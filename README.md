# Prompt Museum

Save, organise and reuse your AI prompts, in a museum of your own.

- **Wings**: sort prompts into coloured collections, each hung as a living painting.
- **Blanks**: write `{{topic}}` in a prompt and fill it in when you copy, with a live preview.
- **Find anything**: live search across titles, text, `#tags`, notes and models.
- **Backups**: copy your whole museum as text and import it anywhere.
- **Updates in the app**: see what's new and install new versions with one tap.

Built with Godot 4.5 (GDScript, Mobile renderer). Every merge to `main` publishes a release with a signed Android APK and a single-file Windows `.exe`.

## Download

Grab the latest from [Releases](../../releases/latest): `PromptMuseum.apk` for Android, `PromptMuseum.exe` for Windows.

## Develop

Open the folder in Godot 4.5. `tests/logic_test.tscn` and `tests/smoke_test.tscn` run headless in CI; `PATCH_NOTES.md` gets a player-facing entry with every change.
