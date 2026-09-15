# A changed object set is a new device; object numbers are positional

ETS' "Aktualisieren" keeps a device's parameters but drops every group
link on these generated products — proven twice on 2026-09-13, with
unchanged object numbers as much as with shifted ones. Stable object
numbers therefore buy nothing: the links move by hand either way.

So the generated devices work like this:

- **Object numbers are positional** — main group, datapoint type,
  sending before receiving — so the object list reads like the
  group-address tree. When the object set changes, numbers shift.
- **A changed object set is a new application version**, imported as a
  **second device** next to the installed one. The links are dragged
  over object by object per worksheet, which marks every object `NEU`
  or `war N` (its number on the old device); then the old device is
  deleted and the new one takes its individual address.
- **The generator compares against the ETS export** (objects matched by
  name) and says per device "same objects — only links" or "N new,
  M renumbered — publish". It **refuses to write** when an installed
  object that still carries links has disappeared — no source claims
  those addresses any more; `--accept-loss` is the deliberate way past.
- **`scripts/kaenx/versions.yaml` records the version last handed out**
  per device, committed with the catalog. The generator bumps above the
  higher of the installed version and that record, and only when the
  objects changed — because ETS remembers every version it ever
  imported, also ones deleted from its catalog, and silently ignores a
  re-import.

## Considered options

- **An object registry with stable numbers** (`scripts/kaenx/objects.yaml`,
  built and then removed): meant to keep numbers across regenerations so
  links would survive an application update. They do not — the update
  drops them regardless of the numbers. What remained was a second state
  file with nothing to protect; the worksheet's `war N` mapping does the
  same job for the drag-over.
- **Writing links into the ETS export from outside ETS**: ETS refuses to
  import the result. The export is for reading only.
- **Bumping the version by hand in Kaenx-Creator's publish tab**: a
  number at or below one ETS has ever seen does nothing, silently. The
  record has to be kept where the generator can read it.

## Consequences

- Supersedes the consequence in ADR-0001 that collector order keeps
  object numbers and lets ETS links survive application updates: numbers
  shift with the set, and no link survives an update; the worksheet
  carries the mapping instead.
- `versions.yaml` is committed state; a run that handed out a version
  without a commit leaves the next run one version short.
- Every publish costs a drag-over on the ETS VM — under five minutes for
  a hundred objects — plus linking the new addresses.
- The ETS behaviour behind this (update drops links, versions are
  remembered forever, exports are read-only) is product knowledge and
  lives in the wiki page
  [ets-kaenx-creator](https://wiki.zimmermann.sh/en/ets-kaenx-creator),
  not in this repository; the ADR only relies on it.
