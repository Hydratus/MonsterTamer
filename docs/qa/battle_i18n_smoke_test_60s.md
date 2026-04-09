# Battle i18n Smoke Test (60s)

Use this before commit for a fast battle-localization sanity pass.

## Setup (5s)

1. Language set to German.
2. Start a battle that allows one attack and one action change.

## Run (about 45s)

1. Use one translated move.
2. Use Rest or Switch once.
3. If possible, trigger one miss or low-energy message.
4. Open any status/attack view once and back out.

## Pass Criteria (about 10s)

- Move name in battle log is German, not English key.
- Core action text (Rest/Switch/Escape/feedback) is German.
- No obvious mixed-language line in battle box.
- No placeholder corruption (%s/%d) in displayed messages.

## Fail Fast Signals

- English move name appears despite existing de.po key.
- Battle line contains untranslated fragments like self/target/enemy.
- Broken text/encoding artifacts in battle messages.
