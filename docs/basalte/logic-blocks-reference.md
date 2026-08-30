# Basalte Studio logic blocks

Reference for every logic block, captured from `docs.basalte.live/basalte/logic/blocks`
on 2026-06-05. Inputs and outputs are written as `name` (type) — description;
"Trigger" means only `true` events are processed.

**Contents:** [Communication](#communication) · [Convert](#convert) · [Device](#device) · [Home](#home) · [KNX](#knx) · [Logic](#logic) · [Math](#math) · [State](#state) · [String](#string) · [Time](#time) · [Link](#link)

---

## Communication

### Email/App Notification

`communication/notification` – Sendet eine Benachrichtigung an die Basalte Home-App oder an eine/mehrere E-Mail-Adressen. E-Mail kommt von einem No-Reply-Account von Basalte. Limit: 5/Minute, 100/24 h. Push erhalten nur Admin-User.

- **Properties:** Email Addresses (eine/mehrere, optional je nach Typ); Title (string); Message Body (string)
- **Inputs:** `trigger` (boolean) – bei Auslösung wird die Benachrichtigung gesendet

### TCP client

`communication/tcp-client` – Interaktion mit einem TCP-Server.

- **Properties:** IP; Port (1–65535, Default 23); Delimiter (Default `\r`, nur beim Empfang genutzt)
- **Inputs:** `send` (string) – Nachrichten an den TCP-Server (Delimiter wird nicht angehängt)
- **Outputs:** `received` (string) – empfangene Nachrichten (ohne Delimiter); `connected` (boolean) – Verbindungs-Feedback
- **Behaviour:** Reconnect-Versuch alle 30 s nach Fehlschlag

### UDP emitter

`communication/udp-emitter` – Sendet UDP-Nachrichten an IP/Port.

- **Properties:** IP; Port (1–65535, Default 5000)
- **Inputs:** `send` (string) – Nachrichten an den UDP-Empfänger

---

## Convert

### Number to Percentage

`convert/number-to-percentage` – Wandelt Zahl in Prozent: `(input – min) / (max – min)`.

- **Properties:** Min (Default 0); Max (Default 100)
- **Inputs:** `in` (number)
- **Outputs:** `out` (percentage)

### Percentage to Number

`convert/percentage-to-number` – Wandelt Prozent in Zahl: `(input · (max – min)) + min`.

- **Properties:** Min (Default 0); Max (Default 100)
- **Inputs:** `in` (percentage)
- **Outputs:** `out` (number)

### String to Number

`convert/string-to-number` – Interpretiert eine Zahl aus einem String.

- **Properties:** Base (2 = binär, 10 = dezimal, 16 = hex; Default 10)
- **Inputs:** `in` (string)
- **Outputs:** `out` (number) – falls gefunden
- **Behaviour:** Bei ungültigen Zeichen wird nichts gesendet; negative und Dezimalzahlen parsbar; Whitespace getrimmt

### To String

`convert/to-string` – Wandelt beliebigen Datentyp in einen String.

- **Inputs:** `in` (generic)
- **Outputs:** `out` (string)

---

## Device

### Auro RS485

`device/auro-rs485` – _(Seite „under construction" – keine Doku vorhanden.)_

### AV Matrix

`device/av-matrix` – Steuert eine IP-AV-Matrix aus dem Projekt.

- **Properties:** Select device
- **Inputs:** `on/off` (boolean); `In->Out#` (number) – Eingang # auf Ausgang routen
- **Outputs:** `on/off` (boolean) Power-Feedback; `In->Out#` (number) – welcher Eingang auf diesem Ausgang liegt

### AV Receiver

`device/av-receiver` – Steuert einen IP-AV-Receiver aus dem Projekt.

- **Properties:** Select device
- **Inputs:** `on/off` (boolean); `volume` (percentage, Main-Zone); `mute` (boolean); `input` (number)
- **Outputs:** `on/off` (boolean); `volume` (percentage); `mute` (boolean); `input` (number)
- **Behaviour:** Feedback-Verzögerung je nach Marke/Typ

### BO Sensor

`device/bo-sensor` – Verbindet sich mit BO.sensor-Auslösern.

- **Properties:** Select device; Input (vorauswählen oder „Any input"); Group
- **Outputs:** `enabled` (boolean, optional bei vorgewähltem Input); `control` (boolean) – mehrere Trigger je nach gewählten Controls
- **Behaviour:** Alle Ausgänge sind Trigger

### Door / Window / Gate

`device/door-window-gate` – Steuert Tür/Fenster/Tor.

- **Properties:** Select device
- **Inputs:** `open` (boolean); `close` (boolean); `stop` (boolean); `trigger` (boolean, toggelt open/close/stop) – je optional nach Typ
- **Outputs:** `closed` (boolean) – true wenn vollständig geschlossen (optional bei aktiviertem Feedback)
- **Behaviour:** Alle Eingänge sind Trigger

### Ekey fingerprint

`device/ekey-fingerprint` – true bei bekanntem User mit gepaartem Finger.

- **Properties:** Select device; User-finger pairs
- **Outputs:** `Any known user: Any finger` (boolean)

### Generic Device

`device/generic-device` – Steuert ein generisches Gerät aus dem Projekt. Ein-/Ausgänge je nach Control-Typ.

- **Controls:** Trigger Button (boolean, nur Output); Toggle Button (boolean); Percentage Slider (percentage); Number Indicator (number); Percentage Indicator (percentage)

### IR Device

`device/ir-device` – Sendet IR-Codes über einen Basalte Flex.

- **Properties:** Select device; IR code set
- **Inputs:** `control value` (number); `IR code` (boolean) – mehrere Codes für Einzelsteuerung
- **Behaviour:** Außer `control value` sind alle Eingänge Trigger; IR ist unidirektional, kein Feedback

### Lights

`device/lights` – Steuert ein Lighting-Device aus dem Projekt.

- **Properties:** Select device
- **Inputs:** `on/off` (boolean); `brightness` (percentage); `white` (percentage, RGBW); `temperature` (number, Kelvin); `hue/sat/bri` (number, RGB(W)); `hue/sat` (number, Helligkeit behalten) – je optional nach Typ
- **Outputs:** Feedbacks zu `on/off`, `brightness`, `white`, `temperature`, `hue/sat/bri`

### Miro Preset

`device/miro-preset` – Belegt die 3 Preset-Tasten am Miro.

- **Properties:** Select (Raum)
- **Outputs:** `Preset #` (boolean) – true bei Tastendruck #
- **Behaviour:** Alle Ausgänge sind Trigger

### Scene Controller

`device/scenes` – Steuert einen Scene-Controller aus dem Projekt.

- **Properties:** Select controller
- **Inputs:** `scene` (boolean) – mehrere Trigger zum Aktivieren der jeweiligen Szene
- **Outputs:** `scene` (boolean) – Feedback der aktivierten Szene
- **Behaviour:** Alle Ein-/Ausgänge sind Trigger

### Serial Device

`device/serial-device` – Kommunikation über RS232/RS485 via Basalte Flex.

- **Properties:** Select device
- **Inputs:** `in` (string) – Daten senden
- **Outputs:** `out` (string) – empfangene Daten
- **Behaviour:** Output ist ein Datenstrom ohne Delimiter – ggf. `split`-Node nutzen

### Shades

`device/shades` – Steuert Beschattung/Fensterbehandlung aus dem Projekt.

- **Properties:** Select device
- **Inputs:** `position` (percentage, absolut); `rotation` (percentage, Lamellen, optional); `open`/`close`/`stop` (boolean, Trigger)
- **Outputs:** `position` (percentage); `rotation` (percentage, optional); `closed` (boolean)

### Television

`device/television` – Steuert einen IP-Fernseher aus dem Projekt.

- **Properties:** Select device; Controls (zusätzliche Steuerbefehle aktivieren)
- **Inputs:** `on/off` (boolean); `volume` (percentage, absolut); `mute` (boolean); `control` (boolean, Trigger)
- **Outputs:** `on/off` (boolean); `volume` (percentage); `muted` (boolean)
- **Behaviour:** Feedback-Verzögerung je nach Marke/Typ; Zusatz-Controls sind Trigger

### Thermostat

`device/thermostat` – Steuert ein Thermostat aus dem Projekt.

- **Properties:** Select device
- **Inputs:** `setpoint` (number, Einheit je Projektkonfig); `mode: off/auto/heating/cooling` (boolean, Trigger, je optional); `fan: off/auto/low/medium/high` (boolean, Trigger, je optional)
- **Outputs:** `setpoint` (number); `mode: …`-Feedbacks (boolean Trigger); `fan: …`-Feedbacks (boolean Trigger); `temperature` (number); `humidity` (percentage); `heating active` (boolean); `cooling active` (boolean)
- **Behaviour:** Alle boolean Ein-/Ausgänge außer `heating/cooling active` sind Trigger

### Weather Station

`device/weather-station` – Liefert die aktuellen Werte einer Wetterstation im Projekt (auswählbar wenn im KNX-Tab verbunden).

- **Properties:** Select device
- **Outputs:** `Temperature` (number); `Humidity` (number); `Brightness` (number); `Wind speed` (number); `Air pressure` (number); `Rain detected` (boolean); `Frost detected` (boolean)

---

## Home

### Access Control

`home/access-control` – Regeln für Zutrittskontrolle.

- **Properties:** Person; Identifier (Keycard, PIN, Fingerprint, Access-App, QR-Code); Door; Event (Trigger bei granted/denied access); „+" für mehrere Regeln

### Area

`home/area` – _(Leere Stub-Seite – keine Doku vorhanden.)_

### Audio Alert

`home/audio-alert` – Startet/stoppt eine Audio-Notification; sendet true solange sie spielt.

- **Properties:** Notification (Verknüpfung aus dem Music-Tab)
- **Inputs:** `play` – Notification starten/stoppen
- **Outputs:** `playing` – Status-Feedback

### AV Room

`home/av-room` – Repräsentiert einen AV-Raum im Projekt.

- **Properties:** Select Room
- **Inputs:** `on/off` (boolean); `Cobra Source` (number); `AV Source` (string, startet Automagic-Sequenz); `volume` (percentage, absolut); `volume delta` (percentage, relativ); `mute` (boolean)
- **Outputs:** Feedbacks zu `on/off` (boolean), `Cobra source` (number), `AV Source` (string), `volume` (percentage), `mute` (boolean)

### AV Source

`home/av-source` – Liefert den Namen der AV-Source als String.

- **Properties:** Select (Gerät, dessen interner Name als String)
- **Inputs:** `Trigger` (string) – true-Event erzeugt den AV-Source-String
- **Outputs:** `AV Source` – interner Aufrufname der AV-Source als String

### Input Detection

`home/input-detection` – Sendet true solange ein Audio-Input aktiv ist.

- **Properties:** Select device; Debounce deactivation (Retrigger-Zeit)
- **Outputs:** `out` (boolean) – Feedback des gewählten Inputs

### Motion Detection

`home/motion-detection` – Anpassbares Verhalten von Bewegungsmelder-Signalen.

- **Properties:** Debounce motion off; Brightness when idle; Brightness on motion; Light dependent Switching (Checkbox für Lux-Schwelle); Lux threshold (nur aktivieren wenn Lux < Schwelle)
- **Inputs:** `enable` (boolean); `motion` (boolean, vom Sensor); `lux` (number)
- **Outputs:** `out` (boolean – true bei Bewegung, false nach konfigurierbarer Zeit ohne Bewegung); `brightness` (percentage); `scene on` (boolean Trigger); `scene off` (boolean Trigger)

### Stream

`home/stream` – Steuert einen dedizierten Stream und liefert Feedback.

- **Properties:** Select device; Select preset (KNX-Wert aus Music-Tab)
- **Inputs:** `Play` (boolean); `Shuffle` (boolean); `Repeat` (boolean); `Preset` (number)
- **Outputs:** Feedbacks zu `Play` (boolean), `Shuffle` (boolean), `Repeat` (boolean)

---

## KNX

> Alle KNX-Nodes: Eingang und Ausgang gleichzeitig zu verbinden ist nicht möglich. Mehrfaches Senden desselben Werts erzeugt jeweils ein KNX-Paket. Properties jeweils: `name` (Node-Bezeichner), `type` (KNX-DPT), `address` (Gruppenadresse).

### KNX bool

`knx/bool` – Senden an / Empfangen von einer 1-bit-Gruppenadresse.

- **Properties:** type Default `1.001` (1-bit Switch)
- **Inputs:** `in` (boolean) – an den Bus
- **Outputs:** `out` (boolean) – vom Bus

### KNX number

`knx/number` – Senden/Empfangen als numerischer Typ.

- **Inputs:** `in` (number) · **Outputs:** `out` (number)

### KNX percentage

`knx/percentage` – Senden/Empfangen als Prozent-Typ.

- **Inputs:** `in` (percentage) · **Outputs:** `out` (percentage)

### KNX string

`knx/string` – Senden/Empfangen als String-Typ.

- **Inputs:** `in` (string) · **Outputs:** `out` (string)

---

## Logic

### AND

`logic/and` – `out` high, wenn alle Eingänge gleichzeitig high; sonst low.

- **Inputs:** `in` (boolean) – mehrere · **Outputs:** `out` (boolean)
- **Behaviour:** Unverbundene Eingänge ignoriert; ≥2 Eingänge, Default low; jedes Input-Event löst Output-Event aus (auch ohne Änderung)

### Compare to

`logic/compare-to` – Vergleicht A und B (number, percentage oder string); `out` high wenn Bedingung wahr.

- **Operatoren:** `A > B`, `A >= B`, `A == B`, `A != B`, `A <= B`, `A < B`
- **Inputs:** `A` (generic); `B` (generic) · **Outputs:** `out` (boolean)
- **Behaviour:** Jedes Input-Event löst Output-Event aus (auch ohne Änderung)

### Gate

`logic/gate` – Lässt Eingänge zu Ausgängen durch, solange `enable` high; bei low getrennt.

- **Properties:** „Ignore inputs when disabled" – true: Enable sendet nichts (Default); false: Enable sendet letzte bekannte Werte
- **Inputs:** `enable` (boolean, Default geschlossen); `in #` (generic) · **Outputs:** `out #` (generic)
- **Behaviour:** Mehrere Ein-/Ausgänge mit je eigenem Typ möglich

### Interlock

`logic/interlock` – Merkt sich den zuletzt auf high gegangenen Eingang; der vorherige Ausgang geht low, bevor der nächste high geht. Nur ein Ausgang gleichzeitig high.

- **Inputs:** `reset` (boolean, alle Ausgänge low); `in #` (boolean) · **Outputs:** `out #` (boolean)
- **Behaviour:** Alle Eingänge sind Trigger

### LUT (Lookup Table)

`logic/lookup-table` – Vergleicht einen Eingangswert mit einer Werteliste; passender Wert triggert den zugehörigen Ausgang, sonst `default`.

- **Node options:** Type select (Number, Percentage oder String)
- **Properties:** Values (Vergleichsliste)
- **Inputs:** `in` (number/percentage/string) · **Outputs:** `value` (boolean, je Listeneintrag); `default` (boolean)
- **Behaviour:** Alle Ausgänge sind Trigger (nur true)

### MUX

`logic/mux` – Führt mehrere Eingänge zu einem Ausgang zusammen.

- **Inputs:** `in` (generic) – mehrere · **Outputs:** `out` (generic) – in Empfangsreihenfolge
- **Behaviour:** Studio fügt einen MUX automatisch ein, wenn mehrere Outputs auf einen Input gelegt werden; verbundener Typ gilt für alle Ein-/Ausgänge

### NOT

`logic/not` – Invertiert das Eingangssignal (high↔low).

- **Inputs:** `in` (boolean) · **Outputs:** `out` (boolean)
- **Behaviour:** Jedes Input-Event löst Output-Event aus

### OR

`logic/or` – `out` high, wenn mind. ein Eingang high; sonst low.

- **Inputs:** `in` (boolean) – mehrere · **Outputs:** `out` (boolean)
- **Behaviour:** Unverbundene Eingänge ignoriert; ≥2 Eingänge, Default low; jedes Input-Event löst Output-Event aus

---

## Math

### Absolute

`math/absolute` – Absolutbetrag des Eingangs.

- **Inputs:** `in` (number) · **Outputs:** `out` (number, nur positiv)

### Add

`math/add` – Addiert 2 Werte.

- **Inputs:** `in` (number, triggert); `addend` (number) · **Outputs:** `out` (number)
- **Behaviour:** Nur ein Event auf `in` triggert den Output

### Average

`math/average` – Gibt den Mittelwert **aller Eingänge** aus (räumlich, kein Zeitbezug).

- **Inputs:** `in` (number) – mehrere · **Outputs:** `out` (number)
- **Behaviour:** Ein Eingang zählt erst ab gesetztem Wert; unverbundene ignoriert; jedes Input-Event löst Output-Event aus

### Ceil

`math/ceil` – Rundet auf die nächste Ganzzahl auf.

- **Inputs:** `in` (number) · **Outputs:** `out` (number ≥ Eingang)

### Clamp

`math/clamp` – Begrenzt den Eingang zwischen min und max.

- **Inputs:** `in` (number); `min` (number); `max` (number) · **Outputs:** `out` (number)
- **Behaviour:** Nur Event auf `in` triggert; > max → max; < min → min

### Divide

`math/divide` – Dividiert 2 Werte.

- **Inputs:** `in` (number, triggert); `divisor` (number) · **Outputs:** `out` (number)
- **Behaviour:** Nur Event auf `in` triggert; Division durch 0 tut nichts

### Exponent

`math/exponent` – `in` hoch `exponent`.

- **Inputs:** `in` (number, triggert); `exponent` (number) · **Outputs:** `out` (number)
- **Behaviour:** Nur Event auf `in` triggert

### Floor

`math/floor` – Rundet auf die nächste Ganzzahl ab.

- **Inputs:** `in` (number) · **Outputs:** `out` (number ≤ Eingang)

### Modulo

`math/modulo` – Rest der euklidischen Division `in` / `modulus`.

- **Inputs:** `in` (number, triggert); `modulus` (number) · **Outputs:** `out` (number)
- **Behaviour:** Nur Event auf `in` triggert; Modulus 0 tut nichts

### Moving average

`math/moving-average` – Mittelwert eines Datensatzes der zuletzt empfangenen Werte (FIFO, **Sample-basiert, kein Zeitfenster**).

- **Properties:** Min samples (Default 1); Max samples (Default 10)
- **Inputs:** `in` (number) – Wert zum Datensatz hinzufügen · **Outputs:** `out` (number)
- **Behaviour:** Output ab Erreichen der Min-Samples; bei vollem Satz fällt der älteste Wert raus

### Multiply

`math/multiply` – Multipliziert 2 Werte.

- **Inputs:** `in` (number, triggert); `multiplicand` (number) · **Outputs:** `out` (number)
- **Behaviour:** Nur Event auf `in` triggert

### Random

`math/random` – Erzeugt einen Zufallswert im Bereich.

- **Properties:** Min; Max; Step Size
- **Inputs:** `trigger` (number) – Generierung auslösen · **Outputs:** `out` (number)

### Round

`math/round` – Rundet auf die nächste Ganzzahl gemäß Präzision (z. B. „Round to 100": >50→100, <50→0).

- **Properties:** Round to (Präzision, Default 1)
- **Inputs:** `in` (number) · **Outputs:** `out` (number)

### Square root

`math/square_root` – Quadratwurzel des Eingangs.

- **Inputs:** `in` (number) · **Outputs:** `out` (number)

### Subtract

`math/subtract` – Subtrahiert 2 Werte.

- **Inputs:** `in` (number, triggert); `subtrahend` (number) · **Outputs:** `out` (number)
- **Behaviour:** Nur Event auf `in` triggert

### Sum

`math/sum` – Addiert 2 oder mehr Werte.

- **Inputs:** `in` (number) – mehrere · **Outputs:** `out` (number)

---

## State

### Change Detector

`state/change-detector` – `changed` = true bei geändertem Eingang gegenüber dem vorherigen, false bei gleichem Event.

- **Properties:** Checkbox „Emit 'false' when no change is detected"
- **Inputs:** `value` (generic) · **Outputs:** `changed` (boolean); `new value` (generic, Echo des Eingangs)

### Home Page Message

`state/home-page-message` – Zeigt/versteckt eine vordefinierte Meldung auf der Home-Seite der App.

- **Properties:** Title; Body; Type (`Default` oder `Alarm`)
- **Inputs:** `active` (boolean) – zeigt/versteckt je nach Event
- **Behaviour:** Meldung wird angezeigt solange Input true; Alarm-Meldungen zuerst

### Init

`state/init` – Sendet einen einzelnen Trigger, nachdem die Initialkonfiguration geladen ist.

- **Outputs:** `out` (boolean) – true nach jedem Systemneustart

### Memory

`state/memory` – Speichert Werte (persistent über Neustart) und gibt sie bei Bedarf aus.

- **Properties:** Passthrough (Eingänge direkt auf Ausgang)
- **Inputs:** `trigger` (boolean) – alle gespeicherten Werte ausgeben; `in #` (generic) – Wert # speichern · **Outputs:** `out #` (generic) – Wert # abrufen
- **Behaviour:** `trigger` nur true; Werte bleiben auch nach Stromausfall erhalten

### Number Increment

`state/number-increment` – Addiert/subtrahiert einen Delta-Wert, begrenzt durch min/max.

- **Properties:** Delta; Minimum; Maximum
- **Inputs:** `state` (number, setzt aktuellen Wert); `up` (boolean, +Delta); `down` (boolean, −Delta) · **Outputs:** `out` (number)
- **Behaviour:** `up`/`down` sind Trigger

### Percentage Increment

`state/percentage-increment` – Wie Number Increment, aber für Prozentwerte.

- **Properties:** Delta; Minimum; Maximum
- **Inputs:** `state` (percentage); `up` (boolean); `down` (boolean) · **Outputs:** `out` (percentage)
- **Behaviour:** `up`/`down` sind Trigger

### Set Bool

`state/set-bool` – Sendet einen vordefinierten boolean bei true-Event.

- **Properties:** Value
- **Inputs:** `trigger` (boolean) · **Outputs:** `out` (boolean)

### Set Colour

`state/set-colour` – Sendet eine vordefinierte Farbe (32-bit `HHHHHHHH|HHHHHHHH|SSSSSSSS|BBBBBBBB`: 2 Byte Hue, 1 Byte Sat, 1 Byte Brightness) bei true-Event.

- **Properties:** Value
- **Inputs:** `trigger` (boolean) · **Outputs:** `out` (number)

### Set Number

`state/set-number` – Sendet eine vordefinierte Zahl bei true-Event.

- **Properties:** Value · **Inputs:** `trigger` (boolean) · **Outputs:** `out` (number)

### Set Percentage

`state/set-percentage` – Sendet einen vordefinierten Prozentwert bei true-Event.

- **Properties:** Value · **Inputs:** `trigger` (boolean) · **Outputs:** `out` (percentage)

### Set String

`state/set-string` – Sendet einen vordefinierten String bei true-Event.

- **Properties:** Value · **Inputs:** `trigger` (boolean) · **Outputs:** `out` (string)

### Set/Reset

`state/set-reset` – Boolescher Ausgangszustand, gesteuert über drei Trigger-Eingänge (SR-Latch).

- **Inputs:** `set` (boolean, → high); `reset` (boolean, → low); `toggle` (boolean, umschalten) · **Outputs:** `out` (high/low)
- **Behaviour:** Alle Eingänge sind Trigger; jedes Input-Event löst Output-Event aus

---

## String

### find

`string/find` – Findet ein (Teil-)String-Muster.

- **Properties:** Pattern
- **Inputs:** `in` (string) · **Outputs:** `out` (string, erster Treffer; nichts wenn kein Treffer); `found` (boolean)

### length

`string/length` – Anzahl der Bytes (nicht Zeichen) des Eingangs.

- **Inputs:** `in` (string) · **Outputs:** `out` (number)
- **Behaviour:** Ignoriert Encoding, zählt Bytes (z. B. „€" in UTF-8 = 3 Bytes)

### replace

`string/replace` – Ersetzt alle Treffer eines Musters durch einen String (Captures möglich).

- **Properties:** Pattern; Replace by
- **Inputs:** `in` (string) · **Outputs:** `out` (string)
- **Behaviour:** Ohne Treffer wird der Originalstring gesendet

### reverse

`string/reverse` – Kehrt den String um (byteweise).

- **Inputs:** `in` (string) · **Outputs:** `out` (string)

### split

`string/split` – Puffert den Eingang bis ein Delimiter gefunden wird (oder Kapazität überschritten).

- **Properties:** Delimiter (kann Pattern sein, Default `\r\n`)
- **Inputs:** `in` (string) · **Outputs:** `out` (string, ohne Delimiter)
- **Behaviour:** Puffer max. 1000 Zeichen; Delimiter darf nicht leer sein

### substring

`string/substring` – Filtert einen Teil aus einem längeren String.

- **Properties:** From; To
- **Inputs:** `in` (string) · **Outputs:** `out` (string)

### to lowercase

`string/to-lowercase` – Wandelt Großbuchstaben in Kleinbuchstaben.

- **Inputs:** `in` (string) · **Outputs:** `out` (string)

### to uppercase

`string/to-uppercase` – Wandelt Kleinbuchstaben in Großbuchstaben.

- **Inputs:** `in` (string) · **Outputs:** `out` (string)

### trim

`string/trim` – Entfernt Whitespace links und rechts.

- **Inputs:** `in` (string) · **Outputs:** `out` (string)

### trim left

`string/trim-left` – Entfernt Whitespace links.

- **Inputs:** `in` (string) · **Outputs:** `out` (string)

### trim right

`string/trim-right` – Entfernt Whitespace rechts.

- **Inputs:** `in` (string) · **Outputs:** `out` (string)

---

## Time

### Chrono

`time/chrono` – Misst Zeit exakt (Stoppuhr).

- **Properties:** Increment every (Zeitbasis, Default second); Reset when enabled
- **Inputs:** `enable` (boolean, Zählung starten/fortsetzen); `reset` (boolean, auf 0)
- **Outputs:** `second` / `minute` / `hour` (number) – gemessene Zeit, gesteuert über `enable`
- **Behaviour:** `reset` ist Trigger

### Day Of the Week (DOW)

`time/day-of-the-week` – Geht je nach aktuellem Wochentag (und Projekt-Standort) high/low. Update bei Start und täglich um 0:00.

- **Outputs:** `monday` … `sunday` (boolean) – high am jeweiligen Tag

### Daylight

`time/daylight` – Triggert Tageslicht-Events anhand des Projekt-Standorts.

- **Outputs:** `sunrise` (boolean, Trigger); `sunset` (boolean, Trigger); `daytime` (boolean, high Sonnenauf→untergang); `nighttime` (boolean)
- **Behaviour:** Sunrise/sunset sind Trigger; daytime/nighttime setzen auch beim Start den korrekten Zustand

### Debouncer

`time/debouncer` – Leitet ein Event erst weiter, wenn der Timeout ohne neues Event abgelaufen ist.

- **Properties:** Time (ms)
- **Inputs:** `in` (generic) · **Outputs:** `out` (generic, letztes Event nach Timeout)

### Delay

`time/delay` – Verzögert das Setzen des Ausgangs; die Verzögerung beeinflusst auch den Reset. (On-Delay mit Cancel.)

- **Properties:** Delay (ms)
- **Inputs:** `trigger` (boolean, nach Delay wird true gesendet); `rest` (boolean, true bricht ein ausstehendes verzögertes Event ab)
- **Outputs:** `out` (boolean, true nach der Verzögerung)
- **Behaviour:** Ein-/Ausgänge sind Trigger, nur true wird verarbeitet/gesendet

### Duration stepper

`time/duration-stepper` – Mehrere Schritte mit variabler Verzögerung und/oder Dauer pro Schritt.

- **Properties:** Variable duration (an: Variablen verbindbar; aus: feste Tabellenwerte); Delay / Duration pro Step (Sekunden)
- **Inputs:** `Trigger` (boolean, Start); `Reset` (boolean, stoppt aktive Events); `Enable` (boolean, starten/fortsetzen); `Enable step #` (boolean, Schritt überspringen wenn aus); `Duration step #` (number)
- **Outputs:** `Step #` (boolean, true für definierte Dauer)

### Oneshot

`time/oneshot` – Hält den Ausgang nach Trigger für eine vordefinierte Zeit high, dann low.

- **Properties:** High time (ms); Retriggerable (Default false – wenn gesetzt, bleibt high solange innerhalb der High-Zeit nachgetriggert)
- **Inputs:** `trigger` (boolean); `reset` (boolean, bricht ausstehendes Event ab) · **Outputs:** `out` (boolean)
- **Behaviour:** Eingänge sind Trigger

### Oscillator

`time/oscillator` – Oszilliert zwischen high und low gemäß eingestellter Zeiten.

- **Properties:** High time (ms); Retriggerable (Default false)
- **Inputs:** `trigger` (boolean); `reset` (boolean) · **Outputs:** `out` (boolean)
- **Behaviour:** Default deaktiviert; Output high beim Aktivieren, low beim Deaktivieren

### Pacer

`time/pacer` – Stellt sicher, dass Events mit konstantem Mindestabstand gesendet werden; frühere Events werden bis zu einem Maximum gepuffert.

- **Properties:** Buffer size; Time (min. ms zwischen Events)
- **Inputs:** `in` (generic) · **Outputs:** `out` (generic)
- **Behaviour:** Puffer FIFO; Events bei vollem Puffer werden verworfen

### Period

`time/period` – Setzt den Ausgang high abhängig von der eingestellten Zeit.

- **Properties:** Start (Zeit → high); Stop (Zeit → low)
- **Outputs:** `out` (boolean)
- **Behaviour:** Korrekter Zustand wird beim Start gesetzt

### Stepper

`time/stepper` – Mehrere Schritte mit vordefinierter Verzögerung pro Schritt.

- **Properties:** Delay before step # (ms)
- **Inputs:** `trigger` (boolean, Start wenn inaktiv); `reset` (boolean, stoppt)
- **Outputs:** `step #` (generic, Trigger)
- **Behaviour:** Alle Ein-/Ausgänge sind Trigger; Trigger nach Reset startet bei Step 1

### Timer

`time/timer` – Empfängt den Ausgang eines in der Basalte Home-App konfigurierten Timers (Uhrzeit-basiert).

- **Properties:** Trigger on (Verknüpfung zu Projekt-Timer)
- **Inputs:** `enable` (boolean, Timer an/aus)
- **Outputs:** `out` (On/Off-Timer: boolean; %-Timer: percentage); `enabled` (boolean, Feedback)
- **Behaviour:** An/aus über `enable` oder Home-App; Timer-Output nur in der Home-App setzbar (z. B. „um 8:00 an")

### When

`time/when` – Sendet einen Trigger zur angegebenen Zeit an gewählten Tagen.

- **Properties:** Days of the week; Trigger at (Uhrzeit)
- **Outputs:** `out` (boolean, true zur angegebenen Zeit)
- **Behaviour:** Output ist Trigger

---

## Link

### Link

`link` – Erzeugt virtuelle Verdrahtungen zwischen Flows (über Logic-Tabs hinweg). Workflow: „add Link Output" → Name vergeben → „add Link Input" → Name in der Property auswählen → beide sind verbunden.

- **Link Input:** verbindet sich mit einem beliebigen Link-Output auf irgendeinem Logic-Tab (über eindeutigen Namen).
- **Link Output:** braucht einen eindeutigen Namen, auf den sich Link-Inputs beziehen.
- Verbundene Link-Nodes verhalten sich wie direkt verdrahtet; die Verbindungslinien werden nicht angezeigt.
