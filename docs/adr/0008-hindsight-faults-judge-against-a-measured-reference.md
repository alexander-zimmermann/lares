# Hindsight faults judge against a measured reference, never a forecast

A fault judges in hindsight: by the time it compares a day, the day is
over and its weather is an observation, no longer a prediction. So the
reference a fault judges against is a measured series or a declared
number, never a forecast. For a PV plane the measured series is the
irradiance the satellite measured on the plane's own tilt and azimuth —
EUMETSAT's SARAH-3 through the Open-Meteo satellite archive, hourly —
times the plane's peak power and its declared performance ratio for the
month; for a module it is the median module of its own plane on the same
day. A forecast, forecast.solar's yield or Open-Meteo's weather, stays
behind the prognosis addresses and the answers given in conversation, and
is no fault's reference.

Two reasons carry this:

- **A forecast's error is the weather's, and it swamps the fault.**
  Measured against the plant over 31 days, the satellite irradiance times
  kWp tracked the daily yield at a correlation of 0.992 with a daily
  scatter of 7.0 % (3.5 % over seven days); forecast.solar scattered
  23.1 %, ran 15 % low overall and 27 % low in the middle tercile of
  expected yield. A dead string costs about 25 % and persists: against the
  forecast it is a coin toss on any poor day, against the measured sky it
  shows within a week.
- **The fault then measures the plant, not the forecaster.** A cloudy day
  the forecast got wrong says nothing about the plant. The one episode the
  forecast produced in its 30-day verification was exactly that: a 62 %
  shortfall under full cloud cover, on a healthy plant.

## Considered options

- **forecast.solar's yield**, already stored for the prognosis addresses:
  the bias and the scatter above, and on a poor day a comparison no
  better than chance.
- **The sibling plane**, the other roof face under the same sky: what both
  planes share, snow and soiling, cancels out instead of showing, and the
  planes face different ways, so their ratio moves with the sun through
  the day and the year. The two planes are never compared, in any form.
- **A clear-sky model**, to widen the tolerance on broken-cloud days: the
  satellite archive offers no tilted clear-sky variable. It returns only
  if the gate on expected yield cannot do without it.

## Consequences

- **A plane's frontier is the day before yesterday.** SARAH-3 reaches
  the archive with about two days' lag, and the five-day window and the
  verification are sized on that lag. A faster series changes those
  numbers with it.
- **The satellite model is fixed.** The reference reads one model,
  `eumetsat_sarah3`, and the performance ratio is calibrated against it;
  Open-Meteo's MTG model runs 2–6 % above SARAH-3 in May and June.
  Changing the model is a recalibration, never a line swap.
- **The measured sky has a table and a job of its own.**
  `satellite_radiation` holds the hourly irradiance per plane, pulled by
  the `lares-diagnostics-engine-satellite-radiation` CronJob, which refills
  its own gaps. Every Grafana panel that shows it carries the Open-Meteo
  attribution its licence asks for.
- **forecast.solar stays the forecast** behind the prognosis addresses
  15/4/70–73, and is no fault's reference.
- **A forecast may decide which hours a signal counts, never what it is
  compared against.** The rain sensor's fault counts rain only in hours
  the stored weather forecast calls dry; the share it measures is judged
  against its declared zero.
