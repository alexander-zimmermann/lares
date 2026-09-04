# Basalte logic: inventory

Generated from the Studio export with `task basalte:inventory` — **do not hand-edit**.
Regenerate after every change in Basalte and read the diff.

The export itself is not in the repo: 14 MB of binary, and it carries at least one
value that looks like an access token. See `docs/basalte/README.md` for where it goes.

**166 logic blocks**, **28 of them notifying**, carrying **127 distinct notifications** between them. 878 named objects in the export.

## Notifications

The existing set, against which every newly planned fault has to be checked.
One row per notification — a block often carries several, one per room or device.

| Block | Message | Thresholds | Devices |
|---|---|---|---|
| A5 - Dach | Windgeschwindigkeit größer als 36km/h für mehr als 3 Minuten. | False, True | — |
| Alarmauslösung EMA Extern Scharf | Linienüberschreitung auf der Terrasse! | 1, False | Pollerleuchte |
| An/Abwesend - Meldung | Willkommen zu Hause. | — | — |
| An/Abwesend - Meldung | Außer Haus. | — | — |
| Anomalie Temperatur | Kritisch: Heizung Vorlauf Ist-Temperatur auffällig. | — | — |
| Anomalie Temperatur | Warnung: Heizung Vorlauf Ist-Temperatur auffällig. | — | — |
| Anomalie Temperatur | Warnung: Heizung Rücklauf Ist-Temperatur auffällig. | — | — |
| Anomalie Temperatur | Kritisch: Heizung Rücklauf Ist-Temperatur auffällig. | — | — |
| Anomalie Temperatur | Info: Heizung Rücklauf Ist-Temperatur auffällig. | — | — |
| Anomalie Temperatur | Info: Heizung Vorlauf Ist-Temperatur auffällig. | — | — |
| Anomalie Therme | Kritisch: Brenner Modulation auffällig. | — | — |
| Anomalie Therme | Info: Brenner Modulation auffällig. | — | — |
| Anomalie Therme | Warnung: Brenner Modulation auffällig. | — | — |
| Anomalie Warmwasser | Kritisch: Warmwasser Ist-Temperatur auffällig. | — | — |
| Anomalie Warmwasser | Kritisch: Warmwasser Durchfluss auffällig. | — | — |
| Anomalie Warmwasser | Warnung: Warmwasser Ist-Temperatur auffällig. | — | — |
| Anomalie Warmwasser | Info: Warmwasser Durchfluss auffällig. | — | — |
| Anomalie Warmwasser | Warnung: Warmwasser Durchfluss auffällig. | — | — |
| Anomalie Warmwasser | Info: Warmwasser Ist-Temperatur auffällig. | — | — |
| CO-Melder Alarm | Technischer Alarm: Technikraum (K3) CO-Melder. | — | — |
| DG - Dachgeschoss | Warnung: im Speicher (S) ist der Taupunkt unterschritten. | — | — |
| DG - Dachgeschoss | Warnung: im Speicher (S) ist der CO2 Wert > 1600ppm. | — | — |
| DG - Dachgeschoss | Warnung: im Abstellraum (O2) ist die Luftfeuchtigkeit > 65%. | — | — |
| EG - Erdgeschoss | Warnung: im Büro (E3) ist die Luftfeuchtigkeit > 65%. | — | — |
| EG - Erdgeschoss | Warnung: im Esszimmer (E5) ist der CO2 Wert > 1400ppm. | — | — |
| EG - Erdgeschoss | Warnung: im der Küche (E6) ist der Taupunkt unterschritten. | — | — |
| EG - Erdgeschoss | Warnung: im Wohnzimmer (E4) ist die Luftfeuchtigkeit > 65%. | — | — |
| EG - Erdgeschoss | Warnung: in der Küche (E6) ist die Luftfeuchtigkeit > 65%. | — | — |
| EG - Erdgeschoss | Warnung: im Gäste WC (E2) ist der CO2 Wert > 1400ppm. | — | — |
| EG - Erdgeschoss | Warnung: im Gäste WC (E2) ist die Luftfeuchtigkeit > 65%. | — | — |
| EG - Erdgeschoss | Warnung: im Wohnzimmer (E4) ist der CO2 Wert > 1400ppm. | — | — |
| EG - Erdgeschoss | Warnung: im Esszimmer (E5) ist der Taupunkt unterschritten. | — | — |
| EG - Erdgeschoss | Warnung: im Gäste WC (E2) ist der Taupunkt unterschritten. | — | — |
| EG - Erdgeschoss | Warnung: im Esszimmer (E5) ist die Luftfeuchtigkeit > 65%. | — | — |
| EG - Erdgeschoss | Warnung: im Arbeitszimmer (E3) ist der Taupunkt unterschritten. | — | — |
| EG - Erdgeschoss | Warnung: im der Küche (E6) ist der CO2 Wert > 1400ppm. | — | — |
| EG - Erdgeschoss | Warnung: im Wohnzimmer (E4) ist der Taupunkt unterschritten. | — | — |
| EG - Erdgeschoss | Warnung: im Arbeitszimmer (E3) ist der CO2 Wert > 1400ppm. | — | — |
| EG - Erdgeschoss | Warnung: im Flur (E1) ist noch ein Fenster geöffnet. | — | Eingangstüre, Fenster, Fenster Links, Fenster Mitte, Fenster Mitte Links, Fenster Mitte Rechts, Fenster Rechts, Fenster Seite |
| EG - Erdgeschoss | Warnung: im Gäste WC (E2) ist noch ein Fenster geöffnet. | — | Eingangstüre, Fenster, Fenster Links, Fenster Mitte, Fenster Mitte Links, Fenster Mitte Rechts, Fenster Rechts, Fenster Seite |
| EG - Erdgeschoss | Warnung: in der Küche (E6) ist noch ein Fenster geöffnet. | — | Eingangstüre, Fenster, Fenster Links, Fenster Mitte, Fenster Mitte Links, Fenster Mitte Rechts, Fenster Rechts, Fenster Seite |
| EG - Erdgeschoss | Warnung: im Arbeitszimmer (E3) ist noch ein Fenster geöffnet. | — | Eingangstüre, Fenster, Fenster Links, Fenster Mitte, Fenster Mitte Links, Fenster Mitte Rechts, Fenster Rechts, Fenster Seite |
| EG - Erdgeschoss | Warnung: im Esszimmer (E5) ist noch ein Fenster geöffnet. | — | Eingangstüre, Fenster, Fenster Links, Fenster Mitte, Fenster Mitte Links, Fenster Mitte Rechts, Fenster Rechts, Fenster Seite |
| EG - Erdgeschoss | Warnung: im Wohnzimmer (E4) ist noch ein Fenster geöffnet. | — | Eingangstüre, Fenster, Fenster Links, Fenster Mitte, Fenster Mitte Links, Fenster Mitte Rechts, Fenster Rechts, Fenster Seite |
| Gasmelder Alarm | Technischer Alarm: Vorratsraum (K4) Gasmelder. | — | — |
| Gasmelder Alarm | Technischer Alarm: Technikraum (K3) Gasmelder. | — | — |
| Gefriehrschrank - Türe auf | Warnung:erhöhter Stromverbrauch festgestellt. Möglicherweise ist die Türe nicht richtig geschlossen. | 120, 150, 180, 210, 25.5, 27 | Fußbodenheizung |
| KG - Kellergeschoss | Warnung: im Hauswirtschaftsraum (K5) ist noch ein Fenster geöffnet. | — | Fenster, Garagentor |
| KG - Kellergeschoss | Warnung: im Technikraum (K3) ist noch ein Fenster geöffnet. | — | Fenster, Garagentor |
| KG - Kellergeschoss | Warnung: in der Garage (K2) ist noch ein Fenster geöffnet. | — | Fenster, Garagentor |
| KG - Kellergeschoss | Warnung: im Vorratsraum (K4) ist noch ein Fenster geöffnet. | — | Fenster, Garagentor |
| KG - Kellergeschoss | Warnung: im Hauswirtschaftsraum (K5) ist der Taupunkt unterschritten. | — | — |
| KG - Kellergeschoss | Warnung: im Hauswirtschaftsraum (K5) ist der CO2 Wert > 1400ppm. | — | — |
| KG - Kellergeschoss | Warnung: im der Garage (K2) ist die Luftfeuchtigkeit > 65%. | — | — |
| KG - Kellergeschoss | Warnung: im Vorratsraum (K4) ist der CO2 Wert > 1400ppm. | — | — |
| KG - Kellergeschoss | Warnung: im Hauswirtschaftsraum (K5) ist die Luftfeuchtigkeit > 65%. | — | — |
| KG - Kellergeschoss | Warnung: im Technikraum (K3) ist der CO2 Wert > 1400ppm. | — | — |
| KG - Kellergeschoss | Warnung: in der Garage (K2) ist der Taupunkt unterschritten. | — | — |
| KG - Kellergeschoss | Warnung: im Technikraum (K3) i ist der Taupunkt unterschritten. | — | — |
| KG - Kellergeschoss | Warnung: im Technikraum (K3) ist die Luftfeuchtigkeit > 65%. | — | — |
| KG - Kellergeschoss | Warnung: im Vorratsraum (K4) ist die Luftfeuchtigkeit > 65%. | — | — |
| KG - Kellergeschoss | Warnung: im Vorratsraum (K4)  ist der Taupunkt unterschritten. | — | — |
| KG - Kellergeschoss | Warnung: in der Garage (K2) ist der CO2 Wert > 1400ppm. | — | — |
| Kühlschrank - Türe auf | Warnung:erhöhter Stromverbrauch festgestellt. Möglicherweise ist die Türe nicht richtig geschlossen. | 25.5, 27, 30, 60, 80, 90 | Fußbodenheizung |
| Meldung Bewässerung | Die Bewässerung für Kreislauf 1 ist gestoppt worden. | — | — |
| Meldung Bewässerung | Die Bewässerung für Kreislauf 1 ist gestartet worden. | — | — |
| Meldungen Sabotage | Sabotage: Leitungsüberwachung Optischer Signalgeber. | — | — |
| Meldungen Sabotage | Sabotage: Wandabreisskontakt Signalgeber. | — | — |
| Meldungen Sabotage | Sabotage: Deckelkontakt. | — | — |
| Meldungen Sabotage | Sabotage: Leitungsüberwachung Akustischer Signalgeber. | — | — |
| Meldungen Sicherungsbereich | Sicherungsbereich Alarm! | — | — |
| Meldungen Sicherungsbereich | Warnung: das Haus ist verlassen worden und die Sicherungsbereich ist nicht extern scharf geschaltet worden. | — | — |
| Meldungen Sicherungsbereich | Sicherungsbereich extern scharf geschaltet. | — | — |
| Meldungen Sicherungsbereich | Sicherungsbereich unscharf geschaltet. | — | — |
| Meldungen Sicherungsbereich | Sicherungsbereich intern scharf geschaltet. | — | — |
| Meldungen Sicherungsbereich | Sicherungsbereich unscharf geschaltet. | — | — |
| Meldungen Sicherungsbereich | Sicherungsbereich scharf geschaltet. | — | — |
| Meldungen Störung | Störung Akku. | — | — |
| Meldungen Störung | Störung Netz. | — | — |
| Meldungen Störung | Störung Übertragungseinrichtung. | — | — |
| Meldungen Störung | Störung des Sicherungsbereich. | — | — |
| Meldungen Terrasse EMA Extern Scharf | Sirenengeräusch auf der Terrasse Wohnzimmer erkannt! | False, True | — |
| Meldungen Terrasse EMA Extern Scharf | Einruchsgegäusch auf der Wohnzimmer Esszimmer erkannt! | False, True | — |
| Meldungen Terrasse EMA Extern Scharf | Glasbruchgeräusch auf der Wohnzimmer Esszimmer erkannt! | False, True | — |
| Meldungen Terrasse EMA Extern Scharf | Personen auf der Terrasse Wohnzimmer erkannt! | False, True | — |
| Meldungen Terrasse EMA Extern Scharf | Geschrächsgeräusch auf der Wohnzimmer Esszimmer erkannt! | False, True | — |
| Meldungen Wohnzimmer EMA Extern Scharf | Sirenengeräusch auf der Terrasse Esszimmer erkannt! | False, True | — |
| Meldungen Wohnzimmer EMA Extern Scharf | Geschrächsgeräusch auf der Terrasse Esszimmer erkannt! | False, True | — |
| Meldungen Wohnzimmer EMA Extern Scharf | Glasbruchgeräusch auf der Terrasse Esszimmer erkannt! | False, True | — |
| Meldungen Wohnzimmer EMA Extern Scharf | Einruchsgegäusch auf der Terrasse Esszimmer erkannt! | False, True | — |
| Meldungen Wohnzimmer EMA Extern Scharf | Personen auf der Terrasse Esszimmer erkannt! | False, True | — |
| OG - Obergeschoss | Warnung: im Kinderbad (O3) ist die Luftfeuchtigkeit > 65%. | — | — |
| OG - Obergeschoss | Warnung: im Abstellraum (O2) ist die Luftfeuchtigkeit > 65%. | — | — |
| OG - Obergeschoss | Warnung: in Luis Schlafzimmer (O5) ist die Luftfeuchtigkeit > 65%. | — | — |
| OG - Obergeschoss | Warnung: in Luis Schlafzimmer (O5) ist der Taupunkt unterschritten. | — | — |
| OG - Obergeschoss | Warnung: im Kinderbad (O3) ist der CO2 Wert > 1600ppm. | — | — |
| OG - Obergeschoss | Warnung: im Gregory's Schlafzimmer (O4) ist die Luftfeuchtigkeit > 65%. | — | — |
| OG - Obergeschoss | Warnung: im Kinderbad (O3) ist der Taupunkt unterschritten. | — | — |
| OG - Obergeschoss | Warnung: im Abstellraum (O2) ist der CO2 Wert > 1600ppm. | — | — |
| OG - Obergeschoss | Warnung: im Elternbad (O8) ist die Luftfeuchtigkeit > 65%. | — | — |
| OG - Obergeschoss | Warnung: im Gregory's Schlafzimmer (O4) ist der CO2 Wert > 1600ppm. | — | — |
| OG - Obergeschoss | Warnung: im Elternbad (O8) ist der CO2 Wert > 1600ppm. | — | — |
| OG - Obergeschoss | Warnung: im Abstellraum (O2) ist der Taupunkt unterschritten. | — | — |
| OG - Obergeschoss | Warnung: in Luis Schlafzimmer (O5) ist der CO2 Wert > 1600ppm. | — | — |
| OG - Obergeschoss | Warnung: im Elternschlafzimmer (O6) ist die Luftfeuchtigkeit > 65%. | — | — |
| OG - Obergeschoss | Warnung: in Gregory's Schlafzimmer (O4) ist der Taupunkt unterschritten. | — | — |
| OG - Obergeschoss | Warnung: im Elternbad (O8) ist der Taupunkt unterschritten. | — | — |
| OG - Obergeschoss | Warnung: im Elternschlafzimmer (O6) ist der CO2 Wert > 1600ppm. | — | — |
| OG - Obergeschoss | Warnung: im Elternschlafzimmer (O6) ist der Taupunkt unterschritten. | — | — |
| OG - Obergeschoss | Warnung: im Schlafzimmer (O6) ist noch ein Fenster geöffnet. | — | Fenster, Fenster Gallerie, Fenster Gang |
| OG - Obergeschoss | Warnung: im Kinderbad (O3) ist noch ein Fenster geöffnet. | — | Fenster, Fenster Gallerie, Fenster Gang |
| OG - Obergeschoss | Warnung: in Luis Schafzimmer (O5) ist noch ein Fenster geöffnet. | — | Fenster, Fenster Gallerie, Fenster Gang |
| OG - Obergeschoss | Warnung: im Elternbad (O8) ist noch ein Fenster geöffnet. | — | Fenster, Fenster Gallerie, Fenster Gang |
| OG - Obergeschoss | Warnung: in Gregory's Schlafzimmer (O4) ist noch ein Fenster geöffnet. | — | Fenster, Fenster Gallerie, Fenster Gang |
| OG - Obergeschoss | Warnung: im Flur (O1) ist noch ein Fenster geöffnet. | — | Fenster, Fenster Gallerie, Fenster Gang |
| OG - Obergeschoss | Warnung: im Abstellraum (O2) ist noch ein Fenster geöffnet. | — | Fenster, Fenster Gallerie, Fenster Gang |
| Trockner - Programmaktionen | Trockenprogramm ist beendet. | False, True | — |
| Waschmaschine - Programmaktionen | Waschmaschinenprogramm ist beendet. | False, True | — |
| Wasser - Erweiteter Durchflussalarm | Wasserdurchfluss für Wasserzähler Haus größer als 1000 l/h für mehr als 1 Minute. | False, True | — |
| Wasser - Erweiteter Durchflussalarm | Wasserdurchfluss für Wasserzähler Garten größer als 1000 l/h für mehr als 1 Minute. | False, True | — |
| Wassermelder Alarm | Technischer Alarm: Flur (E1) Wassermelder. | — | — |
| Wassermelder Alarm | Technischer Alarm: Küche (E6) Wassermelder Küchenzeile Links. | — | — |
| Wassermelder Alarm | Technischer Alarm: Küche (E6) Wassermelder Kücheninsel. | — | — |
| Wassermelder Alarm | Technischer Alarm: Flur (E6) Wassermelder Küchenzeile Rechts. | — | — |
| Wassermelder Alarm | Technischer Alarm: Elternschlafzimmer (O6) Wassermelder. | — | — |
| Wassermelder Alarm | Technischer Alarm: Technikraum (K3) Wassermelder. | — | — |
| Wassermelder Alarm | Technischer Alarm: Hauswirtschaftsraum (K5) Wassermelder. | — | — |

## All blocks

| Block | Nodes | Node types |
|---|---:|---|
| (unnamed) | 10 | and×1, knxbool×3, linkinput×1, not×2, openclosedevice×1 |
| 1 Minute | 4 | init×1, linkoutput×1, oscillator×1, setbool×1 |
| 1 Stunde | 4 | init×1, linkoutput×1, oscillator×1, setbool×1 |
| 10 Minuten | 4 | init×1, linkoutput×1, oscillator×1, setbool×1 |
| 2 Minuten | 4 | init×1, linkoutput×1, oscillator×1, setbool×1 |
| 3 Stunden | 4 | init×1, linkoutput×1, oscillator×1, setbool×1 |
| 30 Minuten | 4 | init×1, linkoutput×1, oscillator×1, setbool×1 |
| 5 Minuten | 4 | init×1, linkoutput×1, oscillator×1, setbool×1 |
| A1 - Fassade | 6 | daylight×1, delay×1, lights×1, multiplexer×1, setbool×1, when×1 |
| A2 - Eingang | 6 | daylight×1, delay×1, lights×1, multiplexer×1, setbool×1, when×1 |
| A2 - Terrasse | 18 | init×2, interlock×2, knxbool×2, linkoutput×4, memory×2, multiplexer×2, not×2, scenes×2 |
| A3/A4/A5 - Terrasse / Balkon / Garten | 23 | and×1, area×2, daylight×1, delay×1, lights×4, not×3, openclosedevice×2, or×1, setbool×2, setpercentage×2, setreset×1, when×1 |
| A5 - Dach | 15 | delay×3, init×1, knxbool×2, memory×1, multiplexer×1, not×1, notification×1, setbool×2 |
| Alarmauslösung EMA Extern Scharf | 17 | and×1, audio_notification×1, daylight×1, gate×1, knxbool×2, lights×3, linkinput×2, multiplexer×2, notification×1, setbool×2, setpercentage×1 |
| Alarmauslösung EMA Intern Scharf | 18 | and×1, audio_notification×1, daylight×1, gate×1, knxbool×4, lights×3, linkinput×2, multiplexer×2, setbool×2, setpercentage×1 |
| An/Abwesend - Home Szenen | 5 | linkinput×2, not×1, or×1, scenes×1 |
| An/Abwesend - Meldung | 17 | compare×2, debouncer×2, gate×1, linkinput×2, memory×1, not×1, notification×2, or×1 |
| An/Abwesend - Zustand | 8 | debouncer×2, init×1, knxbool×2, linkoutput×2, memory×1 |
| Anomalie Temperatur | 12 | changedetector×2, knxnumber×2, lookuptable×2, notification×6 |
| Anomalie Therme | 6 | changedetector×1, knxnumber×1, lookuptable×1, notification×3 |
| Anomalie Warmwasser | 12 | changedetector×2, knxnumber×2, lookuptable×2, notification×6 |
| Automatik Bereit - Präsenzfenster | 6 | linkinput×2, linkoutput×1, multiplexer×1, oneshot×1 |
| Automatik Bereit - Status senden | 7 | init×1, knxbool×2, linkinput×1, memory×1, multiplexer×1 |
| Automatik Sperren - Status senden | 7 | init×1, knxbool×2, linkinput×1, memory×1, multiplexer×1 |
| CO 2 Alarm | 36 | changedetector×3, knxbool×15, linkinput×3, linkoutput×3, memory×3, or×3 |
| CO 2 Alarm | 39 | changedetector×3, knxbool×18, linkinput×3, linkoutput×3, memory×3, or×3 |
| CO-Melder Alarm | 3 | changedetector×1, knxbool×1, notification×1 |
| DG - Dachgeschoss | 10 | changedetector×3, debouncer×3, genericdevice×1, notification×3 |
| DG - Dachgeschoss | 5 | knxbool×1, linkinput×1, scenes×1, setbool×1 |
| DG - Dachgeschoss | 4 | knxbool×1, scenes×1, setbool×1 |
| E1 - Flur | 9 | and×1, changedetector×1, knxbool×3, linkinput×1, memory×1, not×1 |
| E1 - Flur | 9 | init×1, knxbool×4, knxnumber×1, memory×1, motion_detection×1, not×1 |
| E2 - Gäste WC | 9 | and×1, changedetector×1, knxbool×3, linkinput×1, memory×1, not×1 |
| E3 - Büro | 5 | audioroom×1, knxbool×3, multiplexer×1 |
| E3 - Büro | 16 | delay×2, linkinput×2, memory×2, multiplexer×3, not×1, setpercentage×4, windowtreatments×2 |
| E3 - Büro | 36 | and×4, changedetector×4, knxbool×12, linkinput×4, memory×4, not×4 |
| E3 - Büro | 19 | init×1, knxbool×5, knxnumber×2, memory×2, motion_detection×1, multiplexer×1, not×2, pacer×1, scenes×1, setnumber×2 |
| E3 - Büro | 10 | init×1, interlock×1, knxbool×1, linkoutput×2, memory×1, multiplexer×2, not×1, scenes×1 |
| E4 - Wohnzimmer | 5 | knxbool×3, multiplexer×1, television×1 |
| E4 - Wohnzimmer | 19 | init×1, knxbool×5, knxnumber×2, memory×2, motion_detection×1, multiplexer×1, not×2, pacer×1, scenes×1, setnumber×2 |
| E4 - Wohnzimmer | 12 | init×1, interlock×1, knxbool×1, linkoutput×3, memory×1, multiplexer×3, not×1, scenes×1 |
| E5 - Esszimmer | 12 | init×1, interlock×1, knxbool×1, linkoutput×3, memory×1, multiplexer×3, not×1, scenes×1 |
| E6 - Küche | 16 | delay×1, gate×1, init×1, lights×2, memory×1, multiplexer×1, scenes×2, setbool×1, setpercentage×2 |
| E6 - Küche | 36 | and×4, changedetector×4, knxbool×12, linkinput×4, memory×4, not×4 |
| E6 - Küche | 5 | audioroom×1, knxbool×3, multiplexer×1 |
| E6 - Küche | 19 | init×1, knxbool×5, knxnumber×2, memory×2, motion_detection×1, multiplexer×1, not×2, pacer×1, scenes×1, setnumber×2 |
| E6 - Küche | 12 | init×1, interlock×1, knxbool×1, linkoutput×3, memory×1, multiplexer×3, not×1, scenes×1 |
| E6 - Küche Links | 16 | delay×2, linkinput×2, memory×2, multiplexer×3, not×1, setpercentage×4, windowtreatments×2 |
| E6 - Küche Rechts | 16 | delay×2, linkinput×2, memory×2, multiplexer×3, not×1, setpercentage×4, windowtreatments×2 |
| EG - Erdgeschoss | 35 | changedetector×1, knxbool×1, linkinput×1, memory×1, not×13, openclosedevice×13, or×4 |
| EG - Erdgeschoss | 18 | genericdevice×2, not×7, openclosedevice×7, or×2 |
| EG - Erdgeschoss | 50 | changedetector×15, debouncer×15, genericdevice×5, notification×15 |
| EG - Erdgeschoss | 38 | memory×1, multiplexer×1, not×13, notification×6, openclosedevice×13, or×3, scenes×1 |
| EG - Erdgeschoss | 7 | knxbool×2, linkinput×1, scenes×2, setbool×2 |
| EG - Erdgeschoss | 6 | knxbool×2, scenes×2, setbool×2 |
| EG - Erdgeschoss | 8 | knxbool×3, scenes×2, setbool×2 |
| EG - Erdgeschoss | 9 | knxbool×3, linkinput×1, scenes×2, setbool×2 |
| EG - Erdgeschoss | 15 | changedetector×3, knxbool×6, linkinput×3, memory×3 |
| G3 - Garten | 10 | init×1, interlock×1, knxbool×1, linkoutput×2, memory×1, multiplexer×2, not×1, scenes×1 |
| Garagentoröffnung bei Nummerschilderkennung | 8 | gate×1, knxbool×1, knxnumber×1, lookuptable×1, oneshot×1, openclosedevice×1 |
| Gasmelder Alarm | 6 | changedetector×2, knxbool×2, notification×2 |
| Gefriehrschrank - Türe auf | 29 | and×2, changedetector×1, chrono×1, compare×4, genericdevice×1, init×3, linkinput×1, linkoutput×1, multiplexer×1, not×3, notification×1, setnumber×6, t |
| Geladene Energie | 7 | divide×1, init×1, knxnumber×3, setnumber×1, subtract×1 |
| Initialisierung | 6 | delay×1, init×1, knxbool×1, linkinput×1, multiplexer×1 |
| K1 - Flur | 9 | init×1, knxbool×4, knxnumber×1, memory×1, motion_detection×1, not×1 |
| K2 - Garage | 9 | init×1, knxbool×4, knxnumber×1, memory×1, motion_detection×1, not×1 |
| KG - Kellergeschoss | 16 | changedetector×1, knxbool×1, linkinput×1, memory×1, not×5, openclosedevice×5, or×1 |
| KG - Kellergeschoss | 18 | memory×1, multiplexer×1, not×5, notification×4, openclosedevice×5, or×1, scenes×1 |
| KG - Kellergeschoss | 40 | changedetector×12, debouncer×12, genericdevice×4, notification×12 |
| KG - Kellergeschoss | 17 | knxbool×6, scenes×5, setbool×5 |
| KG - Kellergeschoss | 18 | knxbool×6, linkinput×1, scenes×5, setbool×5 |
| KG - Kellergeschoss | 10 | changedetector×2, knxbool×4, linkinput×2, memory×2 |
| KG - Kellergeschoss | 6 | changedetector×2, genericdevice×4 |
| Kühlschrank - Türe auf | 29 | and×2, changedetector×1, chrono×1, compare×4, genericdevice×1, init×3, linkinput×1, linkoutput×1, multiplexer×1, not×3, notification×1, setnumber×6, t |
| Luftfeuchtigkeit Alarm | 24 | changedetector×2, knxbool×10, linkinput×2, linkoutput×2, memory×2, or×2 |
| Luftfeuchtigkeit Alarm | 26 | changedetector×2, knxbool×12, linkinput×2, linkoutput×2, memory×2, or×2 |
| Lüftermodus - Automatik im Sensorprofil | 6 | and×1, linkinput×2, linkoutput×1, not×1 |
| Lüftermodus - Automatik im Szenenprofil | 14 | and×1, linkinput×9, linkoutput×1, or×1 |
| Lüftermodus - Manuell / Automatik | 7 | compare×1, init×1, knxnumber×1, linkoutput×1, setnumber×1 |
| Lüftermodus - Status senden | 7 | init×1, knxnumber×2, linkinput×1, memory×1, multiplexer×1 |
| Lüfterstufe - Manuell | 7 | debouncer×1, gate×1, knxnumber×1, linkinput×1, linkoutput×1, not×1 |
| Lüfterstufe - Sensormodus | 29 | and×3, debouncer×1, gate×1, linkinput×7, linkoutput×1, multiplexer×1, not×2, or×3, setbool×3, setnumber×3 |
| Lüfterstufe - Szenenmodus | 21 | gate×1, linkinput×9, linkoutput×1, multiplexer×1, setnumber×8 |
| Lüfterstufe setzen | 9 | knxbool×4, linkinput×3, lookuptable×1, multiplexer×1 |
| Meldung Bewässerung | 5 | changedetector×1, knxbool×1, not×1, notification×2 |
| Meldungen Sabotage | 12 | changedetector×4, knxbool×4, notification×4 |
| Meldungen Sicherungsbereich | 19 | changedetector×4, delay×1, linkinput×4, memory×1, multiplexer×1, not×1, notification×5, scenes×1 |
| Meldungen Sicherungsbereich | 6 | changedetector×2, knxbool×2, notification×2 |
| Meldungen Störung | 12 | changedetector×4, knxbool×4, notification×4 |
| Meldungen Terrasse EMA Extern Scharf | 16 | gate×1, knxbool×5, linkinput×2, multiplexer×1, notification×5, setbool×2 |
| Meldungen Wohnzimmer EMA Extern Scharf | 16 | gate×1, knxbool×5, linkinput×2, multiplexer×1, notification×5, setbool×2 |
| O1 - Flur | 16 | delay×2, linkinput×2, memory×2, multiplexer×3, not×1, setpercentage×4, windowtreatments×2 |
| O1 - Flur | 18 | and×2, changedetector×2, knxbool×6, linkinput×2, memory×2, not×2 |
| O1 - Flur (Gang) | 9 | init×1, knxbool×4, knxnumber×1, memory×1, motion_detection×1, not×1 |
| O1 - Flur (Treppe) | 9 | init×1, knxbool×4, knxnumber×1, memory×1, motion_detection×1, not×1 |
| O2 - Abstellraum | 16 | delay×2, linkinput×2, memory×2, multiplexer×3, not×1, setpercentage×4, windowtreatments×2 |
| O2 - Abstellraum | 9 | and×1, changedetector×1, knxbool×3, linkinput×1, memory×1, not×1 |
| O2 - Abstellraum | 10 | init×1, interlock×1, knxbool×1, linkoutput×2, memory×1, multiplexer×2, not×1, scenes×1 |
| O3 - Badezimmer Kinder | 16 | delay×2, linkinput×2, memory×2, multiplexer×3, not×1, setpercentage×4, windowtreatments×2 |
| O3 - Badezimmer Kinder | 9 | and×1, changedetector×1, knxbool×3, linkinput×1, memory×1, not×1 |
| O3 - Badezimmer Kinder | 16 | delay×1, gate×1, knxbool×4, multiplexer×1, not×3, or×1, scenes×1, setbool×1 |
| O3 - Badezimmer Kinder | 18 | debouncer×3, gate×1, genericdevice×1, linkinput×1, memory×1, not×2, setbool×1, windowtreatments×2 |
| O3 - Badezimmer Kinder | 13 | changedetector×1, init×1, interlock×1, knxbool×1, linkinput×1, linkoutput×2, memory×1, multiplexer×1, not×2, oneshot×1, scenes×1 |
| O3 - Badezimmer Kinder | 7 | genericdevice×1, linkinput×1, not×2, setbool×1 |
| O4 - Schlafzimmer Gregory | 8 | linkinput×2, memory×2, not×1, windowtreatments×2 |
| O4 - Schlafzimmer Gregory | 5 | audioroom×1, knxbool×3, multiplexer×1 |
| O4 - Schlafzimmer Gregory | 10 | init×1, interlock×1, knxbool×1, linkoutput×2, memory×1, multiplexer×2, not×1, scenes×1 |
| O4 - Schlafzimmer Luis | 10 | init×1, interlock×1, knxbool×1, linkoutput×2, memory×1, multiplexer×2, not×1, scenes×1 |
| O5 - Schlafzimmer Luis | 8 | linkinput×2, memory×2, not×1, windowtreatments×2 |
| O5 - Schlafzimmer Luis | 5 | audioroom×1, knxbool×3, multiplexer×1 |
| O6 - Schlafzimmer Eltern | 8 | linkinput×2, memory×2, not×1, windowtreatments×2 |
| O6 - Schlafzimmer Eltern | 5 | knxbool×3, multiplexer×1, television×1 |
| O6 - Schlafzimmer Eltern | 16 | delay×1, gate×1, knxbool×4, multiplexer×1, not×3, or×1, scenes×1, setbool×1 |
| O6 - Schlafzimmer Eltern | 10 | init×1, interlock×1, knxbool×1, linkoutput×2, memory×1, multiplexer×2, not×1, scenes×1 |
| O8 - Badezimmer Eltern | 16 | delay×2, linkinput×2, memory×2, multiplexer×3, not×1, setpercentage×4, windowtreatments×2 |
| O8 - Badezimmer Eltern | 9 | and×1, changedetector×1, knxbool×3, linkinput×1, memory×1, not×1 |
| O8 - Badezimmer Eltern | 21 | debouncer×3, gate×1, genericdevice×1, linkinput×2, memory×1, multiplexer×1, not×3, setbool×1, windowtreatments×2 |
| O8 - Badezimmer Eltern | 10 | genericdevice×1, linkinput×2, multiplexer×1, not×3, setbool×1 |
| O8 - Badezimmer Eltern | 16 | delay×1, gate×1, knxbool×4, multiplexer×1, not×3, or×1, scenes×1, setbool×1 |
| O8 - Badezimmer Eltern | 20 | changedetector×2, init×1, interlock×1, knxbool×1, linkinput×2, linkoutput×4, memory×1, multiplexer×2, not×3, oneshot×2, scenes×1 |
| OG - Obergeschoss | 22 | changedetector×1, knxbool×1, linkinput×1, memory×1, not×8, openclosedevice×8, or×1 |
| OG - Obergeschoss | 21 | genericdevice×7, not×7, openclosedevice×7 |
| OG - Obergeschoss | 60 | changedetector×18, debouncer×18, genericdevice×6, notification×18 |
| OG - Obergeschoss | 27 | memory×1, multiplexer×1, not×8, notification×7, openclosedevice×8, or×1, scenes×1 |
| OG - Obergeschoss | 21 | knxbool×8, linkinput×1, scenes×6, setbool×6 |
| OG - Obergeschoss | 20 | knxbool×8, scenes×6, setbool×6 |
| OG - Obergeschoss | 25 | changedetector×5, knxbool×10, linkinput×5, memory×5 |
| OG - Obergeschoss | 16 | knxbool×5, scenes×5, setbool×5 |
| OG - Obergeschoss | 21 | and×1, knxbool×7, linkinput×1, scenes×5, setbool×5 |
| PV Erzeugung Gesamt | 9 | add×1, compare×1, init×1, knxnumber×3, memory×1, setnumber×1 |
| Relais 1 - Garagentor sperren | 8 | knxbool×4, not×2 |
| Relais 2 - Garagentor fahren | 3 | knxbool×2 |
| Scharfschaltung bei Gute Nacht | 3 | knxbool×2, scenes×1 |
| Sicherungsbereich Status | 8 | knxbool×4, linkoutput×4 |
| Sommer/Winter | 11 | changedetector×1, compare×1, init×2, knxbool×1, linkinput×1, memory×1, multiplexer×1, setnumber×1, weatherstation×1 |
| Sonnenaufgang oder 6:00 | 18 | daylight×1, init×2, linkoutput×1, lookuptable×1, memory×1, modulo×1, multiplexer×2, numberincrement×1, setnumber×2, when×2 |
| Sonnenaufgang und 6:00 | 18 | daylight×1, init×2, linkoutput×1, lookuptable×1, memory×1, modulo×1, multiplexer×2, numberincrement×1, setnumber×2, when×2 |
| Sonnenaufgang und 7:10/9:00 | 22 | daylight×1, delay×1, init×2, linkoutput×1, lookuptable×1, memory×1, modulo×1, multiplexer×2, numberincrement×1, setnumber×2, when×3 |
| Sonnenaufgang und 7:45/9:00 | 22 | daylight×1, delay×1, init×2, linkoutput×1, lookuptable×1, memory×1, modulo×1, multiplexer×2, numberincrement×1, setnumber×2, when×3 |
| Sonnenuntergang oder 21:30 | 19 | daylight×1, delay×1, init×2, linkoutput×1, lookuptable×1, memory×1, modulo×1, multiplexer×2, numberincrement×1, setnumber×2, when×2 |
| Sonnenuntergang oder 22:00 | 19 | daylight×1, delay×1, init×2, linkoutput×1, lookuptable×1, memory×1, modulo×1, multiplexer×2, numberincrement×1, setnumber×2, when×2 |
| Sony TV Status - Schlafzimmer Eltern | 10 | debouncer×1, init×1, knxbool×4, knxpercentage×2, memory×1, television×1 |
| Sony TV Status - Wohnzimmer | 10 | debouncer×1, init×1, knxbool×4, knxpercentage×2, memory×1, television×1 |
| Statustext - DC Fehlerstrom | 11 | knxnumber×1, knxstring×1, lookuptable×1, multiplexer×1, setstring×7 |
| Statustext - Fehlerzustand | 9 | knxnumber×1, knxstring×1, lookuptable×1, multiplexer×1, setstring×5 |
| Statustext - IEC61851 | 9 | knxnumber×1, knxstring×1, lookuptable×1, multiplexer×1, setstring×5 |
| Statustext - Ladecontroller | 9 | knxnumber×1, knxstring×1, lookuptable×1, multiplexer×1, setstring×5 |
| Statustext - Lademodus | 7 | knxnumber×1, knxstring×1, lookuptable×1, multiplexer×1, setstring×3 |
| Statustext - Schütz Fehler | 17 | knxnumber×1, knxstring×1, lookuptable×1, multiplexer×1, setstring×13 |
| Strom - Einspeisung | 15 | init×1, knxnumber×8, multiply×4, setnumber×1 |
| Strom - Einspeisung Gesamt | 9 | add×1, compare×1, init×1, knxnumber×3, memory×1, setnumber×1 |
| Strom - Netzbezug Gesamt | 9 | add×1, compare×1, init×1, knxnumber×3, memory×1, setnumber×1 |
| Strom - Wirkleistung Gesamt | 10 | compare×1, init×1, knxnumber×3, memory×1, setnumber×1, subtract×1 |
| Trockner - Programmaktionen | 15 | audio_notification×1, gate×1, genericdevice×1, knxbool×1, linkinput×2, multiplexer×2, notification×1, setbool×3 |
| Trockner - Status | 13 | compare×1, delay×2, genericdevice×1, init×1, linkoutput×1, multiplexer×1, not×1, setbool×2, setnumber×1 |
| Trockner - Statusänderung | 16 | compare×2, debouncer×2, gate×1, linkinput×1, linkoutput×2, memory×1, not×1, setbool×2 |
| Trockner - Strom sparen | 10 | gate×1, genericdevice×1, linkinput×1, multiplexer×1, not×1, setbool×1, when×2 |
| Waschmaschine - Programmaktionen | 15 | audio_notification×1, gate×1, genericdevice×1, knxbool×1, linkinput×2, multiplexer×2, notification×1, setbool×3 |
| Waschmaschine - Status | 13 | compare×1, delay×2, genericdevice×1, init×1, linkoutput×1, multiplexer×1, not×1, setbool×2, setnumber×1 |
| Waschmaschine - Statusänderung | 16 | compare×2, debouncer×2, gate×1, linkinput×1, linkoutput×2, memory×1, not×1, setbool×2 |
| Waschmaschine - Strom sparen | 10 | gate×1, genericdevice×1, linkinput×1, multiplexer×1, not×1, setbool×1, when×2 |
| Wasser - Durchfluss | 18 | gate×2, init×1, knxbool×1, knxnumber×3, multiplexer×2, multiply×2, not×1, setnumber×3 |
| Wasser - Erweiteter Durchflussalarm | 28 | delay×6, init×2, knxbool×4, memory×2, multiplexer×2, not×2, notification×2, setbool×4 |
| Wassermelder Alarm | 21 | changedetector×7, knxbool×7, notification×7 |
| Zehnder Automatik deaktivieren | 4 | knxbool×1, linkinput×1, setbool×1 |
| Zentral | 10 | init×1, interlock×1, linkoutput×3, memory×1, multiplexer×3, scenes×1 |
