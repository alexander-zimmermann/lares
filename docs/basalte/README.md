# Basalte

## Wohin der Studio-Export gehört

`docs/basalte/Steinroth.bcfg` — dorthin exportieren und dort liegen lassen.

Die Datei ist **nicht** im Repo (`*.bcfg` steht in `.gitignore`), genau wie der
ETS-Export `Steinroth.knxproj` nicht drin ist. Zwei Gründe: sie ist 14 MB binär,
und sie enthält mindestens einen Wert, der wie ein Zugangstoken aussieht —
ungeprüft, aber Grund genug, sie nicht zu veröffentlichen.

## Bestandsaufnahme neu erzeugen

```
task basalte:inventory                       # nimmt docs/basalte/Steinroth.bcfg
task basalte:inventory -- /pfad/zum/export.bcfg
```

Schreibt `logic-inventory.md`. Nach jeder Änderung in Basalte Studio neu
erzeugen und den Diff ansehen — daran sieht man, was sich geändert hat, ohne
Studio zu öffnen.

## Was hier nicht liegt

Die **Referenz aller Basalte-Logikbausteine** (was `chrono`, `multiplexer`,
`changedetector` tun) gehört nicht hierher, sondern ins Wiki. Sie beschreibt das
Produkt, nicht dieses Haus.
