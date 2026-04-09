# Pause Menu Focus Smoke Test (60s)

Use this before commit for a very fast sanity check of pause menu focus/input.

## Setup (5s)

1. Load into HUB or overworld.
2. Open pause menu.

## Run (about 45s)

1. Go to Settings -> Video.
2. Focus Language and press select (space / gamepad A) to open dropdown.
3. Change language once (DE <-> EN).
4. Immediately press up/down 4 to 6 times.
5. Press left/right to change settings tab once, then back to Video.
6. Press back to sidebar, then enter Settings again.
7. Open Team and move up/down through at least 2 entries.
8. Open one monster options and move between Status/Switch once.

## Pass Criteria (about 10s)

- No runtime error about previously freed instance.
- Dropdown opens via select button (no mouse required).
- Focus remains visible and controllable in every step.
- No soft lock after language change.

## Fail Fast Signals

- Cannot call method grab_focus on a previously freed instance.
- Focus disappears and cannot be recovered by input.
- Dropdown reacts only to mouse click.
