# Battle Flow Playtest Matrix

## Ziel
Schneller manueller Regression-Check fuer den kompletten Kampf-Flow nach den letzten Aenderungen.

## Vorbereitung
- Save mit mindestens 3 Monstern im Team (mind. 1 aktives + 2 Reserve)
- Ein Monster mit teurem Angriff (hoher Energieverbrauch)
- Zugang zu:
  - Wildkaempfen
  - NPC-/Elite-/Boss-Kaempfen
  - Healing Spring Event im Dungeon

## Testfaelle

### 1) Wildkampf: Escape erlaubt
Schritte:
1. Wildkampf starten.
2. Escape waehlen.

Soll:
- Escape-Versuch startet.
- Meldung fuer Erfolg/Misserfolg erscheint.
- Bei Erfolg endet der Kampf ohne normale Sieg-Belohnungslogik.
- Bei Misserfolg laeuft die Runde normal weiter.

### 2) NPC-/Elite-/Boss-Kampf: Escape gesperrt
Schritte:
1. NPC-/Elite-/Boss-Kampf starten.
2. Escape waehlen.

Soll:
- Meldung: Escape ist hier nicht moeglich.
- Kein Escape-Versuch.
- Rueckkehr ins Kampfmenue (Action erneut waehlbar).

### 3) Angriff ohne genug Energie (Spieler)
Schritte:
1. Energie des aktiven Monsters unter Angriffskosten bringen.
2. Teuren Angriff waehlen.

Soll:
- Meldung: Monster ist zu erschoepft.
- Angriff wird nicht eingereicht.
- Kein Zugverlust.
- Action-Menue bleibt / wird wieder aktiv.

### 4) Rest-Aktion im Attack-Menue
Schritte:
1. Attack-Menue oeffnen.
2. Rest waehlen.

Soll:
- Rest fuehrt als normale Action aus (kein Angriff).
- +25% Max-Energie (mind. 1) auf aktives Monster.
- Runde wird verbraucht (gegnerische Aktion kann folgen).

### 5) Rest/Back Navigation
Schritte:
1. Attack-Menue oeffnen.
2. Fokus auf Rest setzen.
3. Rechts druecken.
4. Von Back links druecken.

Soll:
- Rest -> Back mit Rechts.
- Back -> Rest mit Links.
- Kein vertikaler Sprung zwischen den beiden Buttons.

### 6) KI-Energieverhalten
Schritte:
1. Gegner mit Angriffen > aktueller Energie erzeugen/beobachten.

Soll:
- KI waehlt keine unbezahlbare Attacke.
- KI nutzt stattdessen Rest-Fallback.
- Keine "doesn't have enough energy"-Turnwaste-Logik als Hauptpfad.

### 7) Reserve-Energie-Regeneration nach Kampf
Schritte:
1. Kampf mit Team >= 3 Monster gewinnen.
2. Werte vorher/nachher notieren.

Soll:
- Nicht-aktive, lebende Reserve-Monster erhalten +8% Max-Energie (mind. 1).
- Aktive Teilnehmer erhalten diesen Reserve-Bonus nicht.
- KO-Monster erhalten keinen Energie-Bonus.

### 8) Healing Spring Event
Schritte:
1. Healing Spring nutzen.

Soll:
- Team bekommt HP-Wiederherstellung.
- Team bekommt Energie-Wiederherstellung.
- KO-Monster werden bei Energie-Regeneration uebersprungen.

## Ergebnisprotokoll
Fuer jeden Testfall eintragen:
- Status: PASS / FAIL
- Beobachtung
- Repro-Schritte (wenn FAIL)
- Vorschlag fuer Balancing (nur falls PASS, aber gefuehlt unbalanciert)

## Balancing-Notizen (nach Testdurchlauf)
- Rest-Energie: aktuell 25%
- Reserve-Regen nach Kampf: aktuell 8% (min 1)
- Escape-Chance: aktuell basis-/speed-/level-basiert mit Clamp

Empfehlung fuer erste Nachjustierung nur in kleinen Schritten:
- Rest: +/-5%
- Reserve-Regen: +/-2%
- Escape-Basis: +/-5
