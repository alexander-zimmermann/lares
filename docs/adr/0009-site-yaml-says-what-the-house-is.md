# `site.yaml` says what the house is; the fault list says what counts as wrong

What the house is is declared once, in `site.yaml` beside the fault list:
where it stands, the timezone its days are counted in, and its PV planes,
each with the inverter it feeds, its orientation and its peak power.
Every job of the engine reads it there. The fault list, `faults.yaml`, says
what counts as wrong: sentences, parameters and references. A fact about
the house is never a fault parameter and never a job's environment
variable.

The line between the two files is how a value changes. A fact changes
when the house does, a new plane or a replaced inverter, and is right or
wrong on inspection. A judgement changes when the evidence does, by a pull
request that says why. The performance ratio is the case that tests the
line: twelve numbers per plane, one per month, that read like a property
of the roof and still live in the fault list as the plane's references.
They say how much a healthy plane delivers, calibrated on a year declared
healthy; that is a judgement, and it moves like one
([ADR 0010](0010-fault-references-are-declared-never-derived.md)).

Two reasons carry this:

- **One place per fact.** Every job reads what it needs of the house
  there, validated at load, and nothing in the cluster repeats it. The
  engine copies the declared planes into `pv_planes`, and every
  fault's references into `fault_references`, on each run, so Grafana and
  the MCP bridge join the declaration instead of holding a second copy.
- **A change to the fault list is a judgement, reviewed as one.** Its
  pull requests come with evidence, a back-test and the verdicts, from the
  owner or from Propose. With the house in a file of its own, no such
  pull request moves a fact about the house, and no edit of the house
  moves a threshold.

## Considered options

- **The environment of each job**: location, timezone and planes set per
  CronJob, with engine defaults behind them. Every job carries its own
  copy of the same facts, nothing validates them, and the fact a fault
  needs most, which inverter feeds which roof face, has nowhere to live.
- **A `site:` block inside the fault list**: one file instead of two, but
  the forecast jobs, which judge nothing, load the fault list to learn
  where the house stands, and a fact kept beside the thresholds is
  reviewed and moved like one.

## Consequences

- **The loaders hang on the boundary.** Each file has its own schema and
  its own check before every commit (`diagnostics:validate-faults`,
  `diagnostics:validate-site`); a fault that needs the house, a plane's
  references or the kWp that bounds a day's yield, is cross-checked against
  the site wherever both are loaded.
- **Plane keys are the site's.** `West` and `Ost` travel unchanged into
  the references, the database copies, the payloads and the writer rules;
  the generator reads them from `site.yaml` for the per-plane target form.
- **Which channel measures a room is a fact about the house.** The room →
  sensor map `fbh_cold` reads belongs to the site; the gap beside each
  room stays the fault's.
