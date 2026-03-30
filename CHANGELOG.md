# Changelog

## [1.0.8] - 2026-03-30

### Improved

- Settings toggles now show helpful descriptions on hover, starting with the auto-focus option

## [1.0.7] - 2026-03-29

### Added

- Font family selector in Appearance settings — choose between Default (Friz Quadrata), System (Arial Narrow), or Custom (inherits fonts from addons like ElvUI)

### Improved

- Large behind-the-scenes cleanup to make the messenger feel more consistent and easier to maintain going forward
- Contact details now stay in sync more reliably, especially when Battle.net friend details change while the addon is open
- Scrolling is now more consistent in long contact lists and long conversations
- Message headers and chat bubbles now line up more consistently

### Fixed

- Fixed cases where contact details could lag behind until the window was reopened
- Fixed inconsistent spacing between sender names and chat bubbles
- Fixed refresh behavior so unread counts and contact updates stay accurate even while the window is hidden
- Fixed Mythic content confusion by showing an in-window pause notice and disabling the send box until whispers are available again
- Fixed a Classic startup error caused by unsupported whisper-related events, so the addon now loads cleanly on clients that do not provide them
- Fixed drag-resizing the messenger window beyond the screen bounds so it no longer snaps to an unrecoverable fullscreen size or requires deleting SavedVariables to recover

## [1.0.6] - 2026-03-27

### Added

- Profanity filter toggle in Behavior settings — enable or disable WoW's built-in profanity filter directly from the messenger without opening game options

### Fixed

- Fixed lint warnings for unused variables in whisper chat filter tests and link hooks

## [1.0.5] - 2026-03-27

### Improved

- Mythic content suspension is now much more robust — the addon cleanly suspends all activity when you enter a Mythic+ dungeon or Mythic raid, and fully resumes when you leave
- Added support for abandoned or depleted keystones — the addon now correctly resumes if your group leaves a key early
- You will now see a chat message when the addon suspends and resumes for mythic content, so you always know the current state
- Contact list and presence lookups are paused during mythic content to avoid unnecessary background work

### Fixed

- Fixed an issue where whispering from guild or community rosters could break the chat input during mythic content
- Fixed a rare issue where the reply target (/r) could become corrupted after receiving a whisper with "Hide from default chat" enabled
- Fixed the addon not resuming properly if a mythic keystone was abandoned or depleted without completing
- Fixed the addon sometimes not resuming after leaving a mythic dungeon — zone transitions now reliably detect when you are no longer in mythic content

## [1.0.4] - 2026-03-27

### Fixed

- Fix sending whispers during combat — sends are now blocked with a friendly status message instead of causing an error
- Fix occasional crashes with player names during mythic lockdown
- Fix rare crash in faction detection during mythic content
- Prevent broken conversations from appearing when receiving whispers during restricted content

### Added

- Automatic mythic content suspension — the addon fully disables itself in Mythic+ dungeons and Mythic raids. Your window auto-hides and restores when you leave. Whispers fall through to the default chat frame during this time.
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

