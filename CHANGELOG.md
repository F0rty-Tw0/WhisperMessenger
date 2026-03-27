# Changelog

## [1.0.3] - 2026-03-27

### Fixed
- Fix `ADDON_ACTION_FORBIDDEN` when sending character whispers during combat — wire `InCombatLockdown` as the default lockdown check so sends are blocked with a "Lockdown" status instead of triggering a protected function error
- Fix `attempt to perform string conversion on a secret string value` — detaint player names from chat events via `Ambiguate` before string operations
- Fix `table index is secret` crash in faction inference during mythic lockdown — guard tainted `raceTag` table lookups with `pcall`
- Drop fully-tainted events in EventRouter when all payload fields are secret — prevents degenerate conversations and `table index is secret` crashes on `availabilityByGUID`
- Harden all Identity and Factions string operations against tainted execution (mythic/challenge mode lockdown) with graceful `pcall` fallbacks

### Added
- Automatic mythic content suspension — addon fully disables in Mythic+ dungeons and Mythic raids (detected via `GetInstanceInfo` difficultyID). Events are dropped before payload build, chat filter lets whispers through to default chat, window auto-hides and restores on exit. Responds to `PLAYER_ENTERING_WORLD`, `CHALLENGE_MODE_START`, and `CHALLENGE_MODE_COMPLETED`.
- "Hide whispers from default chat" toggle in Behavior settings — disable to show whispers in both WhisperMessenger and the default chat frame (defaults to off)

## [0.1.0] - 2025-01-01

### Added
- Messenger-style whisper UI window
- Contact list with online status and unread badges
- Conversation pane with chat bubbles and date separators
- Composer with whisper and BNet sending
- Toggle icon with unread badge
- Settings panels (General, Appearance, Behavior, Notifications)
- Message retention and conversation age limits
- Drag-to-reorder contacts
- BNet friend resolution
- SavedVariables persistence with migrations
