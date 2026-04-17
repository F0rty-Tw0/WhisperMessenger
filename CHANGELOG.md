# Changelog

Player-friendly release notes for WhisperMessenger. Each version below focuses on the changes most people will actually notice in game.

## [Unreleased]

- New Azeroth theme gives the messenger a more native WoW look, with Blizzard-style colors and window styling.
- Reply now follows your current WoW reply key instead of assuming R, and a broad UI cleanup fixes small annoyances like wrong offline labels, stray scrollbars, and awkward window focus behavior.
- Fixed: right-clicking a chat bubble no longer crashes on Retail 10.0+ where the old dropdown template was removed — the Copy Text popup appears instead.
- Fixed: contact-row relative labels (day name, short date, long date) now honor "Server time" like the rest of the UI, so timestamps near midnight no longer show the wrong day.
- Fixed: whisper availability checks are now safely guarded, so quirky Battle.net API errors (or early-load states) can no longer surface as error popups.

## [1.1.7] - 2026-04-16

- Contact status now updates as soon as you open the messenger and stays fresh while the window is open.
- Added an optional "Double ESC to close" setting. You can also switch characters without losing saved channel context for a contact.

## [1.1.6] - 2026-04-16

- Added the /wr and /wreply commands, and whisper actions now open in WhisperMessenger instead of the default chat box.
- Mythic+ and encounter behavior is more predictable: the addon pauses whispers when WoW locks chat, then resumes cleanly afterward.

## [1.1.5] - 2026-04-08

- This build was shipped briefly, then rolled back in 1.1.6 after Blizzard's chat restrictions made its main Mythic+ whisper-recovery feature unreliable.
- While it was live, it also improved lock warnings in regular raids and stopped links from jumping into the messenger when the input was not focused.

## [1.1.4] - 2026-04-07

- Added more control over how the messenger behaves: choose 12-hour or 24-hour time, local or server time, separate incoming and outgoing auto-open toggles, and whether the window jumps to the latest message on open.

## [1.1.3] - 2026-04-06

- Big customization update: font controls, icon size, bubble color presets, and a lock indicator when whispering is blocked in competitive content.
- Added click-to-reveal for censored whispers and a quicker Start New Whisper button when no conversation is selected.

## [1.1.2] - 2026-04-05

- URLs in messages are easier to use. WhisperMessenger now detects links and gives you a safer copy flow when direct clicking is not allowed.
- Added a Start New Whisper shortcut in the header, plus channel context so you can see the sender's latest public message before whispering them.

## [1.1.1] - 2026-04-01

- History and reply behavior are more reliable, especially if you hide whispers from the default chat.
- WhisperMessenger now handles battlegrounds and arena restrictions more safely, keeps drafts better, and avoids stealing focus as often when a new whisper arrives.

## [1.1.0] - 2026-04-01

- Added theme presets, including Midnight, Shadowlands, and Draenor, so you can change the look without reloading.
- WhisperMessenger now works across Retail and a wide range of Classic versions, with cleaner startup and more reliable theme switching.

## [1.0.10] - 2026-03-31

- Added search across contacts and message history, plus right-click Copy Text on chat bubbles.
- Resizing feels smoother, contrast is clearer, and copying message text is easier when WoW blocks direct clipboard access.

## [1.0.9] - 2026-03-31

- You can now resize the contacts column, and WhisperMessenger remembers the width.
- Right-clicking a contact now opens the normal WoW player menu, including entries added by other addons.

## [1.0.8] - 2026-03-30

- WhisperMessenger can now auto-open for incoming whispers, right-click whisper actions, click-on-name whispers, and Battle.net whispers.
- Added selectable notification sounds, and fixed combat-time whisper saving plus shift-click links into the messenger.

## [1.0.7] - 2026-03-29

- Added a font family picker, including support for using fonts from addons like ElvUI.
- This release also smooths out everyday use: contact details stay in sync better, scrolling feels steadier, and Classic startup plus resize issues were fixed.

## [1.0.6] - 2026-03-27

- Added a profanity filter toggle in Behavior settings so you can switch WoW's built-in filter on or off without leaving the messenger.

## [1.0.5] - 2026-03-27

- Mythic+ and Mythic raid handling became much more reliable. WhisperMessenger now pauses itself cleanly, tells you when it pauses or resumes, and recovers better if a key ends early.
- Fixed several edge cases around reply targets, guild/community whispers, and resuming after leaving mythic content.

## [1.0.4] - 2026-03-27

- WhisperMessenger now automatically pauses itself in Mythic+ dungeons and Mythic raids, then restores itself after you leave.
- Added a toggle to keep whispers in both WhisperMessenger and the default chat, and fixed several restricted-content crashes.

## [0.1.0] - 2025-01-01

- First public version of WhisperMessenger: a dedicated whisper window with chat bubbles, contacts, unread badges, Battle.net support, saved history, settings, and drag-to-reorder contacts.
