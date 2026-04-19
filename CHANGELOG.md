# Changelog

Player-friendly release notes for WhisperMessenger. Each version below focuses on the changes most people will actually notice in game.

## [Unreleased]

- Fixed: the incoming-message popup next to the chat icon now shows Russian, Greek, and other non-Latin letters correctly instead of blank boxes.
- Fixed: receiving a new whisper now reliably scrolls the chat to the newest message instead of occasionally jumping to the top.
- Pressing Reply (or using /wr) now reliably places the cursor in the chat input so you can start typing right away.
- The incoming-message popup next to the chat icon no longer appears while the messenger window is open — the conversation is already visible, so the popup would just be duplicated noise.
- The Whispers and Groups tabs each remember their own selected conversation. Switching between tabs keeps your place in both, so you can flip back and forth without losing who you were talking to.
- Leaving a party, raid, or instance no longer wipes that chat. The conversation stays in the Groups tab with a "Left party." / "Left raid." / "Left instance." note, and sending is blocked until you rejoin.
- Party, raid, and instance chat history now persists across /reload and logout — you'll see your recent group messages again after relogging.
- Switching characters no longer hides the party, raid, guild, officer, or instance chats from your other characters. They now show up in the Groups tab prefixed with the character name (for example, "Jaina — Guild"), so you can scroll back through history regardless of who you logged in as last.
- Guild chat is now shared across characters in the same guild — alts in the same guild see one combined conversation, and the header shows the guild's name. Alts in a *different* guild get their own row labeled with the character name ("Jaina — Guild") and the header shows that guild's name.
- Group chat rows and headers are now tinted by the class color of the character who actually chatted in that group — so Jaina's guild history shows in a mage's blue, Thrall's raid in a shaman's electric blue, and so on. The first time you log in on a character, the addon remembers that character's class so the right color sticks for that character's group history across relogs. Before a character has logged in once since this update, their rows stay neutral instead of borrowing the current character's color.
- Fixed: switching between characters no longer spams "Left party." / "Left raid." messages into your alts' group history. Membership transitions are now only recorded on the currently-logged-in character's own group rows; other characters' history is left untouched.
- Fixed: selecting another character's party, raid, instance, guild, or officer chat no longer lets you type into it. The composer is disabled with an "Another character's history — read-only." notice so you can't accidentally send a message to your current character's group while looking at an alt's history.
- An incoming whisper no longer takes over your view when you're on the Groups tab. The whisper still arrives quietly in the Whispers tab; your group conversation stays put. Opening the messenger while on the Groups tab also respects that — it won't jump you into a freshly-received whisper.
- Starting a whisper from the Groups tab (via Reply, /w, Start New Whisper, or any outgoing whisper) now switches you back to the Whispers tab automatically so the new conversation is visible. Your group selection is remembered — flipping back to Groups restores it.
- Guild chats now show your guild's name in the conversation header, and the header icon renders your actual guild tabard (background, emblem, and border) instead of a static picture. The contact row keeps the compact "Guild" label with a small tabard icon.
- Party, Raid, and Instance headers no longer repeat themselves (it used to read "Party [Party]"). The channel-type chip now only appears when it adds new information — for example, it stays next to a custom Battle.net group name or your guild's name.
- The conversation header now carries the channel icon for group chats (party, raid, instance, guild, Battle.net group, community), matching what you see in the contact row.
- Alliance / Horde faction icons no longer clutter party, raid, instance, guild, or other group chat rows — they only make sense for individual whispers and now only appear there.
- You can now reply to party, instance, and Battle.net group conversations directly from the messenger window.
- Party, instance, and Battle.net group conversations now appear in the messenger window alongside your whispers.
- Use the Whispers / Groups toggle at the bottom of your contacts list to switch between the two views. The tab you last used is remembered across reloads.
- Group messages never trigger the minimap badge — only whispers do.
- Turn off "Show group chats" in Behavior settings to hide the Groups tab entirely and keep the window whisper-only.
- When the Groups tab is empty, a hint now explains how to populate it.

## [1.1.9] - 2026-04-18

- Fixed: replying to a whisper from WoW's default chat during a Mythic+ or boss fight no longer makes WhisperMessenger pop open on the next Enter after the fight.
- Fixed: turning off "Auto-open on outgoing whisper" now keeps outgoing whispers in WoW's normal chat box.
- Fixed: the messenger window can be resized narrower, down to about 480px wide.
- The incoming whisper popup now shows the sender's class icon, auto-dismisses after 30 seconds (new slider: 0–120s), and can sit to the left, right, above, or below the chat icon. Right-click anywhere on it to dismiss, and the dismissal is remembered across /reload and re-login.
- The messenger always jumps to the most recent message and auto-selects the contact with new unread whispers. The two old toggles for these are gone.
- The Options panel reflows as you resize the window, so nothing gets clipped on narrow widths.
- Added eleven more notification sounds, and the draggable chat icon now picks up the colors of your chosen theme.

## [1.1.8] - 2026-04-17

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
