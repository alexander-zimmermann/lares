---
name: lares-explain
description: Erklärt eine Episode des Hauses Lares aus ihren Beobachtungen, dem Katalog und den Nachbarkanälen; benutzen, wenn der Eigentümer nach dem Warum einer Episode fragt.
---

# Eine Episode erklären

Eine Episode ist ein gefalteter Vorfall eines Faults auf einem Kanal: sie hat
einen Anfang, eine Severity-Kurve und ihre Beobachtungen als Evidenz. Der
Fault-Satz sagt, *was* gemessen wurde. Deine Aufgabe ist das *Warum*.

## Vorgehen

Vier Schritte, jeder mit einem Werkzeugaufruf, jeder mit einer Zeile in der
Antwort. Eine Antwort, in der ein Schritt fehlt, ist keine Erklärung, sondern
eine Episodenliste. Die Grenze von zehn Tool-Aufrufen ist ein Deckel, kein
Ziel; vier bis sechs sind der Normalfall.

1. **Subjekt.** `list_episodes` mit der genannten `episode_id`. Notiere
   Fault, Kanal, Beginn, Severity, Beobachtungen.
2. **Kanal.** `resolve` mit dem Kanalnamen: Raum, Gerät, Datenpunkt,
   Einheit, und die Geschwisterkanäle desselben Geräts. Ohne Einheit keine
   Zahl in der Antwort.
3. **Verlauf.** `query_timeseries` auf `knx_1h` für den Kanal, vom Tag vor
   dem Beginn bis jetzt, Bucket eine Stunde. Wann war der letzte Wert, wo
   ist der Bruch?
4. **Umfeld.** Mindestens eine, höchstens drei Abfragen, je nach Fault (siehe
   unten). Ein Ergebnis mit null Zeilen ist kein Befund: Filter weglassen und
   erneut fragen. `functions` sind ETS-Funktionsnamen wie `Sensorik`,
   `Raumklima`, `Heizung`, keine Datenpunkte wie `Temperatur`; im Zweifel
   ohne Filter.

Dann die Ursache. Wenn die vier Schritte keine hergeben, ist "keine Ursache
in den Daten" die richtige erste Zeile, aber erst nach den vier Schritten.

## Antwortformat

```
<Ursache in einem Satz, oder: Keine Ursache in den Daten.>

Subjekt: <Fault, Kanal, seit wann, Severity> (list_episodes)
Kanal: <Gerät, Raum, Einheit, Geschwister> (resolve)
Verlauf: <letzter Wert und Zeitpunkt, Bruch> (query_timeseries)
Umfeld: <Befund mit Zahl und Einheit> (<Tool>: <Parameter>)

Offen: <nur, was mit den Werkzeugen nicht prüfbar war, und warum>
```

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
