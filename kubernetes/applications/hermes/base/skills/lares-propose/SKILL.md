---
name: lares-propose
description: Proposes changes to the house's fault list as pull requests, each with its evidence and a back-test over eight weeks; use it for the weekly propose-faults run.
---

# Proposing changes to the fault list

The fault list (`faults.yaml` in `lares`) declares what the diagnostics
engine measures: one German sentence with a unit per fault, a measured kind,
parameters in the channel's own unit, a scope as a catalog query. Your job
is to read the last eight weeks and hand the owner at most three changes to
it, each one a pull request the owner merges or closes in a minute.

A wrong proposal costs the owner one click, a missed one costs nothing.
Propose only what the evidence carries; a week with nothing to propose is a
good week, and saying so is a complete run.

You never open anything. You write one block per pull request, and the
trigger opens it as the write App, after checking the block and applying
its diff to the file on `main`. One block that does not hold keeps every
block of the run from being opened.

## Procedure

Independent reads go into one step together; the harness runs them side by
side. About twenty tool calls is a normal run, forty the ceiling.

A run the owner asked for in chat ends its prompt with the request
(`The owner asked for this run: ein Fault für den Trockner`). Then the
request comes first: look for its candidates before any other, of every
kind that fits, under the same rules. A request is no evidence; when the
data holds nothing for it, the run's sentence says what was looked at and
why it yields no proposal, and the other kinds still follow.

1. **Read** — six calls in one step:
   - `get_memory` with `use_case: "propose-faults"`: the rejected list, and
     ideas the owner wrote there.
   - `search_pull_requests` twice, `owner: "alexander-zimmermann"`,
     `repo: "lares"`: query `is:pr is:open label:agent/proposal`, and query
     `is:pr is:closed is:unmerged label:agent/proposal closed:>=<today minus 12 weeks>`.
   - `get_file_contents`, owner `alexander-zimmermann`, repo `lares`, path
     `kubernetes/applications/lares-diagnostics-engine/base/config/faults.yaml`:
     the file on `main`, the one your diff is applied to.
   - `list_commits`, same owner, repo and path, `since` eight weeks back:
     when the fault list changed, and what each message says it changed.
   - `list_episodes` with `days: 56`, `only_judged: true`, `limit: 200`:
     every judged episode of the eight weeks, with its fault, the channel,
     device or room it accuses (`subject`), severity, peak score, start and
     verdict (`real` or `nonsense`). Never list the unjudged ones: eight
     weeks of `channel_silence` alone are close to a thousand rows.
2. **Rejections.** A closed pull request whose number the memory does not
   carry yet was rejected since it was last read. For each: one
   `pull_request_read` with `method: "get_comments"` for the owner's
   closing comment, then one `append_memory` line, without line breaks:
   `<closed date> rejected #<number> <kind> <fault> <what changed> (<the evidence its body gave: judged and nonsense counts, or back-test episodes>): "<the comment, one line, at most 120 characters>"`
   — or `comment: none`. Write the line before deciding anything it could
   change.
3. **Candidates.** Go through the four kinds below, the verdict-backed ones
   first. Drop a candidate as soon as one of its rules fails; check the
   next one instead of digging deeper.
4. **Back-test** every candidate that survives (`backtest_fault`, `weeks: 8`,
   `limit: 20`). The candidate is the fault's entry as it would stand after
   your change, in the file's schema; for a new fault without its
   `dormant` block, so it is measured. Some measurements read less than
   eight weeks (a drift reads four): the refusal names how many, so ask
   again with those, and the body says how many weeks it covers. Any other
   refusal names what is wrong with the entry; fix it once, or drop the
   candidate.
5. **Answer** with the run's sentence and one block per proposal, ordered by
   evidence strength (format below).

## The four kinds and their evidence

The kind is one of four names, used alike in the body, in the memory and
in the twelve-week match: `moved threshold`, `retirement`, `activation`,
`new fault`.

Verdict counts come from the judged episodes of step 1, per fault. When a
commit of step 1 changed the fault's entry, count the verdicts on episodes
before and after it apart and say so: verdicts on what the previous rule
made do not move the current one. A commit message that does not say
which fault it touched is said so in the body, not guessed.

- **`moved threshold`** — at least three judged episodes of the fault in
  the eight weeks, and either a majority `nonsense` (move up) or all
  `real` at severity 1 (move down). Move the parameter the verdicts point
  at: a per-device or per-room value (`devices`, `references`, `rooms`)
  when the `nonsense` episodes sit on one channel, device or room, the
  fault-wide parameter when they spread. Take the new value from the
  judged episodes' peak scores, which are in the fault's unit: up, past
  the peaks of the `nonsense` ones and below those of the `real` ones;
  down, so the `real` ones open earlier. The back-test confirms it. The
  body lists every judged episode with its verdict.
- **`retirement`** — at least three judged episodes in the eight weeks,
  every one `nonsense`, none `real`. The diff removes the whole entry with
  its comments. The body lists every judged episode; the back-test of the
  entry as declared shows what goes away.
- **`activation`** — a dormant fault whose `dormant.active_when` sentence
  is observed in the data now. Every dormant fault today waits for an
  address to be written; one `get_current_knx` with `name: "-Anomalie"`
  shows all of them at once, value and age. For an address its scope
  names that was written in the last 30 days, one `query_timeseries` on
  `knx_1h` (`columns: ["sample_count"]`, `filters: {"ga": "<its ga>"}`,
  `bucket: "1 day"`, `aggregation: "sum"`, the last 30 days) counts the
  writes per day. The diff removes the `dormant` block. An `external` fault
  cannot be back-tested (the engine only reads back what Basalte writes);
  the observed writes take the back-test's place, and the body says so.
- **`new fault`** — only a measured kind (`drift`, `duration`,
  `deviation`, `silence`, `constancy`, `volume`), never a raw-value
  threshold: that is Basalte's. Look where the file itself shows a gap: a
  device or channel family one fault covers for a sibling and not for
  itself (a duty-cycle drift for the freezer, none for the fridge), a
  measured family no scope matches, an idea the owner wrote into the
  memory. Check the pattern in the hourly aggregates (`knx_1h`,
  `knx_appliance_1h`) before the back-test; never the raw `knx` table. The
  entry carries the sentence and unit in German like every other,
  parameters in the channel's unit, a scope as a catalog query (`dpt`,
  `include`, `exclude`; never an address list), a `target` named after the
  anomaly-address convention (`<Function>.<Device>.<Datapoint>-Anomalie`),
  and a `dormant` block, because that address does not exist yet:
  ```yaml
      dormant:
        reason: "Die Anomalie-Adresse steht noch nicht im Katalog."
        active_when: "Die Adresse <its name> steht im Katalog."
  ```
  The back-test must find something and not everything: zero episodes, or
  one per channel every week, is a rejection the owner should not have to
  give. `measured` says how many channels the scope resolved to; zero
  channels is a broken scope, not a quiet house. New entries go after the
  last measured fault, before the comment that opens the external ones;
  `notification_volume` stays last.

**The writer rules.** The KNX writer rules in
`ga-mappings/diagnostics.yaml` are generated from every fault that has a
`target` and is not dormant, and CI fails when they are stale. A
`retirement` or an `activation` of a fault with a `target` changes them,
and your pull request changes one file only. Then the body opens with this
line, before anything else:

```
**Before merging:** run `task knx:create-ga-mappings` on this branch and commit what it writes; the GA-mapping check fails until then.
```

A `moved threshold`, a `new fault` (dormant) and an `activation` of an
`external` fault leave the writer rules as they are.

**Twelve weeks.** A change the memory rejected in the last twelve weeks,
same fault, same kind, same parameter or subject, is not proposed again —
unless the evidence is clearly stronger than what its memory line
recorded: at least twice the judged episodes, or a verdict it lacked. Then
the body says so in its first paragraph and links the rejected pull
request. Never propose what an open `agent/proposal` pull request already
proposes.

## Answer format

The first line is the run's sentence: what this week brought, in one
sentence. Then one block per proposal, each opened by a line
`~~~github_pr` and closed by a line `~~~`, both at the start of the line.
The values below show the shape only; none of them is a finding.

~~~~
~~~github_pr
repository: lares
path: kubernetes/applications/lares-diagnostics-engine/base/config/faults.yaml
title: "appliance_runtime: dryer limit 4 h → 5 h"
labels: [topic/smart-home]
body: |
  **Kind:** moved threshold · **Fault:** `appliance_runtime` · **Weeks:** 2026-08-09 – 2026-10-04

  <what changes and why, two or three sentences, values in the channel's unit>

  ### Evidence
  - <one line per finding: episodes with id, date, channel or device, severity, verdict; numbers with units>

  ### Back-test
  - <episodes the changed entry finds in eight weeks: count, dates, channels or devices, peak in the fault's unit; how many channels the scope resolved to>

  ### Diff
  ```diff
  <the same diff as below>
  ```
diff: |
  --- a/kubernetes/applications/lares-diagnostics-engine/base/config/faults.yaml
  +++ b/kubernetes/applications/lares-diagnostics-engine/base/config/faults.yaml
  @@ -190,5 +190,5 @@
           max_run_hours: 24
         KG.Hauswirtschaftsraum.K3-L1.Trockner:
  -        max_run_hours: 4
  +        max_run_hours: 5
         # Laundry days chain loads back to back for 10-13 h; only a run past
         # two of those in a row is a fault.
~~~
~~~~

- **Title**: one line in double quotes, at most 100 characters. A
  `moved threshold` is `<fault>: <what> <old> → <new value with unit>`, an
  `activation` is `Activate <fault>`, a `retirement` is `Retire <fault>`, a
  `new fault` is `New fault <name>: <what it catches, in a few English
  words>`.
- **Labels**: exactly `[topic/smart-home]`; the trigger adds
  `agent/proposal`, and a label the repository lacks refuses the run.
- **Body**: English, Markdown. It opens with the kind, the fault and the
  weeks on one line, which is what the rejected list is later read from.
  A `new fault` adds `### Why no existing fault covers it`: the faults
  whose kind or scope come closest, and what each misses.
- **Diff**: a unified diff of that one file against the file as step 1
  read it. Every context and removed line stands in the file exactly as
  written there: indentation, quotes, comments. Two or three unchanged
  lines around each change, enough to be found in one place only; lines
  added without context are refused. The `@@` line numbers come from the
  file as read. A change that moves a value keeps the comment above it
  true: rewrite the comment in English, one line, saying what is, not what
  was.
- Two proposals in one run never touch the same entry: each is applied to
  `main` on its own.
- Nothing to propose: one block holding only `none: <why, in one
  sentence>`, after the run's sentence. A run without any block fails.

## Limits

- At most three proposals per run; what does not fit returns next week if
  its evidence still holds.
- At most two back-tests per candidate, a shorter window aside.
- Set no verdicts, and write nothing to the memory but rejections; the
  ideas in it are the owner's.
