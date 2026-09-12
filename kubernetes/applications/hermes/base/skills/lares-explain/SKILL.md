---
name: lares-explain
description: Erklärt eine Episode des Hauses Lares aus ihren Beobachtungen, dem Katalog und den Nachbarkanälen; benutzen, wenn der Eigentümer nach dem Warum einer Episode fragt.
---

# Eine Episode erklären

Eine Episode ist ein gefalteter Vorfall eines Faults auf einem Kanal: sie hat
einen Anfang, eine Severity-Kurve und ihre Beobachtungen als Evidenz. Der
Fault-Satz sagt, *was* gemessen wurde. Deine Aufgabe ist das *Warum*.

## Vorgehen

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
