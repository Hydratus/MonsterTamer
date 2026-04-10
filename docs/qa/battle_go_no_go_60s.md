# Battle Go/No-Go (60s)

## Ziel
In 30-60 Sekunden entscheiden, ob der aktuelle Refactor-Stand freigegeben werden kann.

## Schnellcheck (Ja/Nein)
1. Kampf startet ohne Fehler und zeigt beide Monster im HUD.
2. Eine Aktion pro Typ funktioniert: Attack, Item, Rest, Escape (wenn erlaubt).
3. Forced Switch nach KO blockiert nicht und nimmt eine gueltige Auswahl an.
4. Kampfende kehrt sauber in die Overworld/Dungeon-Ansicht zurueck.
5. Keine sichtbaren Fehlermeldungen/Script-Errors waehrend des Ablaufs.

## Go/No-Go Regel
- GO: Alle 5 Punkte sind "Ja".
- NO-GO: Mindestens 1 Punkt ist "Nein".

## Bei NO-GO kurz erfassen
- Schritt: Welche Aktion hat den Fehler ausgeloest?
- Meldung: Exakter Fehlertext.
- Ort: Hub, Dungeon, Wildkampf oder NPC-Kampf.
- Repro: 1-2 kurze Schritte zum Wiederholen.

## Kurzprotokoll
- Datum: 2026-04-10
- Tester: User
- 1) Kampfstart/HUD: Ja
- 2) Attack, Item, Rest, Escape: Ja
- 3) Forced Switch: Ja
- 4) Kampfende Rueckkehr: Ja
- 5) Keine Script-Errors sichtbar: Ja
- Ergebnis: GO
