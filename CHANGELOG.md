# Changelog


## [Unreleased]

### Added

- **Whispers no longer lost during Mythic+** — whispers that arrive while you're inside a Mythic+ keystone (or any other content where Blizzard locks down chat) are now held safely in the background and delivered to your messenger the moment you finish the run. Previously these messages were dropped entirely.
- **Smarter lockdown detection** — the messenger now asks the game directly whether chat is locked instead of guessing from the content type. The "chat paused" banner and the lock indicator now trigger correctly across every situation Blizzard restricts whispers in, not just Mythic+ keystones and Mythic raids.

### Fixed

- **Item / quest / spell links going into the messenger when it isn't focused** — fixed shift-clicking items, quest log links, and chat-bubble link clicks being silently captured by the messenger composer even when its input wasn't the focused widget. Links now only insert into the composer when the messenger input has keyboard focus, matching how Blizzard's default chat editbox behaves.
- **Stuck scroll position when switching settings tabs** — fixed the options panel keeping its scroll offset across tab switches. Scrolling down inside a long tab (e.g. Appearance) and then clicking a shorter tab (e.g. Behavior) used to leave the new tab visually scrolled with empty space at the top. The shared options scroll view now resets to the top whenever a new tab is selected.
- **Mythic+ taint error** — fixed `attempt to compare ... a secret string value tainted by 'WhisperMessenger'` spam from `ChannelMessageStore` while inside Mythic+ keystones. The channel message recorder used a direct equality compare against a literal, which trips Blizzard's secret-string protection on tainted chat sender names. The recorder is now type-safe, and channel chat events are unregistered for the duration of mythic suspend so no addon code touches them at all.
- **Stuck "Competitive Mode" after Mythic+** — fixed the toggle-icon lock indicator and the "Whispers paused in competitive content" banner remaining stuck after returning to a capital city from a Mythic+ run. The zone-change handler updated the internal flag but never notified the UI when leaving competitive content via a zone change rather than `CHALLENGE_MODE_COMPLETED`.

## [1.1.4] - 2026-04-07

### Added

- **Timestamp format customization** — new "Time Format" selector in General settings lets you switch between 12-hour (2:30 PM) and 24-hour (14:30) time display in chat bubbles.
- **Local / Server time source** — new "Time Source" selector in General settings lets you choose between your computer's local clock and the game server's clock for all timestamps, including chat bubble times, date separators, and contact preview times.
- **Separate auto-open controls** — the single "Auto-open on whisper" toggle has been split into two independent toggles in Behavior settings: "Auto-open on incoming whisper" and "Auto-open on outgoing whisper", so you can control each direction separately.
- **Scroll to latest on open** — the messenger now scrolls to the most recent message when opened. Controllable via a "Scroll to latest on open" toggle in Behavior settings (enabled by default).

## [1.1.3] - 2026-04-06

### Added

- **Font customization** — new controls in Appearance settings for font size (9–17px slider), font outline (None / Outline / Thick), chat font color (Default, Gold, Blue, Green, Purple, Rose), and a Morpheus fantasy font option alongside Default and System.
- **Icon size customization** — new slider in Notification settings lets you resize the toggle icon from 24px to 64px.
- **Icon desaturation** — the toggle icon is now greyed-out by default and colorizes when you have unread whispers, making notification state visible at a glance. Controlled via a "Desaturate icon when idle" toggle in Notification settings.
- **Bubble color presets** — new "Bubble Colors" selector in Appearance settings lets you customize chat bubble colors independently of the theme. Choose from Default (follows theme), Shadow, Ember, Arcane, Frost, or Fel. Switching back to Default restores the active theme's bubble colors.
- **Competitive content indicator** — a lock icon now appears on the toggle icon when you're in competitive content (M+ keystones, battlegrounds, arenas, or boss encounters). Sending is blocked with a visible notice banner in the messenger (like M+ lockdown), and whispers fall back to the default WoW chat frame so you never miss a message. The tooltip also shows "Chat unavailable — in competitive content" so you know at a glance why messaging is paused.
- **Censored message reveal** — Blizzard-censored whispers now show a "(click to reveal)" indicator on the chat bubble. Left-click to uncensor the message directly in the messenger, even when the default chat is hidden.
- **Start New Whisper** button in the empty conversation pane — when no conversation is selected, a "Start New Whisper" button appears below the prompt text so you can begin a conversation without scrolling to the header.

### Fixed

- Unread badge size and position adjusted for better alignment.
- Title color now updates correctly across theme changes.
- Fixed a parameter name bug in channel event registration.
- Fixed scrollbar jumping when hovering or dragging in the message list.
- Removed unused `Theme` import in competitive content indicator.

## [1.1.2] - 2026-04-05

### Added

- Clickable URL detection in chat bubbles and transcript text for plain `http://`, `https://`, and `www.` links.

- New **Start New Whisper** header action next to `WM` opens a player-name prompt so you can start or jump to a whisper conversation without typing `/w`.
- Start-conversation and manual-copy dialogs now share the same messenger popup styling, including a wider near full-width input field for easier text entry.
- **Channel message context** — when opening a conversation, the contact's most recent message from public channels (Trade, General, LFG, etc.) now appears as a chat bubble with a gold "· via Trade" tag, so you know why you're whispering them.

### Fixed

- URL hyperlink clicks no longer trigger protected-function taint errors (`ADDON_ACTION_FORBIDDEN`).
- URL clicks now use a safe copy fallback flow (clipboard or manual copy dialog) in WoW addon context.

## [1.1.1] - 2026-04-01

### Fixed

- Pinned chats now keep their history while pinned (still capped by your max messages per contact setting).
- Unpinned chats now immediately follow your retention settings.
- Shift-click links now insert into WhisperMessenger only when its window is open. If the window is closed, WoW does the default action.
- Outgoing whispers are now properly hidden from default chat when "Hide whispers from default chat" is enabled.
- Reply (/r) now works reliably with "Hide whispers from default chat" enabled.
- Fixed a whisper-filter taint error (`secret string value`).
- "Hide whispers from default chat" now auto-disables in battlegrounds, arenas, and rated PvP.
- Fixed a race where pressing Enter, then quickly pressing Esc, could reopen the window when the delayed outgoing whisper event arrived.

### Improved

- Auto-open detection is more reliable for reply, right-click whisper, and name-click whisper.
- Incoming whispers no longer steal focus when you already have the messenger open on an active conversation.
- Draft text in the whisper edit box is now preserved across combat transitions.
- Contacts row interactions are cleaner: better action-button visibility, hover-pointer behavior, and spacing.

## [1.1.0] - 2026-04-01

- Added runtime-switchable theme presets in Appearance settings, including Midnight, Shadowlands, and Draenor.
- Improved the messenger's visual polish with stronger section framing, clearer settings toggles, and distinct accent identities for each preset.
- Improved theme consistency by reducing redundant theme tokens, pruning dead preset colors, and making preset changes repaint search/input/settings surfaces immediately.
- Fixed theme startup and preset application issues so the addon loads cleanly and live theme changes update the window reliably.
- Added full Classic compatibility — the addon now runs on Classic Era, Season of Discovery, TBC Classic Anniversary, Cata Classic, and MoP Classic in addition to Retail.
- Fixed a crash caused by the removed UIDropDownMenuTemplate on Retail 10.0+ clients.

## [1.0.10] - 2026-03-31

- Added contacts-list search with live filtering across character names and message history, plus an inline clear (X) action to reset results.
- Improved UI contrast and added deferred window resize with a ghost preview (stable positioning + smooth commit on release) for lag-free resizing.

- Added right-click chat-bubble context menu actions with **Copy Text** support.
- Improved chat-bubble copy flow with safer clipboard fallbacks and a messenger-styled manual copy dialog that pre-fills and highlights message text when direct clipboard APIs are unavailable.

## [1.0.9] - 2026-03-31

- Added independent contacts-pane resizing with persisted width, plus compact spacing/truncation fixes to prevent overlap in narrow layouts.
- Added native right-click contact context menu support in the contacts list, so contact rows now open the standard WoW player menu (including entries added by other addons).

## [1.0.8] - 2026-03-30

### Added

- Auto-open window on incoming whisper, right-click "Whisper", click-on-name whisper, or BNet friend whisper — configurable in Behavior settings, disabled during combat
- Notification sounds now play even when in-game audio is muted
- Choose from five notification sounds: Whisper, Ping, Chime, Bell, or Raid Warning

### Fixed

- Whisper messages received during combat were queued and never stored — they now record immediately
- Shift-clicking quests, achievements, spells, and professions now correctly links them into the messenger chat instead of triggering the default action (tracking, inspecting, etc.)

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
