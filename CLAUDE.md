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
# Check (CI-safe) — always use the project script, not bare tool commands
bash scripts/lint.sh

# Auto-format + check
bash scripts/lint.sh --fix
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

## Development Workflow — TDD (Red-Green-Refactor)

Every change follows test-driven development. No exceptions.

1. **Red** — Write a failing test first. The test must fail for the right reason (missing behavior, not a syntax error). Run it and confirm the failure.
2. **Green** — Write the minimum code to make the test pass. No more, no less. Run the test and confirm it passes.
3. **Refactor** — Clean up the implementation and the test. Remove duplication, improve naming, simplify logic. Run all tests to confirm nothing broke.

Rules:
- **Never write production code without a failing test that demands it.**
- **One behavior per test** — each test should verify a single expectation.
- **Test file mirrors source file** — `Model/ConversationStore.lua` → `tests/model/test_conversation_store.lua`
- **Test names describe behavior** — `test_mark_read_resets_unread_count`, not `test_mark_read_1`
- **Run the relevant test file after Red and Green steps.** Run all tests after Refactor.
- **Lint after Refactor** — run `bash scripts/lint.sh` before considering the cycle complete.

## Lua Best Practices

- **Localize everything** — `local` variables and functions are faster than globals. Always `local function` unless exporting on a module table.
- **Localize hot-path API calls** — `local pairs = pairs`, `local tinsert = table.insert` at the top of files that use them in loops.
- **Avoid creating tables in tight loops** — reuse tables or build outside the loop when possible. Table creation triggers GC pressure.
- **Prefer `ipairs` for arrays, `pairs` for dictionaries** — never use `pairs` on sequential arrays; iteration order is not guaranteed.
- **String concatenation** — use `table.concat` for building strings in loops. The `..` operator creates a new string each time.
- **Nil checks before method calls** — WoW frames may be nil or lack methods in test stubs. Guard with `if obj and obj.Method then` before calling.
- **No global leaks** — every variable must be `local`. Luacheck catches these, but be vigilant. The only intentional globals are WoW API calls via `_G.`.
- **Early returns over deep nesting** — prefer `if not condition then return end` at the top of a function over wrapping the whole body in an `if`.
- **Avoid magic numbers** — extract constants into `Theme.LAYOUT`, `Theme.COLORS`, or a local `UPPER_CASE` variable at the top of the file.
- **Keep functions small** — if a function exceeds ~40 lines, extract helpers. Each function should do one thing.
- **No `table.getn` or `#` on sparse tables** — `#` is only reliable on proper sequences (no nil holes).

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
