# Coupler forwarding carries the bridge's bus visibility, not device objects

The bridge must hear the whole bus (it mirrors every telegram to NATS for
TSDB, insights and fault detection), but its ETS device models only its
own footprint. The full visibility is provided by routing, not by
objects: line coupler `1.2.0` forwards group telegrams upstream and
`1.1.0` forwards downstream ("Gruppentelegramme: weiterleiten"); the
opposite directions stay filtered so the sensor line is not flooded.

A coupler forwards a filtered direction only for addresses some device
on the far side links. Without this setting every address the bridge
does not carry as an object would be filtered away, and the gap would
show only as missing data in TSDB — a telegram that never crosses a
coupler raises no error anywhere.

## Considered options

- **Monitor collector objects on the bridge** carrying the rest of the
  catalog: honest membership, but every future address needs a manual ETS
  link forever, and unknown or mistyped addresses would still be filtered
  away — exactly the telegrams fault detection wants to see.
- **Basalte keeps carrying everything** (status quo): keeps the coverage
  hostage to a device that should model only its real bindings; shrinking
  Basalte later would reopen the same silent-gap trap.
