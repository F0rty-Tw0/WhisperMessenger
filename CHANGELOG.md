# Changelog


## [1.1.8] - 2026-04-16

### Fixed

- **Enter-to-open-chat (and post-Mythic+ `/r`) crashed on `UpdateHeader` arithmetic with WhisperMessenger taint attribution.** `UI/Composer/LinkHooks.lua` replaced `_G.ChatEdit_GetActiveWindow`, `_G.ChatEdit_InsertLink`, `ChatFrameUtil.GetActiveWindow`, and `ChatFrameUtil.InsertLink` at module-load time so shift-click-from-quest-log / achievement / spellbook / bag would route links into our composer. Global/table-entry replacement put our function on Blizzard's secure call stack for every internal "who is the active chat editbox?" query, including the one traversed by `OPENCHAT` → `ActivateChat` → `SetFocus` → `ActivateChat` → `UpdateHeader`. The resulting taint propagated into UpdateHeader's width arithmetic and aborted with `attempt to perform arithmetic on a secret number value (tainted by 'WhisperMessenger')` on every Enter press, and on `/r` when the editbox sticky was left in BN_WHISPER after a during-M+ whisper. `securecall` does not help here — the taint root is Blizzard calling into an addon-defined function, before our body runs. The overrides now install only while the composer input has keyboard focus and restore the originals on focus-lost, so the taint window exists only during active composition and OPENCHAT / `/r` (both fire while the composer is unfocused) see Blizzard's own function untainted.

### Known limitations

- **Shift-click-from-quest-log (and similar UIs) into the messenger composer only works while the composer is already focused.** Previously the addon could accept links even when the composer was visible but unfocused; that capability depended on the module-load override that is no longer taint-safe on 12.0. Click inside the composer first, then shift-click the link. Chat-bubble link clicks (via `SetItemRef`) continue to work regardless of focus.


## [1.1.7] - 2026-04-15

### Fixed

- **`/r` and R-keybind crash during encounters with "Hide whispers from default chat" enabled.** When a whisper arrived while chat was locked (encounter, Mythic+, PvP match) and you hit `/r` or R to reply, WoW would raise `action was blocked... tainted by 'WhisperMessenger'`. Root cause: the addon registered its chat filters via raw `ChatFrame_AddMessageEventFilter`, which tainted Blizzard's filter dispatch table and poisoned `ChatEdit_SetLastTellTarget` on the next whisper. Fixed by routing all register/unregister calls through `securecall` so the mutation happens inside Blizzard's function body.
- **Stale reply target after leaving a Mythic+ keystone.** We did not capture whispers during M+ (live chat events are unregistered while suspended), so any cached `lastIncomingWhisperKey` was pre-M+ stale and could misroute a post-M+ `/r` to the wrong conversation. Resume now clears it.
- **Taint bomb from deferred edit-box close.** `ChatFrame_SendTell` routed into the messenger scheduled a one-tick-later cleanup via `C_Timer.After(0, …)`. If `ENCOUNTER_START` fired between the schedule and the callback, the cleanup ran inside the encounter and tainted Blizzard's secure reply path. The deferred callback now re-checks `isCompetitiveContent` at fire time and bails before touching the edit box.

### Added

- **Midnight (12.0) `C_RestrictedActions` integration.** Subscribes to `ADDON_RESTRICTION_STATE_CHANGED` and stores state from the event payload — never re-queries the API during dispatch (the API returns false during its own event). Drives the authoritative competitive-content gate on 12.0+, with full fallback to `InCombatLockdown` / `IsEncounterInProgress` / `C_ChallengeMode.IsChallengeModeActive` on The War Within (11.x) clients. The event is unregistered during Mythic+ suspend so our handler does not run inside Blizzard's restricted event dispatch.
- **`/wr` and `/wreply` slash commands.** Taint-safe replacement for Blizzard's `/r` during (or after) Mythic+. Opens the messenger focused on your most recent incoming whisper and focuses the composer. Unlike `/r`, it does not go through `ChatEdit_SetLastTellTarget` / `GetLastTellTarget` so it works even after Blizzard's `chatEditLastTell` has been tainted by a during-M+ secret-string sender.
- **Automatic R-key override when "Hide whispers from default chat" is on.** A hidden `SecureActionButton` with `macrotext=/wr` is created on load; whenever the setting is enabled, we call `SetOverrideBindingClick(button, true, "R", …)` so the R key fires our messenger reply instead of Blizzard's tainted `ReplyTell`. When the setting is turned off, `ClearOverrideBindings` restores Blizzard's default. Users who bound R to something other than REPLY will see it temporarily redirected while hide-whispers is on — toggling the setting off gives them their binding back.

### Fixed (additional)

- **OnUpdate poller no longer reads Blizzard edit boxes during competitive content.** The combat-draft-marking path touched `ChatFrame*EditBox` attributes before the suspend/competitive check, risking cross-frame taint propagation into Blizzard's next call on the same frame. Hard-bail moved to the top of the OnUpdate handler.
- **Removed `hooksecurefunc` on `ChatFrame_ReplyTell` / `ChatFrame_ReplyTell2`.** When Blizzard's own `ReplyTell` body errored on a tainted `chatEditLastTell` (after receiving a whisper during M+), WoW's taint system attributed the crash to WhisperMessenger for merely having a hook attached — even though our suffix never executed. Hooks removed; reply via `/wr` or the messenger window instead. Blizzard's R-keybind is now cleanly attributed to Blizzard when it crashes on its own tainted state.

### Known limitations

- **`/r` and R-key are incompatible with "Hide whispers from default chat" in Midnight (12.0).** The chat filter closure that suppresses whispers from the default chat runs in Blizzard's event-dispatch stack; 12.0's secret-value propagation marks any subsequent `SetLastTellTarget` write on that stack as tainted by us, so Blizzard's later `GetLastTellTarget` on `/r` or R crashes. There is no taint-safe alternative within the `AddMessageEventFilter` API. Workflow while the setting is on:
  - Use **`/wr`** (or bind `/wr` to R via macro) to reply — routes through our messenger and `runtime.lastIncomingWhisperKey`, bypassing Blizzard's tainted `chatEditLastTell`.
  - The Behavior settings tooltip for "Hide whispers from default chat" now carries this disclaimer.
  - On entering Mythic+ with the setting enabled, the addon prints a one-time `/r and R-key may fail… use /wr` reminder so the limitation is visible in context.


## [1.1.6] - 2026-04-12

### Changed

- **Reverted v1.1.5 taint-guard and deferred-replay rework.** Testing confirmed that Blizzard's chat-secrecy API blocks whispers from reaching any addon while chat is locked — the replay scaffolding added in v1.1.5/v1.1.6 could never see the messages it was trying to recover, so the added complexity served no purpose. The addon is back to the v1.1.4 behavior: during encounters, Mythic+, and other chat-locked content, whispers fall through to the default chat frame as the game intends, and the messenger shows a "Whispers paused in competitive content" banner that clears the moment the fight or run ends.

### Preserved from v1.1.5

- **Links only insert into the composer when its input is focused** — shift-click on items, quests, spells, and chat-bubble links no longer leaks into the messenger when the composer isn't the active edit box.


## [1.1.5] - 2026-04-08

> Rolled back in v1.1.6 — see the v1.1.6 entry above. The items listed here shipped briefly before testing confirmed that Blizzard's chat-secrecy API blocks whispers from ever reaching addons while chat is locked, making the deferred-replay rework unable to do its job.

### Added

- **Whispers no longer lost during Mythic+** — whispers that arrive while you're inside a Mythic+ keystone (or any other content where Blizzard locks down chat) are now held safely in the background and delivered to your messenger the moment you finish the run. Previously these messages were dropped entirely.
- **Smarter lockdown detection** — the messenger now asks the game directly whether chat is locked instead of guessing from the content type. The "chat paused" banner and the lock indicator now trigger correctly across every situation Blizzard restricts whispers in, not just Mythic+ keystones and Mythic raids.

### Fixed

- **Lock indicator wrongly showing in normal raids** — fixed the "Whispers paused" banner and the lock icon appearing on every boss pull in LFR, Normal, and Heroic raids. The messenger now only shows the lock indicator in content where the game actually restricts whispers.
- **Item / quest / spell links going into the messenger when it isn't focused** — fixed shift-clicking items, quest log links, and chat-bubble link clicks being silently captured by the messenger composer even when its input wasn't the focused widget. Links now only insert into the composer when the messenger input has keyboard focus, matching how Blizzard's default chat editbox behaves.
- **Mythic+ taint error** — fixed `attempt to compare ... a secret string value tainted by 'WhisperMessenger'` spam from `ChannelMessageStore` while inside Mythic+ keystones.
- **Stuck "Competitive Mode" after Mythic+** — fixed the toggle-icon lock indicator and the "Whispers paused in competitive content" banner remaining stuck after returning to a capital city from a Mythic+ run.


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
