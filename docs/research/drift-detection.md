# Drift detection: CUSUM, Page-Hinkley, and whether `river` earns a place

Research note for [lares#1593](https://github.com/alexander-zimmermann/lares/issues/1593)
(parent [#1580](https://github.com/alexander-zimmermann/lares/issues/1580), blocks
[#1582](https://github.com/alexander-zimmermann/lares/issues/1582)).

The question: which method detects a slow drift — standby draw creeping 43 → 300 mA over
weeks, a freezer icing up, a filter clogging, PV decaying — and what would it take to run it
in `iot-insights-engine`?

There is no repo convention for research notes yet; this is the first, filed under
`docs/research/`. `docs/agents/` is reserved for skill configuration and `docs/adr/` for
decisions, so neither fits.

---

## TL;DR

1. **The 30-day z-score cannot detect a ramp — not "poorly", but provably not at all.**
   Against a trailing window of `W` samples, a perfectly linear ramp produces a z-score
   that converges to `sqrt(3·(W+1)/W)` — about **1.73–1.83, independent of the slope**.
   `detect_univariate` fires at 3.0. A ramp of *any* steepness sails under it forever.
2. **Use the tabular CUSUM with a reference level that is pinned, not rolling.** That is
   the whole fix. Page-Hinkley is CUSUM with a *self-computed running* reference, which is
   a weaker version of the same idea and re-introduces a milder form of the drifting-baseline
   problem.
3. **`river` is not worth the dependency for this.** Its `PageHinkley` is 40 lines of pure
   Python; benchmarked head-to-head against a hand-written tabular CUSUM on the same
   parameters it detects the same ramp within 3 hours of the same moment. It cannot express
   a pinned reference at all — the one property this use-case needs.
4. **Do not persist detector state. Recompute it.** The `*_1h` continuous aggregates keep
   full history; replaying 90 days of hourly buckets through a CUSUM loop costs **0.2 ms per
   series**. A stateless recompute is deterministic, idempotent, immune to restarts, and
   matches how every other detector in the engine already works.
5. **Sensitivity is naturally physical.** CUSUM's two knobs are already in the channel's own
   unit: `k` (slack) in mA/W/%rH, and `h` (budget) in mA·h / W·h / %rH·h. The human-facing
   phrasing is *"tolerate ±5 mA of noise; alarm once it has sat 40 mA high for a day"* →
   `k = 5 mA`, `h = (40 − 5) × 24 = 840 mA·h`.

---

## 1. Why the rolling z-score is the wrong instrument — exactly

`detect_univariate` scores the latest 1 h bucket against an hour-of-day × weekday profile
built from the last 60 days
([`detect_univariate.py`](https://github.com/alexander-zimmermann/iot-insights-engine/blob/main/src/iot_insights_engine/detect_univariate.py):
`BASELINE_LOOKBACK_DAYS = 60`, `SEVERITY_INFO_THRESHOLD = 3.0`, effective σ from
`stddev(rollup(...), 'sample')`).

Take a channel drifting linearly at `m` units per sample. Score it against the previous `W`
samples:

- window mean `= a + m·(W−1)/2`, next value `= a + m·W`
  → **deviation `= m·(W+1)/2`**, a *constant* — it does not grow;
- sample standard deviation of an arithmetic sequence `= m·sqrt(W·(W+1)/12)` — also
  proportional to `m`;
- so `z = m(W+1)/2 ÷ m·sqrt(W(W+1)/12) = sqrt(3·(W+1)/W)`.

**The slope cancels.** Verified numerically (`statistics.stdev`, ddof = 1, matching the
toolkit's `stddev(..., 'sample')` — [stats_agg docs][sa]):

| window `W` | 43→300 mA over 6 weeks | 43→300 mA over 6 hours | closed form |
|---|---|---|---|
| 9 (one hour×weekday cell over 60 d) | z = 1.826 | z = 1.826 | 1.8257 |
| 30 | 1.761 | 1.761 | 1.7607 |
| 720 (30 d hourly) | 1.733 | 1.733 | 1.7333 |

The engine's baseline joins on `hour_of_day` **and** `weekday` over 60 days, so each cell
holds ≈ 60/7 ≈ 8.6 samples — the `W = 9` row. **Ceiling ≈ 1.83 against a threshold of 3.0.**

Adding realistic noise (σ = 4 mA on a 43 mA channel) only moves the *maximum* z over a
6-week 43→300 mA ramp to **2.54** — still no alarm, ever.

The `deadband_abs` knob does not rescue this either: for a ramp the raw deviation
`|actual − mean| = m(W+1)/2` is likewise constant, so a deadband can gate a *fast* ramp but
never a slow one.

This is the precise statement of "the profile drifts along with the fault": a trailing
reference is a **high-pass filter**. It passes steps and rejects ramps, by construction. No
choice of threshold, lookback, or σ-floor changes that — the instrument has no gain at DC.
You need an estimator whose reference does *not* move, and a statistic that *integrates*
rather than differencing.

---

## 2. CUSUM: parameters, state, units

Page's cumulative-sum scheme ([Page 1954][page], Biometrika 41(1/2):100–115,
[doi:10.1093/biomet/41.1-2.100][page] — paywalled; the algorithm is restated verbatim in the
sources below).

The [NIST/SEMATECH e-Handbook §6.3.2.3][nist-cusum] gives the tabular form:

> `S_hi(i) = max(0, S_hi(i−1) + x_i − μ̂_0 − k)`
> `S_lo(i) = max(0, S_lo(i−1) + μ̂_0 − k − x_i)`
> … "When either S_hi(i) and S_lo(i) exceeds h, the process is out of control."

[Gama et al. 2014][gama] (ACM Computing Surveys 46(4), §3.2.1) gives the streaming form and
the parameter semantics:

> "The CUSUM test is given by `g_t = max(0, g_{t−1} + (x_t − δ))` (`g_0 = 0`), and the
> decision rule is if `g_t > λ` then signal an alarm followed by setting `g_t = 0`. Here
> `x_t` stands for the current observed value, `δ` corresponds to the magnitude of changes
> that are allowed … and `λ` is a user defined threshold. … The CUSUM test is memoryless,
> and its accuracy depends on the choice of parameters `δ` and `λ`. Both parameters control
> the trade-off between earlier detecting the true changes and allowing more false alarms."

**What it needs:**

| | meaning | unit |
|---|---|---|
| `μ₀` (reference) | the healthy level | mA, W, %rH |
| `k` = `δ` (slack) | deviation tolerated as noise | mA, W, %rH |
| `h` = `λ` (budget) | accumulated excess that trips the alarm | mA·h, W·h, %rH·h |

**What it keeps:** two floats (`S_hi`, `S_lo`). That is the entire state.

**Why it sees ramps:** for a ramp of slope `m`, the increment `(x_t − μ₀ − k)` itself grows
linearly, so `S_hi` grows **quadratically**. Detection is guaranteed, and the delay is a
closed form (derived from `m·T²/2 − kT = h`):

```
T      = (k + sqrt(k² + 2·m·h)) / m          samples until alarm
excess = m·T = k + sqrt(k² + 2·m·h)          how far above μ₀ it has climbed by then
```

For a *step* of size `e` above `μ₀`: `T = h / (e − k)` — no alarm at all if `e ≤ k`.

Both formulas were checked against simulation (43 mA, σ = 4 mA, 6-week ramp to 300 mA,
`k = 5 mA`, `h = 480 mA·h`): predicted 84.0 h / +21.4 mA, observed alarm 79–84 h into the
ramp at +20…+32 mA.

The classical σ-normalised design (`k = δσ/2`, `h ≈ 4–5σ`) from [NIST][nist-cusum] is
deliberately *not* what to use here — see §6.

---

## 3. Page-Hinkley, and what river's version actually does

[Gama et al. 2014][gama] §3.2.1 and Algorithm 1:

> "The test variable `m_T` is defined as the cumulative difference between the observed
> values and their mean up until the current time: `m_T = Σ(x_t − x̄_T − δ)`, where
> `x̄_T = (1/T)Σx_t` and `δ` specifies the tolerable magnitude of changes. The minimum `m_T`
> is defined as `M_T = min(m_t, t = 1…T)`. PH tests for the difference between `M_T` and
> `m_T`: `PH_T = m_T − M_T`. When this difference is greater than a threshold (`λ`) … a
> change is flagged. Larger `λ` will entail fewer false alarms, but might miss some changes."

**The one structural difference from CUSUM: PH has no `μ₀`.** It substitutes the *running
mean of everything seen so far*. That matters directly for this ticket:

- A cumulative mean is **not** a trailing window. Against a ramp it lags by `m·T/2`, which
  *grows*, so `m_T` still grows quadratically and PH does detect the ramp. It is not
  afflicted the way the 30-day z-score is.
- But the reference is still contaminated by the fault, and — worse for a homelab — it is
  *unauditable*. There is no number a human can look at and say "the freezer's healthy idle
  draw is 43 mA". With a pinned `μ₀` there is.

[`river.drift.PageHinkley`][river-ph] ([source][river-ph-src], v0.26.1) implements this with
two additions:

```python
self._x_mean.update(x)                                         # stats.Mean — cumulative, resets on drift
dev = x - self._x_mean.get()
self._sum_increase = self.alpha * self._sum_increase + dev - self.delta
self._sum_decrease = self.alpha * self._sum_decrease + dev + self.delta
...
if self._x_mean.n >= self.min_instances:
    test_increase = self._sum_increase - self._min_increase
    test_decrease = self._max_decrease - self._sum_decrease
    self._drift_detected = self._test_drift(test_increase, test_decrease)
```

| parameter | default | note |
|---|---|---|
| `min_instances` | 30 | warm-up before it may fire |
| `delta` | **0.005** | `δ`, in the channel's unit |
| `threshold` | **50.0** | `λ`, in unit × samples |
| `alpha` | **0.9999** | forgetting factor on the sums — *not* in Page/Gama |
| `mode` | `"both"` | up / down / both (two-sided) |

State kept: `stats.Mean` (two floats — [`stats/mean.py`][river-mean] is pure Python:
`self.n`, `self._mean`), plus `_sum_increase`, `_sum_decrease`, `_min_increase`,
`_max_decrease`, `_drift_detected`. Seven floats. It resets *everything* on detection
(`update()` calls `_reset()` at the top of the next call).

`alpha` bounds the sums at roughly `(dev − δ)/(1 − alpha)`. Measured effect on a slow ramp
(1.2 mA/day, `δ = 2 mA`, `λ = 240 mA·h`):

| `alpha` | effective memory | detected |
|---|---|---|
| 0.9999 (default) | 10 000 samples | 5.6 d into ramp |
| 0.999 | 1 000 | 5.4 d |
| 0.99 | 100 | 4.6 d |
| 0.9 | 10 | **26.0 d** |

So at the default it is effectively absent; anything below ~0.99 starts to blind the
detector to exactly the slow drift we care about. It is a knob with no physical meaning that
can only hurt here — another small argument for owning the code.

### The defaults are a trap

`delta = 0.005` and `threshold = 50.0` *look* dimensionless. They are not — they are in the
channel's unit. On a 43 mA standby channel with σ = 4 mA of hourly noise:

```
river PageHinkley(defaults)  on 1 year of healthy 43 mA ± 4 mA noise
  → 90 alarms, the first after 31 hours
```

i.e. an alarm every four days on a perfectly healthy appliance. On the 43→300 mA ramp the
defaults "detect" at hour 127 — **8.7 days before the ramp even starts**. Anyone who drops
`river.drift.PageHinkley()` in unconfigured gets noise that looks like a working detector.

---

## 4. Head-to-head benchmark

Scenario: hourly buckets; 14 days healthy at 43 mA (σ = 4 mA); then a 42-day linear ramp to
300 mA (6.12 mA/day). `μ₀` for CUSUM frozen from the healthy period.

| detector | parameters | first alarm |
|---|---|---|
| z-score vs 30 d trailing window | threshold 3.0 | **never** (max z = 2.54) |
| tabular CUSUM (`μ₀` pinned) | `k = 5 mA`, `h = 480 mA·h` | 3.3 d into ramp, +30 mA |
| tabular CUSUM | `k = 5 mA`, `h = 240 mA·h` | 2.7 d, +22 mA |
| tabular CUSUM | `k = 2 mA`, `h = 240 mA·h` | 2.1 d, +13 mA |
| `river` PageHinkley | defaults | h = 127 — **false alarm, before the ramp** |
| `river` PageHinkley | `delta=5, threshold=480, mode="up"` | 3.4 d |
| `river` PageHinkley | `delta=5, threshold=240, mode="up"` | 2.8 d |
| `river` PageHinkley | `delta=2, threshold=240, mode="up"` | 2.2 d |

Tuned to the same numbers, river and 40 hand-written lines land within **3 hours** of each
other on a 42-day ramp. **River buys no detection power here.** It buys a `μ₀` you cannot
pin, an `alpha` you do not want, and defaults that fire on noise.

---

## 5. Is `river` worth the dependency?

Facts ([PyPI `river` 0.26.1][river-pypi], [pyproject.toml][river-pyproject]):

- `requires-python >= 3.11`; **cp313 `manylinux_2_28_x86_64` / `aarch64` wheels exist**
  (≈ 2.7 MB), so `python:3.13-slim` in the engine's Dockerfile installs binary — no Rust
  toolchain in the build.
- Runtime deps: `scipy`, `numpy`, `narwhals`. `scipy` and `numpy` are already in
  `uv.lock` (via `scikit-learn`); `narwhals` is already there too. **Net new: none.**
- Since 0.26 the build backend is `maturin` and it ships a compiled `river._river_rust`
  extension — a new supply-chain and ABI surface for the engine, however small.
- Peer-reviewed and maintained: [Montiel et al., JMLR 22(110):1–8, 2021][river-paper].

So the dependency is *cheap*. It is still the wrong call, because:

1. **It cannot express a pinned reference.** No constructor argument, no attribute. The one
   property that separates a working drift detector from a broken one here is unreachable
   without monkey-patching `stats.Mean`.
2. **`update()` is one sample at a time, in Python.** There is no `update_many`, so it gives
   nothing over a plain loop.
3. **The state is not ours to version.** Persisting a pickled river object couples our stored
   state to river's internal attribute names across upgrades (see §6).
4. **The hand-written version is genuinely small.** A complete, typed, two-sided
   replay-based CUSUM with both planning helpers came to **38 non-blank lines**; the
   detection loop itself is 8.

`river` would earn its place if the engine later wanted **ADWIN**
([`river.drift.ADWIN`][river-adwin], [Bifet & Gavaldà 2007][adwin]) — an adaptive-window
detector with a real statistical guarantee and only one knob (`delta`, a significance
level), whose bucket structure is genuinely awkward to reimplement. That is a different
ticket. For CUSUM/PH: **no.**

For completeness, the alternatives that are *already* installed or one dependency away:

- **`scipy` 1.18.1** — verified by introspection: no CUSUM, change-point or drift symbol
  in `scipy.stats` or `scipy.signal`. Nothing to use.
- **`statsmodels`** — only *retrospective* structural-break tests on regression residuals:
  [`breaks_cusumolsresid`][sm-cusum] ("maximum of absolute value of scaled cumulative OLS
  residuals", null hypothesis "no structural change", p-value from a Brownian-Bridge
  asymptotic), `breaks_hansen`, `recursive_olsresiduals`. These answer "was there a break in
  this fixed sample?", not "alarm me now". Wrong shape, and a new dependency.
- **`ruptures`** ([docs][ruptures], Truong/Oudre/Vayatis, *Signal Processing* 167:107299) —
  explicitly **off-line** change-point detection (PELT, binary segmentation, dynamic
  programming). Excellent for a *post-hoc* "when did the freezer start icing?" analysis in a
  notebook. Not for a 15-minute CronJob, and no `k`/`h` in physical units.
- **EWMA control chart** ([NIST §6.3.2.4][nist-ewma]) — `EWMA_t = λY_t + (1−λ)EWMA_{t−1}`,
  limits at `EWMA_0 ± k·s·sqrt(λ/(2−λ))`. Also sensitive to "a small or gradual drift", also
  ~10 lines, but its λ is a dimensionless smoothing constant and its limits are in σ. CUSUM's
  knobs are the ones that map onto a human sentence. Worth keeping in mind as a
  complement, not a replacement.

---

## 6. Surviving restarts

Each CronJob run is a fresh pod: Kubernetes "creates Jobs on a repeating schedule" and warns
"in some situations, more than one Job may be created. **Jobs should be idempotent**"
([CronJob docs][k8s-cron]). The existing `detect-univariate` CronJob already leans on this —
`concurrencyPolicy: Forbid`, `*/15 * * * *`, and an `INSERT … ON CONFLICT DO UPDATE` so the
same hour re-scored four times is harmless.

Three options, in descending order of preference:

### (a) Recompute from the CAGG every run — recommended

The `*_1h` continuous aggregates carry **no retention policy** (`bootstrap.sql` applies
`add_retention_policy` only to raw hypertables at 365 d and to `mcp_anomalies` /
`mcp_forecasts` at 90 d). The 1 h CAGG refresh policies use `start_offset => 2 days` and the
baseline CAGGs `60 days`, both far inside the 365-day raw retention, so the refresh window
never overlaps dropped raw chunks — which is the one way materialised rows get deleted
("If it sees that the raw data was deleted, it also deletes the aggregate data",
[Tiger Data docs][ts-retention]). **The full hourly history is durable and queryable.**

Cost, measured: replaying a 90-day hourly window (2 160 points) through the CUSUM loop takes
**0.2 ms**. Two hundred series ≈ 40 ms. The SELECT dominates; the arithmetic is free.

Properties: no state to migrate, no state to corrupt, deterministic given `(window, μ₀, k,
h)`, trivially idempotent, replayable for backtesting, and a late-arriving backfill is
automatically incorporated. It is also the same shape as the rest of the engine — every
detector today is a stateless query over a CAGG.

Verified end-to-end: a stateless replay over the last 90 days, with `μ₀` taken from the
oldest 7 days of that window, fires **4.0 days into the ramp at 69 mA**.

### (b) Persist the two floats in the database

A small `mcp_drift_state(uc, entity, ref, s_hi, s_lo, last_bucket)` table, upserted each run.
Cheaper per run, but: it needs its own idempotency rule against re-scored buckets (the
detector must skip buckets `<= last_bucket`), it silently diverges if a run is skipped
(`startingDeadlineSeconds: 600` means missed schedules *are* skipped), it cannot be
backfilled, and it needs a reset path when a human replaces the appliance. All of that to
save 0.2 ms. Only worth it if the replay window ever has to exceed a year.

### (c) Pickle the detector to S3

The engine already has this mechanism — `artifacts.save_model` / `load_model` joblib-dump
model objects to rustfs, used by the IsolationForest train/score split. River's FAQ endorses
pickling. **Do not use it for this.** It stores seven floats behind a version-fragile binary
blob whose schema is river's private attribute names, and it inherits every failure mode of
(b). It exists for a 20 MB fitted forest; a CUSUM is not that.

---

## 7. Expressing sensitivity in the channel's own unit

This is the part that decides whether the feature is usable, and CUSUM is unusually good at
it: `k` and `h` are *already* physical. No standardisation is required and none should be
introduced.

### The human sentence → the two numbers

> *"Ignore wobble up to **5 mA**. If the fridge sits **40 mA** above its healthy idle for a
> **day**, tell me."*

```
k = 5 mA
h = (40 − 5) mA × 24 h = 840 mA·h
```

That is the whole configuration. Two registry fields per channel, in mA. The same sentence
in W for the ventilation filter, in %rH for the dehumidifier, in % of expected yield for PV.

### What those numbers then imply, in closed form

| fault shape | delay | trigger level |
|---|---|---|
| step of `e` above `μ₀` | `T = h / (e − k)` | `e` |
| ramp of slope `m` | `T = (k + sqrt(k² + 2mh)) / m` | `μ₀ + k + sqrt(k² + 2mh)` |

Worked, `μ₀ = 43 mA`, `k = 5 mA`, `h = 480 mA·h`:

| fault | result |
|---|---|
| +40 mA step | alarm after 13.7 h |
| +10 mA step | alarm after 96 h |
| +5 mA step | never (at or below `k` — by design) |
| 6.12 mA/day ramp | alarm after 84 h, at 64 mA (+21 mA) |

Both formulas belong in the registry as a doctest, so setting `k`/`h` shows what they mean
in hours and mA rather than in an abstract score. That is the missing half of "expressed in
the channel's own unit": the number the human *types* is physical, and the number the tool
*reports back* ("this catches a 6 mA/day creep 21 mA in, about 3½ days late") is physical too.

### The sanity check the human should not have to do — but the code must

`h` in physical units still has to clear two hazards.

**Hazard 1 — false-alarm rate.** Empirical in-control ARL, one-sided, i.i.d. N(0,1),
4 M samples per cell (`h` and `k` in σ of the channel's *hourly* noise):

| `k` | `h` | ARL₀ (hours) | false alarms / channel / year, two-sided |
|---|---|---|---|
| 0.5σ | 4σ | 340 | ≈ 52 |
| 0.5σ | 5σ | 926 | ≈ 19 |
| 0.5σ | 8σ | 18 700 | ≈ 0.9 |
| 0.5σ | 12σ | 1 052 000 | ≈ 0.02 |
| 1.0σ | 4σ | 14 600 | ≈ 1.2 |
| 1.0σ | 5σ | 95 600 | ≈ 0.2 |

(The `k = 0.5σ, h = 5σ` cell lands at ARL₀ ≈ 926 one-sided, i.e. ≈ 463 two-sided, which is
the value classically tabulated for that design — a useful check that the simulation is
right.) Note that NIST's stock advice — "choose `k` to
be half the δ shift … and `h` to be around 4 or 5" ([§6.3.2.3][nist-cusum]) — is calibrated
for a factory taking a handful of samples per shift. At 8 760 hourly samples per channel per
year across dozens of channels it yields dozens of false alarms per channel per year. **The
house needs `h` around 8–12σ, not 4–5σ.**

**Hazard 2 — autocorrelation, which is the real one.** House channels are strongly
autocorrelated hour to hour. Same `k = 1.0σ`, `h = 8σ`, AR(1) noise with identical marginal
variance:

| φ | false alarms / channel / year |
|---|---|
| 0.0 | ≈ 0.00 |
| 0.5 | 1.45 |
| 0.8 | **19.9** |

Four orders of magnitude of ARL₀ destroyed by autocorrelation alone. **Never set `h` from
the table above.** Set it by backtest: because the replay is stateless and costs 0.2 ms,
a one-off script can sweep `h` over each channel's own last 90 days and pick the smallest
value with zero alarms on a stretch the human confirms was healthy. That calibration is the
single most valuable thing to build alongside the detector, and it is only possible *because*
of the stateless design in §6(a).

**Hazard 3 — periodicity.** A one-sided CUSUM ratchets on any sustained in-control
excursion. For a channel with a diurnal swing of amplitude `A` and period `P`, the
accumulation over a half-period is `A·P/π − k·P/2`; `h` must exceed it. Measured against the
prediction (`k = 5 W`, 24 h period, over 76 days):

| amplitude | predicted daily accumulation | `h = 480 W·h` | `h = 1200 W·h` |
|---|---|---|---|
| 60 W | 398 W·h | 0 false alarms | 0 |
| 100 W | 704 W·h | **76** (one per day) | 0 |
| 150 W | 1 086 W·h | **118** | 0 |

Exactly as predicted. So for a diurnal channel, either run the CUSUM on a **daily**
aggregate, or run it on **residuals** after subtracting the hour-of-day profile — the engine
already materialises exactly that profile in the `*_baseline_30d` CAGGs. Standby draw, a
freezer's idle floor and PV daily yield are all flat or already-normalised and need neither.

---

## 8. What this would look like here (no code written)

- **Channel**: `knx_appliance_1h.idle_floor` (`min(value)` per hour over `%Stromwert` GAs) is
  already the right signal for the 43 → 300 mA case — an idle floor is flat by construction,
  so no residualisation is needed.
- **Detector**: a new `detect-drift` subcommand alongside the existing ten in `__main__.py`,
  reading a `DriftMetric` registry entry: `source_cagg`, `metric`, `group_cols`,
  `reference` (either a pinned constant or "mean of the oldest N days of the window"),
  `slack`, `budget`, `window_days`.
- **Schedule**: it can share `*/15 * * * *` with the others, but hourly (`:35`) is honest —
  the source CAGGs only refresh once an hour, and a drift detector has no use for 15-minute
  latency.
- **Output**: the same `mcp_anomalies` upsert path and `anomaly.<slug>.<severity>` subject,
  so it reaches Basalte through the existing writer-rules with no new plumbing.
- **Severity**: derive from *how far past the budget* it is, or better from the excess in
  physical units (`+13 mA` → info, `+50 mA` → warning), never from a σ count.
- **Reference provenance** is the one genuinely open design decision — see below.

---

## 9. Open questions

1. **Where does `μ₀` come from?** A hand-set constant per channel is the most auditable and
   the most honest, but needs updating when an appliance is replaced. "Mean of the oldest 7
   days of a 90-day replay window" self-provisions and was verified to work (alarm 4.0 d into
   the ramp), but silently normalises any fault older than the window — a freezer that has
   been icing for four months would be adopted as healthy. A hybrid (auto-seed, then pin the
   value into the registry once a human has looked at it) is probably right.
2. **What resets the chart after a true alarm?** Classical CUSUM zeroes on alarm, and
   `river.drift.PageHinkley` wipes its whole state including the reference. Neither fits
   here: the fault persists until someone fixes it, so a reset just re-alarms every
   `h/(e−k)` hours. The engine's own convention is the better answer — anomalies re-insert
   every run while active and `clear.py` emits `severity_level=0` once an entity stops
   appearing (`_CLEAR_LOOKBACK = 7 days`). So: **do not reset**. Let the replayed chart stay
   over budget for as long as the drift is real, let the upsert keep the row open, and let
   the existing auto-clear close it. That falls out of the stateless design for free.
3. **Does `k` need to be per-channel, or can it default to a multiple of the channel's own
   measured σ from the `*_baseline_30d` `stats_agg`?** A `k = max(k_abs, 1.0 × σ)` floor
   mirrors the `min_stddev_abs` pattern already in `UnivariateMetric` and would let most
   channels ship with one number instead of two.
4. **PV decay is a ratio, not a level.** It has to be normalised against irradiance or
   against `mcp_forecasts` before a CUSUM sees it; `detect_pv_underperformance` already owns
   that normalisation and is the natural place to attach the chart.

---

## 10. Reproduction

Every number in this note was produced from the sources cited or measured directly. The
measurements used a throwaway venv (`river` 0.26.1, `scipy` 1.18.1, `statsmodels` 0.15.0) and
touched no cluster, no database and no application code. The scenarios were: (1) closed-form
vs simulated z-score ceiling on linear ramps for `W ∈ {9, 30, 60, 720}`; (2) a 14-day healthy
/ 42-day ramp 43→300 mA standby series at σ = 4 mA, scored by trailing-window z, tabular
CUSUM and `river.drift.PageHinkley`; (3) one year of healthy noise for false-alarm counts;
(4) 4 M-sample in-control ARL sweeps over `(k, h)` for i.i.d. and AR(1) noise; (5) a
sinusoidal channel at three amplitudes for the ratchet check.

---

## Sources

- [E. S. Page (1954), "Continuous Inspection Schemes", *Biometrika* 41(1/2):100–115][page] — the original CUSUM paper. **Paywalled**; the algorithm is quoted verbatim from NIST and Gama et al. below.
- [D. V. Hinkley (1971), "Inference about the change-point from cumulative sum tests", *Biometrika* 58(3):509–523][hinkley] — the other half of the Page-Hinkley name. Also paywalled.
- [NIST/SEMATECH e-Handbook of Statistical Methods §6.3.2.3, "Cusum Control Charts"][nist-cusum] — tabular CUSUM, `k = δσ/2`, `h = d·k`, `d = (2/δ²)ln((1−β)/α)`, "`h` to be around 4 or 5".
- [NIST/SEMATECH e-Handbook §6.3.2.4, "EWMA Control Charts"][nist-ewma] — the EWMA alternative.
- [Gama, Žliobaitė, Bifet, Pechenizkiy, Bouchachia (2014), "A Survey on Concept Drift Adaptation", *ACM Computing Surveys* 46(4):44][gama] — §3.2.1 CUSUM and Page-Hinkley formulations, Appendix Algorithm 1 (PH pseudocode), Algorithm 2 (ADWIN).
- [river `PageHinkley` API docs][river-ph] and [`river/drift/page_hinkley.py`][river-ph-src] — parameters, defaults, update rule.
- [`river/stats/mean.py`][river-mean] — the running mean PH uses as its reference; pure Python, two floats.
- [`river/base/drift_detector.py`][river-drift-base] — the `DriftDetector` contract (`update(x)`, `drift_detected`).
- [river `ADWIN` API docs][river-adwin] and [Bifet & Gavaldà (2007), SIAM SDM][adwin] — the alternative that *would* justify the dependency.
- [Montiel, Halford, Mastelini, et al. (2021), "River: machine learning for streaming data in Python", *JMLR* 22(110):1–8][river-paper].
- [river on PyPI][river-pypi] (0.26.1 wheel matrix) and [river `pyproject.toml`][river-pyproject] (`requires-python >= 3.11`, deps `scipy`/`numpy`/`narwhals`, maturin build backend).
- [river FAQ — model persistence via `pickle`][river-faq].
- [`statsmodels.stats.diagnostic.breaks_cusumolsresid`][sm-cusum] — retrospective OLS-residual CUSUM test (Ploberger & Krämer, *Econometrica* 60(2):271–285, 1992).
- [`ruptures` documentation][ruptures] — off-line change-point detection (Truong, Oudre, Vayatis, *Signal Processing* 167:107299, 2020).
- [Tiger Data / TimescaleDB — `stats_agg()` (two variables)][sa] and [data retention with continuous aggregates][ts-retention].
- [Kubernetes — CronJob][k8s-cron] — "Jobs should be idempotent", `concurrencyPolicy`, `startingDeadlineSeconds`.

[page]: https://doi.org/10.1093/biomet/41.1-2.100
[hinkley]: https://academic.oup.com/biomet/article-abstract/58/3/509/233432
[nist-cusum]: https://www.itl.nist.gov/div898/handbook/pmc/section3/pmc323.htm
[nist-ewma]: https://www.itl.nist.gov/div898/handbook/pmc/section3/pmc324.htm
[gama]: https://dl.acm.org/doi/10.1145/2523813
[river-ph]: https://riverml.xyz/latest/api/drift/PageHinkley/
[river-ph-src]: https://github.com/online-ml/river/blob/main/river/drift/page_hinkley.py
[river-mean]: https://github.com/online-ml/river/blob/main/river/stats/mean.py
[river-drift-base]: https://github.com/online-ml/river/blob/main/river/base/drift_detector.py
[river-adwin]: https://riverml.xyz/latest/api/drift/ADWIN/
[adwin]: https://doi.org/10.1137/1.9781611972771.42
[river-paper]: https://www.jmlr.org/papers/v22/20-1380.html
[river-pypi]: https://pypi.org/project/river/0.26.1/
[river-pyproject]: https://github.com/online-ml/river/blob/main/pyproject.toml
[river-faq]: https://riverml.xyz/dev/faq/
[sm-cusum]: https://www.statsmodels.org/stable/generated/statsmodels.stats.diagnostic.breaks_cusumolsresid.html
[ruptures]: https://centre-borelli.github.io/ruptures-docs/
[sa]: https://www.tigerdata.com/docs/api/latest/hyperfunctions/statistical-and-regression-analysis/stats_agg-two-variables
[ts-retention]: https://www.tigerdata.com/docs/use-timescale/latest/data-retention/data-retention-with-continuous-aggregates/
[k8s-cron]: https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/
