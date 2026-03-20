# WhisperMessenger

Messenger-style whisper UI addon for World of Warcraft Retail.

## Tech Stack

- **Lua 5.1** (WoW runtime) — no Lua 5.2+ features (no `goto`, no `table.unpack` without compat)
- **WoW API** — Blizzard's frame/widget system, C_ namespaced APIs
- **StyLua** — formatter (`stylua.toml`)
- **Luacheck** — static analysis (`.luacheckrc`)

## Code Conventions

- **2-space indentation, spaces** (not tabs)
- **PascalCase** for modules/classes: `ConversationStore`, `TableUtils`
- **camelCase** for functions/variables: `buildContacts`, `refreshWindow`
- **snake_case** for theme constants: `bg_primary`, `text_secondary`
- **Module pattern**: every file starts with `local addonName, ns = ...` and ends with `ns.ModuleName = ModuleName; return ModuleName`
- **Prefix unused args with `_`**: `_self`, `_event`, `_conversation`
- **Access WoW globals via `_G.`**: `_G.CreateFrame`, `_G.C_ChatInfo` — keeps the dependency on globals explicit and testable

## Linting

```bash
# Check (CI-safe)
./scripts/lint.sh

# Auto-format + check
./scripts/lint.sh --fix

# Individual tools
luacheck .          # static analysis — must show 0 warnings
stylua --check .    # format check
stylua .            # auto-format
```

Luacheck handles semantics (unused vars, undefined globals, shadowing). StyLua handles formatting (line length, spacing, alignment). Both must pass clean before committing.

When adding new WoW API globals, add them to `.luacheckrc` under `read_globals`.

## Tests

```bash
lua tests/run.lua tests/path/to/test_file.lua
```

Tests run with plain Lua — no WoW runtime needed. WoW APIs are stubbed via `tests/helpers/fake_ui.lua`. Run all tests:

```bash
for f in tests/**/*.lua; do lua tests/run.lua "$f"; done
```

## Project Structure

```
Core/           — Bootstrap, event routing, slash commands, module loader
Model/          — Identity, conversations, contacts, retention, lockdown queue
Persistence/    — SavedVariables, migrations, schema
Transport/      — WhisperGateway, BNet resolver, availability
UI/             — MessengerWindow, ContactsList, ConversationPane, Composer,
                  ChatBubble, ScrollView, Theme, ToggleIcon
Util/           — TableUtils, TimeFormat
tests/          — Unit and integration tests
scripts/        — Build and lint scripts
```
