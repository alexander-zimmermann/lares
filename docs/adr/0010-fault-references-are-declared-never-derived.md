# Fault references are declared, never derived

A fault's reference is declared in its entry in the fault list: as a
number, or as the series it is measured on. It is never derived by the
engine from the subject's own past. A declared number, such as a
device's healthy standby, a freezer's healthy duty cycle, an exchanger's
healthy recovery, a heated rain sensor's zero or a plane's twelve monthly
performance ratios, is read once off a stretch known to be healthy and
written into the entry with a comment that names its source and how to
recompute it. It moves only by a pull request. A declared series, such as
the satellite irradiance over a plane, the median module of a plane or the
room a freezer stands in, is read live, because it is measured on
something other than the subject: a module that fails does not move the
median of its plane.

Two reasons carry this:

- **A derived reference adopts a standing fault as the new normal.** A
  trailing window learns whatever the subject has done lately: an iced
  freezer's long runs, a fouled exchanger's poor recovery, a dead string's
  missing quarter. Against a declared reference the fault stands for as
  long as its cause does: a freezer iced for a year has become its own
  normal and is still a fault.
- **A reference once lost is hard to rebuild.** The database keeps the
  raw series for a year. Once the engine calibrates itself, the fixed
  reference is gone, and a year later the stretch it was read off has left
  the database too. A declared number with its recipe can be recomputed
  from any healthy stretch on hand.

## Considered options

- **A trailing window**, the reference recomputed from the subject's last
  days or weeks: no hand step, and it follows a device as it ages, which
  is exactly why it adopts a fault that stands longer than the window.
- **Applying Propose's numbers automatically**: Propose reads episodes,
  verdicts and data and offers a moved reference with its evidence.
  Applied without a pull request it is a trailing window by another road,
  the engine calibrating itself through an agent, and nobody sees the
  reference move.

## Consequences

- **The performance ratio is a corollary, not a PV special.** It is
  calibrated once on a fixed healthy year and recalibrated by reading the
  recipe in its comment, computing and opening a pull request, by the
  owner or by Propose; no job calibrates it.
- **A moved reference is a candidate.** It is back-tested before it goes
  live, like a moved threshold.
- **Every `references:` comment in the fault list may point here** for
  why the number is declared, and keeps only its own source and recipe.
- **Silence is the exception.** It reads its scale, a channel's normal
  pause, off the channel's own history, because nobody declares the
  rhythm of every channel by hand. What counts as too long, the factor on
  that pause, is still declared.
