---
name: lares-explain
description: Erklärt eine Episode des Hauses Lares aus ihren Beobachtungen, dem Katalog und den Nachbarkanälen; benutzen, wenn der Eigentümer nach dem Warum einer Episode fragt.
---

# Eine Episode erklären

Eine Episode ist ein gefalteter Vorfall eines Faults auf einem Kanal: sie hat
einen Anfang, eine Severity-Kurve und ihre Beobachtungen als Evidenz. Der
Fault-Satz sagt, *was* gemessen wurde. Deine Aufgabe ist das *Warum*.

## Vorgehen

Die Schritte 1 bis 4 gehören zu jeder Erklärung. Eine Antwort, die nach
Schritt 1 aufhört, benennt die Episode nur; das ist keine Erklärung. Die
Grenze von zehn Tool-Aufrufen ist ein Deckel, kein Ziel.

1. **Subjekt holen.** `list_episodes` mit der genannten `episode_id` (oder
   `state: open`, wenn nur "die Episode" gesagt wurde). Notiere Fault, Kanal,
   Beginn, Severity, Beobachtungen.
2. **Kanal einordnen.** `get_current_knx` mit `name` = Kanalname: Raum, Gerät,
   Datenpunkt, Einheit und aktueller Wert. Ohne Einheit keine Zahl in der Antwort.
3. **Verlauf ansehen.** `query_timeseries` auf `knx_1h` für den Kanal, vom
   Tag vor dem Beginn bis jetzt, Bucket eine Stunde. Wo ist der Bruch?
4. **Umfeld prüfen, höchstens drei Abfragen.** Je nach Fault:
   - Raumklima (`query_room_climate`) für Temperatur-, Feuchte- und
     Heizungs-Faults;
   - Heizzyklen (`query_heating_cycles`) für alles an Gastherme und Fußboden;
   - Energiefluss (`query_energy_flow`) für PV, Wallbox und Verbraucher;
   - Wetter (`get_weather_forecast`) wenn Außentemperatur oder Sonne die
     Ursache sein könnten;
   - Anwesenheit (`query_unifi_events`) wenn Nutzung die Ursache sein könnte.
5. **Antworten** im Format unten. Wenn die Daten keine Ursache hergeben,
   ist "keine Ursache gefunden" die richtige erste Zeile.

## Je nach Fault

- **channel_silence auf einem Schaltkanal** (DPT 1.x, Name endet auf
  Ein/Aus): der Kanal sendet nur, wenn geschaltet wird. Schweigen heißt
  zuerst "niemand hat geschaltet", nicht "Sensor tot". Prüfe mit
  `get_current_knx` den letzten Wert und Zeitpunkt, und mit `resolve` den
  Rückmelde- oder Statuskanal desselben Geräts. Sag, ob das Gerät aus ist
  oder ob auch die Rückmeldung fehlt; nur das zweite ist ein Defekt.
- **channel_silence auf einem Messkanal** (Temperatur, Feuchte, Strom): der
  Sender selbst oder seine Bridge ist verdächtig. Prüfe Nachbarkanäle
  desselben Geräts und desselben Raums: schweigen alle, ist es das Gerät
  oder der Bus, schweigt nur einer, ist es der Kanal.
- **appliance_runtime, appliance_standby, freezer_icing**: der Stromkanal
  des Geräts über `query_timeseries`, dazu Raumtemperatur und Nutzung
  (`query_unifi_events` für Anwesenheit).
- **fbh_cold, heat_recovery_decay, Gastherme-Faults**: `query_heating_cycles`
  und `query_room_climate` für den Raum, Außentemperatur über das Wetter.
- **pv_underperformance**: `query_energy_flow` und `get_pv_forecast` für den
  Tag; Wolken sind keine Ursache, Abweichung von der Prognose ist eine.

## Antwortformat

```
<Ursache in einem Satz, oder: Keine Ursache gefunden.>

Evidenz:
- <Befund mit Zahl und Einheit> (<Tool>: <Kanal oder Zeitraum>)
- ...

Nicht geprüft: <was offen blieb, und warum>
```

## Grenzen

- Höchstens zehn Tool-Aufrufe je Erklärung.
- Nie rohe `knx`-Daten über mehr als einen Tag abfragen; Stundenaggregate
  reichen, die Datenbank ist klein.
- Keine Verdikte setzen; das tut der Eigentümer.
