# Research: `heartbeat_agg` and the neighbouring state/counter hyperfunctions

Origin: [lares#1591](https://github.com/alexander-zimmermann/lares/issues/1591) (parent: #1580, blocks #1587)

Question: what can TimescaleDB Toolkit's `heartbeat_agg` actually do, and how would it
answer *"this channel stopped sending"* for the `knx` hypertable (~2500 distinct `ga`)?

All statements below are taken from the TimescaleDB / Toolkit / PostgreSQL primary
sources linked inline. **Nothing here was verified against the running cluster** — the
open items in the last section still need a `psql` check.

---

## TL;DR

- `heartbeat_agg` is a real fit for liveness, but it is **window-anchored, not
  "last seen"-anchored**: you must tell it the start and length of the window up front,
  and every timestamp fed into it must fall inside that window or the query **errors out**.
- It **does work inside a continuous aggregate** with `agg_start := time_bucket(...)` —
  that is the documented and field-tested pattern — but a CAgg holding a `heartbeatagg`
  column could not be *refreshed* until Toolkit **1.24.0** added the `=` operator.
  This is the single hardest version gate.
- The **expected interval is a single constant per aggregate call** (`heartbeat_liveness`).
  One CAgg carries one liveness value for all 2500 GAs. There is no per-channel interval
  unless you split into several aggregates or join a per-`ga` interval column.
- A channel that **never sent anything produces no row at all** (`heartbeat_agg` over zero
  rows returns `NULL`, and `GROUP BY ga` never creates the group). "Silent" is therefore
  *always* an anti-join against `ga_catalog`, never something the aggregate can tell you.
- Cost: **no parallel aggregation** (the aggregate has no `COMBINEFUNC`), and PostgreSQL
  budgets **8 kB per group** for the internal state → ~20 MB planned for 2500 groups,
  with real usage untracked and unbounded.
- For the narrow question *"did this GA stop sending?"* the existing `knx_1h` CAgg
  (`bucket, ga, sample_count`) already answers it with `max(bucket)` and costs nothing new.
  `heartbeat_agg` earns its keep for *uptime %, gap enumeration and gap counting*, not for
  a staleness check.

---

## 1. The aggregate

```sql
heartbeat_agg(
    heartbeat          TIMESTAMPTZ,
    agg_start          TIMESTAMPTZ,
    agg_duration       INTERVAL,
    heartbeat_liveness INTERVAL
) RETURNS HeartbeatAgg
```

Source: [`api/_hyperfunctions/heartbeat_agg/heartbeat_agg.md`](https://github.com/timescale/docs/blob/latest/api/_hyperfunctions/heartbeat_agg/heartbeat_agg.md),
rendered at [`/api/latest/hyperfunctions/state-tracking/heartbeat_agg/`](https://www.tigerdata.com/docs/api/latest/hyperfunctions/state-tracking/heartbeat_agg).

Semantics, verbatim from the docs:

- `agg_start` — "The start of the time range over which this aggregate is tracking liveness."
- `agg_duration` — "The length of the time range … **Any point in this range that doesn't
  closely follow a heartbeat is considered to be dead.**"
- `heartbeat_liveness` — "**How long the system is considered to be live after each heartbeat.**"

So the model is: each timestamp paints the half-open span `[t, t + heartbeat_liveness)`
as live; overlapping spans are merged; whatever is left inside
`[agg_start, agg_start + agg_duration)` is dead.

Versions: experimental in **1.13.0**, stable in **1.15.0**
([Changelog](https://github.com/timescale/timescaledb-toolkit/blob/main/CHANGELOG.md);
[#615](https://github.com/timescale/timescaledb-toolkit/pull/615) added it,
[#722](https://github.com/timescale/timescaledb-toolkit/pull/722) stabilised it).
Licence is the Timescale License, not Apache-2
([toolkit README](https://github.com/timescale/timescaledb-toolkit/blob/main/README.md)).

### 1.1 Hard constraints the docs do not mention

These come from the implementation,
[`extension/src/heartbeat_agg.rs`](https://github.com/timescale/timescaledb-toolkit/blob/main/extension/src/heartbeat_agg.rs):

```rust
// HeartbeatTransState::new
assert!(
    end - start > interval,
    "all points passed to heartbeat agg must occur in the 'agg_duration' interval after 'agg_start'"
);

// HeartbeatTransState::insert
assert!(
    time >= self.start && time < self.end,
    "all points passed to heartbeat agg must occur in the 'agg_duration' interval after 'agg_start'"
);
```

1. **`agg_duration` must be strictly greater than `heartbeat_liveness`.** A one-day bucket
   with a seven-day liveness is impossible — which rules out modelling the event-driven
   GAs with legitimate multi-day gaps as "one day bucket, one week liveness".
2. **Every row in the group must fall inside `[agg_start, agg_start + agg_duration)`.**
   A row outside the window is not ignored — the assert becomes a PostgreSQL `ERROR` and
   the whole query aborts. In a CAgg this is automatic if `agg_start = time_bucket(...)`
   and `agg_duration >= bucket width`; in an ad-hoc query it is a live footgun.
3. **Only the *first* row's `agg_start` / `agg_duration` / `heartbeat_liveness` are used.**
   `heartbeat_trans_inner` does `state.unwrap_or_else(|| … new(...))` — the three window
   arguments of every subsequent row are silently discarded. Since intra-group row order
   is not guaranteed, feeding a *per-row varying* liveness (e.g. from a joined per-`ga`
   column) is non-deterministic unless the value is constant within the group. It is
   constant per `ga` if you group by `ga`, so a joined per-GA interval is in fact safe —
   but only because of the grouping, not because the aggregate re-reads it.
4. Calendar intervals are resolved relative to `agg_start` (`interval_to_ms(&start, &length)`),
   so `'1 month'` behaves sensibly.

### 1.2 Internal representation

`HeartbeatAgg` is a flat varlena of
`start_time, end_time, last_seen, interval_len, num_intervals` (5 × 8 bytes) plus two
parallel `i64` arrays of `num_intervals` entries — i.e. **~40 bytes + 16 bytes per live
range**. The transition state buffers up to `BUFFER_SIZE = 1000` raw timestamps before
merging them into the sorted, non-overlapping range list
([source](https://github.com/timescale/timescaledb-toolkit/blob/main/extension/src/heartbeat_agg.rs)).

Consequence: size is driven by the **number of live ranges (= gaps + 1)**, not by the
number of rows. A GA that ticks every few minutes under a generous liveness collapses to
**one** range. A GA whose every sample is spaced further apart than `heartbeat_liveness`
degenerates to **one range per sample** — that is the pathological case to watch for on
the event-driven GAs.

### 1.3 Accessors

| Function | Signature | Notes |
|---|---|---|
| `live_ranges(agg)` | `TABLE(start TIMESTAMPTZ, end TIMESTAMPTZ)` | the merged live spans |
| `dead_ranges(agg)` | `TABLE(start TIMESTAMPTZ, end TIMESTAMPTZ)` | complement of the above, clipped to the agg window |
| `uptime(agg)` | `INTERVAL` | sum of live ranges |
| `downtime(agg)` | `INTERVAL` | `agg_duration - uptime` |
| `live_at(agg, ts)` | `BOOL` | see caveat below |
| `num_live_ranges(agg)` | `BIGINT` | 1.16.0 |
| `num_gaps(agg)` | `BIGINT` | 1.16.0; counts leading/trailing dead edges too |
| `trim_to(agg [, start] [, duration])` | `HeartbeatAgg` | 1.16.0; **narrowing only**, widening errors |
| `interpolate(agg, pred)` | `HeartbeatAgg` | carries the predecessor's last heartbeat over the boundary |
| `interpolated_uptime(agg, pred)` | `INTERVAL` | |
| `interpolated_downtime(agg, pred)` | `INTERVAL` | |
| `rollup(agg)` | `HeartbeatAgg` | aggregate; unions live ranges |

Sources: the per-function files under
[`api/_hyperfunctions/heartbeat_agg/`](https://github.com/timescale/docs/tree/latest/api/_hyperfunctions/heartbeat_agg)
and [#749](https://github.com/timescale/timescaledb-toolkit/pull/749) for the 1.16.0 trio.

**`live_at` caveat — the docs are wrong.** The doc says "this returns false for any time
not covered by the aggregate", but the implementation raises an error:

```rust
if test < agg.start_time || test > agg.end_time {
    error!("unable to test for liveness outside of a heartbeat_agg's covered range")
}
```

So `live_at(agg, now())` on an aggregate whose window ends before `now()` **errors**; it
does not return `false`. Any "is it live right now?" query must therefore build an
aggregate whose window actually contains `now()`, which conflicts with a materialised CAgg
whose newest bucket lags behind. This is the main reason `live_at` is not the right tool
for a staleness alert.

**There is no accessor for `last_seen`.** The field exists in the struct and drives
interpolation, but nothing exposes it. To answer "when did this GA last send?" you still
need `max(time)` (or `last(...)`, or the end of the final live range minus
`heartbeat_liveness`).

### 1.4 `rollup` and `interpolate`

`rollup` combines aggregates and "considers a time live if any of its component aggregates
were live" — designed both for stitching adjacent buckets into a longer window and for
OR-ing redundant systems together
([rollup.md](https://github.com/timescale/docs/blob/latest/api/_hyperfunctions/heartbeat_agg/rollup.md)).
Two rollup bugs were fixed early: [#660](https://github.com/timescale/timescaledb-toolkit/issues/660)
(rollup should interpolate) and [#679](https://github.com/timescale/timescaledb-toolkit/issues/679)
(rollup producing invalid aggregates), both released in 1.14.0.

`interpolate(agg, pred)` fixes the artefact where the span between `agg_start` and the
first heartbeat looks dead even though the previous bucket's last heartbeat still covered
it. The documented pattern is a window function at *query* time:

```sql
SELECT dead_ranges(interpolate(health, LAG(health) OVER (ORDER BY date)))
FROM liveness WHERE date = '01-9-2022 UTC';
```

`interpolate_start` asserts `pred.end_time <= self.start_time`, so the predecessor must not
overlap. Note that window functions inside a **CAgg definition** are experimental and off
by default (`timescaledb.enable_cagg_window_functions`,
[create-a-continuous-aggregate.md](https://github.com/timescale/docs/blob/latest/use-timescale/continuous-aggregates/create-a-continuous-aggregate.md)),
so interpolation belongs in the reading query, not in the materialisation.

---

## 2. Continuous aggregates

**Yes — with a version gate.**

The official how-to
([use-timescale/hyperfunctions/heartbeat-agg.md](https://github.com/timescale/docs/blob/latest/use-timescale/hyperfunctions/heartbeat-agg.md))
shows the shape, though note it actually creates a *plain* materialized view, not a CAgg:

```sql
CREATE MATERIALIZED VIEW weekly_heartbeat AS
  SELECT time_bucket('1 week', tmstp) as week, iid as unit, deploy,
         heartbeat_agg(tmstp, time_bucket('1w', tmstp), '1w', '2m')
  FROM power_samples GROUP BY 1,2,3;
```

A genuine CAgg is confirmed by toolkit issue
[#875](https://github.com/timescale/timescaledb-toolkit/issues/875), where a user runs:

```sql
CREATE MATERIALIZED VIEW IF NOT EXISTS heartbeat_half_hour
WITH (timescaledb.continuous, timescaledb.materialized_only = false) AS
SELECT m.vehicle_id,
       time_bucket('30 minutes', m.timestamp, 'UTC') AS bucket_half_hour,
       heartbeat_agg(m.timestamp,
                     time_bucket('30 minute', m.timestamp, 'UTC'),
                     INTERVAL '50 minutes',
                     INTERVAL '20 minutes') AS heartbeat
FROM measurement AS m
GROUP BY vehicle_id, bucket_half_hour;
```

Creating and querying it works. **Refreshing it did not**: TimescaleDB's `MERGE`-based
refresh compares `ROW(M.*) IS DISTINCT FROM ROW(P.*)`, and `heartbeatagg` had no equality
operator:

```
ERROR: operator does not exist: public.heartbeatagg = public.heartbeatagg
```

Timescale's own maintainer (`mkindahl`) reopened it as a Toolkit bug:
*"we need to implement equality operators for the `heartbeatagg` type"*. Fixed by
[#922](https://github.com/timescale/timescaledb-toolkit/pull/922), shipped in
**Toolkit 1.24.0 (2026-07-27)**: *"Add equality operators for `heartbeat_agg`, allowing
continuous aggregate refreshes that need to compare heartbeat aggregate states"*
([CHANGELOG](https://github.com/timescale/timescaledb-toolkit/blob/main/CHANGELOG.md)).

Other CAgg constraints that apply
([create-a-continuous-aggregate.md](https://github.com/timescale/docs/blob/latest/use-timescale/continuous-aggregates/create-a-continuous-aggregate.md),
[about-continuous-aggregates.md](https://github.com/timescale/docs/blob/latest/use-timescale/continuous-aggregates/about-continuous-aggregates.md)):

- Everything in `SELECT` / `GROUP BY` / `HAVING` must be immutable. The toolkit's
  `heartbeat_trans` and `heartbeat_final` are declared `immutable, parallel_safe`, so the
  aggregate itself qualifies.
- Note the example's `agg_duration` (50 min) is deliberately **larger than the bucket**
  (30 min) — it has to exceed `heartbeat_liveness` (20 min) per §1.1, and the overhang lets
  a bucket's last heartbeat's liveness extend past the bucket edge. The trade-off is that
  `downtime()` on such an aggregate is measured against 50 minutes, not 30.
- A CAgg may `LEFT JOIN` one hypertable to standard PostgreSQL tables from
  **TimescaleDB ≥ 2.16**, but "changes to standard PostgreSQL table are not tracked" —
  so joining `ga_catalog` for a per-GA expected interval works, yet editing the catalog
  will not retro-refresh existing buckets.
- The join cannot invent buckets: the hypertable drives, so a GA with no rows in a bucket
  still yields no row (see §3).

---

## 3. A channel that never sent anything

Three separate facts, all of which point the same way:

1. `heartbeat_final_inner` is `state.map(|s| …)`. With no rows the transition state is
   `None`, so **`heartbeat_agg(...)` over an empty input returns `NULL`**, not an
   all-dead aggregate.
2. In `GROUP BY ga` a `ga` with zero rows in the window **produces no group at all**, so
   there is not even a `NULL` to look at.
3. The scalar accessors are `STRICT` — pgrx infers `STRICT` for any `#[pg_extern]` whose
   arguments are not `Option`-wrapped
   ([pgrx `PgExternEntity::to_sql`](https://github.com/pgcentralfoundation/pgrx/blob/develop/pgrx-sql-entity-graph/src/pg_extern/entity/mod.rs):
   *"It may be possible to infer a `STRICT` marker … But we can only do that if the user
   hasn't used a nullable argument wrapper"*). `uptime`, `downtime`, `live_at`,
   `num_gaps`, `num_live_ranges`, `live_ranges`, `dead_ranges` all take a bare
   `HeartbeatAgg`, so a `NULL` aggregate short-circuits to `NULL` / no rows.
   Only `interpolate`, `interpolated_uptime` and `interpolated_downtime` take
   `Option<HeartbeatAgg>` and are therefore non-strict in `pred`.

**Implication for lares:** the universe of channels must come from `ga_catalog`
(`kubernetes/applications/timescaledb/base/scripts/bootstrap.sql`), not from the
aggregate. A silent-channel query is structurally
`ga_catalog LEFT JOIN <aggregate> ... WHERE agg IS NULL OR <stale>`. Keep in mind the
already-recorded gotcha that `ga_catalog` lists **ETS addresses, not datapoints** — some
catalogued GAs have never produced a row and never will, so the anti-join needs an
allow-list or a "seen at least once, ever" pre-filter, or it will report a large constant
set of false positives.

Corollary: a fully dead bucket is a **missing row** in a heartbeat CAgg, not a row with
`uptime = 0`. Anything that computes availability over time needs
`generate_series` of buckets (or the catalog) on the left.

---

## 4. Cost over ~2500 distinct `ga`

### 4.1 No parallel aggregation

The aggregate is declared without a combine function:

```sql
CREATE AGGREGATE heartbeat_agg(
    heartbeat TIMESTAMPTZ, agg_start TIMESTAMPTZ, agg_duration INTERVAL, heartbeat_liveness INTERVAL
) (
    sfunc = heartbeat_trans,
    stype = internal,
    finalfunc = heartbeat_final
);
```

No `combinefunc`, no `serialfunc` / `deserialfunc`, no `sspace`. PostgreSQL is explicit
([xaggr.html](https://www.postgresql.org/docs/current/xaggr.html)): a combine function is
required for partial aggregation, and for an `internal` state type serialize/deserialize
functions are required as well — *"Without these functions, parallel aggregation cannot be
performed."* So a `heartbeat_agg` over the raw hypertable is **single-worker**, however
many chunks it touches. (The toolkit says the same about its sibling: *"While the aggregate
is not parallelizable, it is supported with continuous aggregation"* —
[docs/counter_agg.md](https://github.com/timescale/timescaledb-toolkit/blob/main/docs/counter_agg.md).)
CAggs are unaffected because since TimescaleDB 2.7 they store the **finalized** aggregate
value, not a partial ([migrate.md](https://github.com/timescale/docs/blob/latest/use-timescale/continuous-aggregates/migrate.md)).

### 4.2 Memory per group

PostgreSQL's planner has no size estimate to work with, so it falls back to a default —
[`src/backend/optimizer/prep/prepagg.c`](https://github.com/postgres/postgres/blob/master/src/backend/optimizer/prep/prepagg.c):

```c
else if (transinfo->aggtranstype == INTERNALOID)
{
    /*
     * INTERNAL transition type is a special case: although INTERNAL
     * is pass-by-value, it's almost certainly being used as a pointer
     * to some large data structure. …  If it doesn't [provide an
     * estimate], then we assume ALLOCSET_DEFAULT_INITSIZE …
     */
    if (transinfo->aggtransspace > 0)
        costs->transitionSpace += transinfo->aggtransspace;
    else
        costs->transitionSpace += ALLOCSET_DEFAULT_INITSIZE;
}
```

`ALLOCSET_DEFAULT_INITSIZE` is `8 * 1024`
([memutils.h](https://github.com/postgres/postgres/blob/master/src/include/utils/memutils.h)),
and `internal` is `typbyval => 't'`
([pg_type.dat](https://github.com/postgres/postgres/blob/master/src/include/catalog/pg_type.dat)),
which is exactly why that special case exists.

So: **2500 groups × 8 kB ≈ 20 MB** of planned `transitionSpace` charged against `work_mem`
for a HashAggregate. Real usage is in the same ballpark but is **not** bounded by it — the
per-group buffer alone can hold 1000 × `i64` = 8 kB before it is merged, and on top of that
sits the liveness `Vec` at 16 bytes per live range. A GA whose sample spacing exceeds
`heartbeat_liveness` grows that `Vec` without limit. On a 1 GiB TimescaleDB pod this is the
number to keep an eye on; the existing TSDB-OOM gotchas in this repo were caused by exactly
this kind of unbounded per-group state.

Mitigation is straightforward: **narrow buckets** (hour or day) keep every group's range
list short, and `rollup()` reassembles longer windows at read time from small pieces.

### 4.3 Scan cost against `knx`

From `bootstrap.sql`: `knx` is a 1-day-chunk hypertable, compressed after 2 days with
`compress_segmentby = 'ga'`, `compress_orderby = 'time DESC'`, retained 365 days.

- A **per-GA** heartbeat query is cheap: `segmentby = ga` means one segment per GA per
  chunk, so a `WHERE ga = …` decompresses very little.
- An **all-GA** backfill is the expensive shape: it decompresses the `time` column of every
  segment in every chunk in range, single-threaded (§4.1), building 2500 states at once
  (§4.2). Over 365 days that is 365 chunks × 2500 segments.
- The forward-going CAgg is cheap by construction: with `start_offset => 2 days` the
  refresh reads from heap, which is exactly why the existing CAgg policies in `bootstrap.sql`
  are tuned that way (the comment there says so explicitly).

So: build it as a CAgg with `WITH NO DATA` and let the policy fill forward; treat any
historical backfill as a chunked, verified migration rather than one statement.

### 4.4 The cheaper alternative for the actual question

`knx_1h` already exists and already materialises one row per `(bucket, ga, knx_name)` with
`sample_count`. "This channel stopped sending" is therefore:

```sql
SELECT c.ga, max(k.bucket) AS last_bucket
FROM ga_catalog c
LEFT JOIN knx_1h k USING (ga)
GROUP BY c.ga;
```

…at the cost of one hour of resolution and the CAgg's own lag (`end_offset => 1 hour`,
`schedule_interval => 1 hour` → up to ~2 h behind). No new aggregate, no new storage.

`heartbeat_agg` buys things `knx_1h` cannot give: sub-hour resolution of *when* the gaps
were, `uptime`/`downtime` as a proper availability figure, `num_gaps` as a flapping
signal, and `rollup` into arbitrary reporting windows. Whether #1587 needs those is the
design decision this research hands back.

### 4.5 The per-channel-interval problem

`heartbeat_liveness` is one constant per aggregate call. With ~2500 GAs where "most send
every few minutes" but "some are event-driven with legitimate multi-day gaps", a single
liveness value is either too tight (multi-day GAs permanently dead) or too loose (a
few-minutes GA can be silent for days before it registers). Options, in increasing order
of cost:

1. **One generous liveness + a separate staleness rule** for the chatty GAs. Simplest;
   heartbeat_agg answers availability, `max(time)` answers staleness.
2. **Two or three CAggs**, one per liveness class, each with a `WHERE` predicate selecting
   its class of `ga`. Mirrors what `knx_appliance_1h` already does with
   `WHERE knx_name LIKE '%Stromwert'`.
3. **`LEFT JOIN ga_catalog`** for a per-GA `expected_interval` column (needs
   TimescaleDB ≥ 2.16, and catalog edits do not retro-refresh). Safe only because the
   value is constant within each `ga` group — see §1.1 item 3.

Also remember §1.1 item 1: `agg_duration > heartbeat_liveness` strictly. A per-GA liveness
of several days forces `agg_duration` — and therefore the bucket — to be at least that
wide, which collides with option 3 unless the bucket is sized for the *largest* liveness.

---

## 5. Neighbouring hyperfunctions

### 5.1 `state_agg` / `compact_state_agg` — the duty-cycle case

```sql
state_agg(ts TIMESTAMPTZ, value {TEXT | BIGINT}) RETURNS StateAgg
compact_state_agg(ts TIMESTAMPTZ, value {TEXT | BIGINT}) RETURNS CompactStateAgg
```

Experimental 1.13.0, stable 1.15.0
([state_agg docs](https://github.com/timescale/docs/tree/latest/api/_hyperfunctions/state_agg)).

Given a value that switches between **discrete states**, it tracks the transitions.
Accessors: `duration_in(agg, state [, start] [, interval])` → `INTERVAL`,
`state_at(agg, ts)`, `state_periods(agg, state)` → `(start_time, end_time)`,
`state_timeline(agg)` → `(state, start_time, end_time)`, `into_values(agg)` →
`(state, duration)`, plus `rollup` and the `interpolated_*` variants that stitch across
bucket boundaries.

`compact_state_agg` stores only durations; `state_agg` also stores the transition
timestamps and therefore uses more memory. Both are explicitly *"designed to work with a
relatively small number of states"* and *"might not perform well on datasets where states
are mostly distinct between rows"*
([compact_state_agg intro](https://github.com/timescale/docs/blob/latest/api/_hyperfunctions/compact_state_agg/intro.md)).

**Fit for lares:** this is the right tool for the DPT 1.x on/off GAs — `duration_in(agg, 1)`
over an hourly bucket is a duty cycle, directly and without the standby-threshold heuristics
that `knx_appliance_1h` currently uses for `%Stromwert`. It is the *wrong* tool for the
analog GAs (temperature, power) where nearly every row is a distinct value — that is
exactly the "mostly distinct between rows" case the docs warn about, and `value` would need
bucketing into discrete states first. Also note `state_agg` takes `TEXT | BIGINT` while
`knx.value` is `DOUBLE PRECISION`, so every use needs an explicit cast.

`compact_state_agg` is the memory-cheap choice when only durations are needed. Given the
1 GiB TSDB pod, prefer it unless the transition timestamps are actually consumed.

### 5.2 `counter_agg` — the counter-delta case

```sql
counter_agg(ts TIMESTAMPTZ, value DOUBLE PRECISION [, bounds TSTZRANGE]) RETURNS CounterSummary
```

Experimental 0.2.0, stable 1.3.0
([counter_agg docs](https://github.com/timescale/docs/tree/latest/api/_hyperfunctions/counter_agg)).

For **monotonically increasing** values where a decrease means a reset: *"the 'true value'
of the counter after a decrease is the previous value + the current value"*
([toolkit docs/counter_agg.md](https://github.com/timescale/timescaledb-toolkit/blob/main/docs/counter_agg.md)).
Accessors: `delta`, `rate`, `num_resets`, `num_changes`, `num_elements`, `first_val`,
`last_val`, `first_time`, `last_time`, `slope`, `intercept`, `corr`, `idelta_left/right`,
`irate_left/right`, `time_delta`, `counter_zero_time`, plus `extrapolated_delta` /
`extrapolated_rate` (Prometheus-compatible; these need `bounds`, supplied at aggregate time
or later via `with_bounds(summary, tstzrange)`), and the boundary-interpolating
`interpolated_delta` / `interpolated_rate`. `rollup` combines summaries.

**Fit for lares:** correct for energy meters and any GA that only counts up. Explicitly
**not** for values that can go down — the docs say to use **`gauge_agg`** for those, which
was stabilised in Toolkit **1.25.0** ([CHANGELOG](https://github.com/timescale/timescaledb-toolkit/blob/main/CHANGELOG.md),
[#859](https://github.com/timescale/timescaledb-toolkit/pull/859)). Misapplying
`counter_agg` to a gauge silently inflates every delta, because each downward step is read
as a reset.

Like `heartbeat_agg`, `counter_agg` is not parallelizable but is supported in continuous
aggregates.

---

## 6. Recommended shape, if #1587 goes with `heartbeat_agg`

```sql
-- one hour per bucket keeps the per-group range list short (§4.2);
-- agg_duration (90m) > bucket (60m) > heartbeat_liveness (30m)  (§1.1)
CREATE MATERIALIZED VIEW knx_heartbeat_1h
WITH (timescaledb.continuous, timescaledb.materialized_only = true) AS
SELECT time_bucket('1 hour', time) AS bucket,
       ga,
       heartbeat_agg(time, time_bucket('1 hour', time), INTERVAL '90 minutes', INTERVAL '30 minutes') AS hb
FROM knx
GROUP BY bucket, ga
WITH NO DATA;
```

Then, at read time:

- availability over a window: `uptime(rollup(hb))` / `num_gaps(rollup(hb))`
- where the gaps were: `dead_ranges(rollup(hb))`
- silent channels: anti-join `ga_catalog` against the buckets present (§3)
- staleness *now*: **not** `live_at` (§1.3) — use `max(time)` on `knx`, or `max(bucket)`
  on `knx_1h`

This has not been benchmarked; §4 is an analysis of the code and the planner, not a
measurement.

---

## 7. Open items — need a `psql` check before this shape is committed to

1. **Installed Toolkit version.** Must be **≥ 1.24.0** or a CAgg carrying a `heartbeatagg`
   column cannot be refreshed (§2). `SELECT extversion FROM pg_extension WHERE extname = 'timescaledb_toolkit';`
2. **Installed TimescaleDB version**, if the per-GA-interval join of §4.5 option 3 is
   wanted (needs ≥ 2.16).
3. **Actual live-range counts.** Pick the five most event-driven GAs and check
   `num_live_ranges` for a candidate `heartbeat_liveness`; that is the number that decides
   whether §4.2 is a non-issue or a memory problem.
4. **How many catalogued GAs have never produced a row**, to size the false-positive set
   of the §3 anti-join.
5. Whether `%Stromwert` duty cycle is better served by `compact_state_agg` (§5.1) than by
   the current `on_samples` threshold in `knx_appliance_1h`.

Per the repo's constraints, none of these were run — no cluster or database was touched
for this research.

---

## Sources

Toolkit and TimescaleDB (primary):

- heartbeat_agg API pages — https://github.com/timescale/docs/tree/latest/api/_hyperfunctions/heartbeat_agg (rendered: https://www.tigerdata.com/docs/api/latest/hyperfunctions/state-tracking/heartbeat_agg)
- heartbeat how-to — https://github.com/timescale/docs/blob/latest/use-timescale/hyperfunctions/heartbeat-agg.md
- state_agg API pages — https://github.com/timescale/docs/tree/latest/api/_hyperfunctions/state_agg
- compact_state_agg intro — https://github.com/timescale/docs/blob/latest/api/_hyperfunctions/compact_state_agg/intro.md
- counter_agg API pages — https://github.com/timescale/docs/tree/latest/api/_hyperfunctions/counter_agg
- counter_agg design notes — https://github.com/timescale/timescaledb-toolkit/blob/main/docs/counter_agg.md
- Toolkit implementation — https://github.com/timescale/timescaledb-toolkit/blob/main/extension/src/heartbeat_agg.rs
- Toolkit CHANGELOG — https://github.com/timescale/timescaledb-toolkit/blob/main/CHANGELOG.md
- Toolkit README (licence) — https://github.com/timescale/timescaledb-toolkit/blob/main/README.md
- toolkit#875 (CAgg refresh failure) — https://github.com/timescale/timescaledb-toolkit/issues/875
- toolkit#922 (equality operators, 1.24.0) — https://github.com/timescale/timescaledb-toolkit/pull/922
- toolkit#615 / #722 / #733 / #749 / #660 / #679 (feature history) — https://github.com/timescale/timescaledb-toolkit/pulls
- CAgg creation rules — https://github.com/timescale/docs/blob/latest/use-timescale/continuous-aggregates/create-a-continuous-aggregate.md
- CAgg JOIN support matrix — https://github.com/timescale/docs/blob/latest/use-timescale/continuous-aggregates/about-continuous-aggregates.md
- CAgg finalized form (2.7+) — https://github.com/timescale/docs/blob/latest/use-timescale/continuous-aggregates/migrate.md

PostgreSQL and pgrx (primary):

- Partial / parallel aggregation requirements — https://www.postgresql.org/docs/current/xaggr.html
- Transition-space estimate for `internal` — https://github.com/postgres/postgres/blob/master/src/backend/optimizer/prep/prepagg.c
- `ALLOCSET_DEFAULT_INITSIZE` — https://github.com/postgres/postgres/blob/master/src/include/utils/memutils.h
- `internal` is pass-by-value — https://github.com/postgres/postgres/blob/master/src/include/catalog/pg_type.dat
- pgrx `STRICT` inference — https://github.com/pgcentralfoundation/pgrx/blob/develop/pgrx-sql-entity-graph/src/pg_extern/entity/mod.rs

This repo:

- `kubernetes/applications/timescaledb/base/scripts/bootstrap.sql` — `knx` schema, compression, `knx_1h`, `knx_appliance_1h`, `ga_catalog`, CAgg policies
