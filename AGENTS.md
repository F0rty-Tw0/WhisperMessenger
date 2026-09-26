# WhisperMessenger

Messenger-style whisper UI addon for World of Warcraft: Retail, the Classic flavors (Vanilla, TBC, Wrath, Cata, Mists) and WoW: Forever. One TOC (`WhisperMessenger.toc`) carries every flavor's `## Interface-*` line.

## Tech Stack

- **Lua 5.1** (WoW runtime) — no Lua 5.2+ features (no `goto`, no `table.unpack` without compat)
- **WoW API** — Blizzard's frame/widget system, C\_ namespaced APIs
- **Flavor differences** go through `Core/FlavorCompat.lua` — never assume a Retail-only API exists
- **StyLua** — formatter (`stylua.toml`)
- **Luacheck** — static analysis (`.luacheckrc`)

## Code Conventions

- **2-space indentation, spaces** (not tabs)
- **PascalCase** for modules/classes: `ConversationStore`, `TableUtils`
- **camelCase** for functions/variables: `buildContacts`, `refreshWindow`
- **snake_case** for theme constants: `bg_primary`, `text_secondary`
- **Module pattern**: every file starts with `local addonName, ns = ...` plus the `if type(ns) ~= "table" then ns = {} end` guard, and ends with `ns.ModuleName = ModuleName; return ModuleName`
- **Prefix unused args with `_`**: `_self`, `_event`, `_conversation`
- **Access WoW globals via `_G.`**: `_G.CreateFrame`, `_G.C_ChatInfo` — keeps the dependency on globals explicit and testable

## Linting

```bash
# Check (CI-safe) — always use the project script, not bare tool commands
bash scripts/lint.sh

# Auto-format + check
bash scripts/lint.sh --fix
```

Luacheck handles semantics (unused vars, undefined globals, shadowing). StyLua handles formatting (line length, spacing, alignment). Both must pass clean before committing — they are the only lint gates CI runs.

`lint.sh` also runs LuaLS diagnostics, which already report ~300 old problems, so the script exits 1 even on a clean tree. Don't add new LuaLS problems: compare the count against a stash of your changes.

Missing tools on Windows: `powershell -ExecutionPolicy Bypass -File scripts/setup-lint-tools.ps1` installs them into `.tools/`.

When adding new WoW API globals, add them to `.luacheckrc` under `read_globals`.

## Tests

```bash
# If lua is available:
lua tests/run.lua tests/path/to/test_file.lua

# If lua is not available (Windows), use the Python+lupa harness (pip install lupa):
python scripts/run_test.py tests/path/to/test_file.lua
```

Tests run with plain Lua — no WoW runtime needed. WoW APIs are stubbed via `tests/helpers/fake_ui.lua` and the `tests/helpers/fake_ui/` folder. Run all tests:

```bash
for f in tests/**/*.lua; do python scripts/run_test.py "$f"; done

# Release script tests (Python):
python -m unittest tests.scripts.test_gen_patch_notes tests.scripts.test_promote_changelog
```

The release pipeline minifies the shipped Lua and runs every test again on the minified code, so neither code nor tests may depend on comments or exact source formatting.

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

## File Size & Modularity

- **Target ~300 lines per file.** If a file grows past 300 lines, split it into focused sub-modules.
- **One responsibility per file** — a file that does two things should be two files.
- **Extract early** — when adding code would push a file over 300 lines, extract a new module before continuing.
- **Applies to both production and test files.**

## Adding a File

- **Add it to `WhisperMessenger.toc`, after everything it depends on.** TOC order is load order. WoW: Forever has a global `require` that throws "Invalid import", so a module's `ns.X or require(...)` fallback must never be reached in game. `tests/integration/test_toc_load_order.lua` guards this.
- **Folder modules** (`UI/Theme/`, `UI/Composer/`, …) have an `init.lua` that only exists so tests can `require` the folder. It is not in the TOC; add any new one to the `ignore:` list in `.pkgmeta`.
- **New top-level files that aren't addon code** (docs, configs) go in `.pkgmeta` `ignore:` so they don't ship in the zip.

## Localization

- English strings are the keys: `Localization.Text("Mark all as read")`. There is no enUS catalog.
- `Locale/<code>.lua` holds one catalog per language (10 total). Every new player-visible string needs a translation in **all** of them with the same `%s` / `%d` slots in the same order — `tests/util/test_locale_parity.lua` fails otherwise.

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

## Changelog

`CHANGELOG.md` is **player-facing release notes**, not an engineering log. The audience is WoW players browsing CurseForge / Wago — not other developers.

- **Write in plain English.** A player should understand every bullet without knowing any code, module names, or addon internals.
- **Describe the in-game effect, not the implementation.** Say what the user will now see / can now do / will no longer be broken — not which file changed, which API was introduced, which refactor happened.
- **Banned in changelog entries:** file paths, module names (`BehaviorSettings`, `WindowCoordinator`, `MessengerWindow`, etc.), function names, API names (`C_ChatInfo`, `SetCVar`, etc.), Lua terms, test names, "refactor", "introduce", "extract", "wire up", "config key", "token". If a sentence only makes sense to someone reading the diff, it doesn't belong here.
- **One bullet per user-visible change.** Group related fixes into one line if the user would see them as the same thing.
- **Fixes start with `Fixed:`.** Features and behavior changes don't need a prefix.
- **Always update `CHANGELOG.md` when behavior, UI, settings, or fixes change** — in the same turn as the code edit. Put the line under `## [Unreleased]`. Only if a version section exists that has not been tagged yet (release prep in flight), add it there instead — `scripts/release.sh` refuses to run when both hold notes.

### Layout

`CHANGELOG.md` holds only `[Unreleased]` plus the **current series** (2.0.x today). Older series live in `archive/changelog/<major>.<minor>.md` (e.g. `archive/changelog/1.4.md`).

- Every file starts with an `All releases:` nav line linking each of the other series.
- **`bash scripts/release.sh <version>` handles all of this:** it moves `[Unreleased]` into a dated `## [x.y.z]` section, archives the finished series when a new minor/major opens, rebuilds every nav line, regenerates `Core/PatchNotes.lua`, and bumps the TOC + `Constants.lua` versions. Don't hand-edit version sections or nav lines for a release.
- `archive/` is ignored by `.pkgmeta`, so it never ships in the addon zip.

When in doubt, read the 1.1.0 - 1.1.7 sections in `archive/changelog/1.1.md` — they are the style guide. Match their voice.

## Releasing

1. Notes sit under `## [Unreleased]` in `CHANGELOG.md`, and the working tree is clean (the script refuses otherwise).
2. `bash scripts/release.sh <version>` — needs internet (it reads live game version numbers from Blizzard). It promotes the notes, regenerates `Core/PatchNotes.lua` (the in-game What's New), bumps the TOC + `Core/Constants.lua`, commits and tags.
3. `git push origin master v<version>` — CI lints, minifies, re-runs the tests, and uploads to CurseForge, Wago and GitHub Releases.

No local setup? Run the "Package and release" workflow by hand on GitHub (`workflow_dispatch`); it runs the same script.

What's New shows only the **top** changelog section. For a hotfix right after a big release, rename the big section to the new version and add the fix to it, leaving `[Unreleased]` empty — players who skipped the big release still see all of it.

## Project Structure

```
Bootstrap.lua   — Addon entry point (last file in the TOC)
Core/           — Bootstrap runtime, event routing (EventRouter, Ingest),
                  flavor compat, slash commands, module loader, patch notes
Model/          — Identity, conversations, contacts, presence, drafts,
                  requests, replies, reactions, retention, outgoing delivery
Persistence/    — SavedVariables, migrations, schema
Transport/      — Whisper/chat gateways, addon messages, BNet resolver,
                  availability
UI/             — MessengerWindow, ContactsList, ConversationPane, Composer,
                  ChatBubble, ScrollView, Theme, ToggleIcon, MinimapIcon,
                  Hyperlinks, Shared (settings controls, pickers)
Util/           — TableUtils, TimeFormat, TextLimits, ChatPrint
Locale/         — Localization lookup + one catalog per language
Media/          — Icons and textures
tests/          — Unit and integration tests (mirror the source folders)
scripts/        — Lint, test runner, release, packaging
archive/        — Older changelog series (not shipped)
```

