# Changelog

Player-friendly release notes for WhisperMessenger. Each version below focuses on the changes most people will actually notice in game.

## [1.2.15] - Unreleased

- Fixed: with "Desaturate icon when idle" on, the minimap icon now lights back up when unread whispers arrive instead of staying grey.
- Fixed: message preview popups no longer float next to the minimap while the minimap icon is turned off, and no longer pop up while you're already reading that conversation.
- Fixed: the unread badge pulse animation now works on the minimap icon too.
- Fixed: flipping badge settings no longer briefly shows an inflated unread count that included group chats.
- Fixed: messages in Battle.net group conversations now land in the right conversation instead of all piling into the first one.
- Fixed: a Battle.net friend logging out of WoW no longer blanks out their character name in your contact list.
- Fixed: the whisper notification sound no longer plays for messages that couldn't be delivered to the messenger.
- Fixed: starting a Mythic+ key no longer forgets that the messenger window was open, so it reopens correctly when the key ends, and whispers resume more reliably after restricted content ends.
- Fixed: pinned conversations can no longer be silently deleted when the conversation limit is reached.
- Fixed: Battle.net whispers received right after logging in, before your friend list loads, now end up in the same conversation as the rest of that friend's messages instead of a separate orphaned thread.
- Fixed: older saved conversations merged from multiple characters now show their messages in the right order.
- Fixed: brand-new conversations are no longer at risk of being cleaned up by history pruning before their first message arrives.
- Fixed: the icon mode switch and its choices are now translated in all supported languages.
- Fixed: date separators now show the proper full month name for May in Spanish, Italian, Russian and other languages.
- Fixed: the "Yesterday" label now follows your local midnight instead of flipping at odd hours depending on your timezone, and 12-hour timestamps no longer show a leading zero (2:30 PM instead of 02:30 PM).
- Fixed: the Raid conversation no longer claims you can send to it while you're only in a battleground or dungeon-finder group.
- Smoother gameplay in raids and with large friend lists — the addon now does far less background work when other addons chatter or your Battle.net friends change status.
- Fixed: switching themes now also recolors the date separator lines in open conversations.
- Fixed: unpinning a contact no longer leaves its row occasionally swallowing clicks.
- Fixed: "Reset to Defaults" in Behavior settings no longer switches on the game-wide mature language filter.
- Fixed: resizing the contacts pane now lands exactly where you release the divider, and resetting appearance settings restores the inactive window opacity consistently.
- Fixed: contacts with unrecognized class data now show the Battle.net icon instead of an empty circle.

## [1.2.14] - 2026-07-17

- WhisperMessenger now has its own icon around the minimap ring. You can drag it to any angle, and the icon snaps to the minimap's edge even on non-round minimap shapes. Switch between the free-floating widget icon and the minimap icon in the Notifications settings tab.
- Added support for display bars like Bazooka and ChocolateBar — see the unread count and addon name right on your bar, and click to open the messenger.

## [1.2.13] - 2026-06-18

- Updated for World of Warcraft patch 12.0.7 (Midnight).

## [1.2.12] - 2026-06-10

- WhisperMessenger now shows its own icon next to its name in the in-game AddOn list.

## [1.2.11] - 2026-05-24

- Fixed: keeping the messenger open through loading screens, zone changes, and long whisper sessions no longer lets stale background refreshes, temporary message-tracking data, or invisible leftover bits from re-drawing your conversations build up over time. After many hours with the window open, the game now stays as smooth as when you first opened it.
- Fixed: short conversations with only one or two message bubbles no longer show a tiny scrollbar that moves by a few pixels. New incoming messages also snap back to the latest message more reliably after WoW finishes updating the chat layout, instead of sometimes landing in the middle of the thread.

## [1.2.10] - 2026-05-23

- Fixed: when you whisper a quest link in WoW Classic to someone else who also has the messenger installed, they now see it as a fully clickable link in their conversation, instead of just the quest name with no way to open it. This works the same way for regular whispers and Battle.net whispers. Whispering to players who don't have the addon still shows only the quest name — that part is decided by WoW Classic's chat itself and can't be worked around.
- The composer now caps your message at 255 characters as you type, matching WoW's chat limit, so nothing you write is silently cut off when you press Send.
- New setting in the Notifications tab: lock the chat icon in place so you can't drag it by accident. While the icon is locked, hovering it shows a small padlock and adds "Locked" to its tooltip. Translated into every language the addon supports.

## [1.2.9] - 2026-05-13

- Fixed: quest links in WoW Classic character whispers now work end-to-end. Shift-clicking a quest inserts a clickable link in the composer, and your own message bubble shows it as a clickable link too. Battle.net whispers already worked.

## [1.2.8] - 2026-05-06

- Shift-clicking a quest from the quest log in WoW Classic now sends a real clickable link instead of plain text like `[Apprentice's Duties (471)]`.
- Fixed: Korean, Chinese, and Russian text no longer shows as squares when the messenger is set to a language different from your WoW client. Note: in that case the font size and outline sliders won't apply — those scripts use the game's default size to stay readable.

## [1.2.7] - 2026-05-05

- Added localization in German, Spanish, French, Italian, Portuguese, Russian, Korean, Simplified Chinese, and Traditional Chinese.

## [1.2.6] - 2026-05-03

- Fixed: typing `/w Name` in WoW's chat box no longer pops the messenger open on the first letter of the name. The messenger now waits until you finish typing the name (and add a space) before taking over, so you can type `/w Name` without the window jumping in mid-name.
- Opening the messenger while the Auction House, World Map, or another window is up now brings it to the front instead of leaving it stuck behind. Clicking the message input also lifts the window forward, just like clicking the window's frame or title bar.

## [1.2.5] - 2026-05-01

- Leaving a party, raid, or instance now shows the time alongside the "Left party." note in the conversation, so you know exactly when the group ended.
- Fixed: pressing the reply key (R by default) no longer inserts the letter "r" into the composer input when the messenger opens.
- Fixed: pressing Enter after leaving combat no longer unexpectedly opens the messenger when WoW's chat box still had a whisper reply target set from the fight.
- Fixed: typing `/w` to a character after a Battle.net whisper no longer gets pulled into the previous Battle.net conversation. The messenger now opens the character chat and carries over only the message text you typed.
- Fixed: Reply after Mythic+ or a raid boss fight now uses the last whispered character when WoW handled the whisper in default chat during the fight.
- Fixed: selected text in the manual copy dialog is now clearly highlighted. The selection was invisible because the styled dark input background made WoW's default blue selection blend in completely.
- Fixed: hovering an item link in a message no longer makes the item tooltip vanish when the System or Morpheus font is selected. The small copy button in the bubble corner could dismiss the tooltip as the cursor crossed over it; it now leaves other tooltips alone.

## [1.2.4] - 2026-04-26

- Fixed: the small copy button only appears when you hover the message itself. It used to also show when hovering the sender name above the message or the class icon next to it.
- Fixed: the copy button always draws on top of the sender name, time, and surrounding bubbles — it could previously hide behind them on short messages or, intermittently, on every other message.
- Fixed: scrolling in the Options panel now works on every tab and matches each tab's actual content. Tall tabs (Appearance, Notifications) scroll all the way to the Reset button at the bottom, and short tabs (General, Behavior) no longer leave empty scroll room below the last control.
- Fixed: when you switched characters and sent a new whisper to someone you'd already messaged on another alt — without them having replied in between — the new message was visually attached to the old character's name and class icon. Each character's messages now correctly show their own name and class.
- Removed the "Ignored" status badge and the auto-greyed Send button. The detection wasn't reliable across realms and locales, so the conversation no longer flips colour or blocks sending based on ignore state.

## [1.2.3] - 2026-04-26

- Conversations with people on your ignore list now turn red and the Send button is greyed out, so you can't accidentally whisper them. The status line shows "Ignored". (Note: WoW does not tell the sender when the other person is ignoring them — only the reverse is detectable.)
- Fixed: when you switched characters and sent a new whisper to someone you'd already messaged on another alt — without them having replied in between — the new message was visually attached to the old character's name and class icon. Each character's messages now correctly show their own name and class.

## [1.2.2] - 2026-04-25

- Fixed: addon no longer shows as "Out of date" after WoW game updates.

## [1.2.1] - 2026-04-25

- Fixed: addon no longer shows as "Out of date" after WoW game updates.

## [1.2.0] - 2026-04-25

- Fresh icons for party, raid, guild, and officer chats in the contacts list and conversation header.
- Hover a message to reveal a small copy button in the corner of the bubble; click it to copy that message's text. Right-click → "Copy Text" still works the same as before.
- The text field in the manual copy popup now matches the rest of the messenger — flat rounded background, no extra outline.
- Right-click the class icon or the sender's name above an incoming message to open the standard player menu — invite to group, whisper, ignore, report, and so on, exactly like right-clicking a name in WoW's chat.
- Fixed: your chosen notification sound, widget preview position, and widget preview auto-dismiss delay now stay selected when you open settings after a relog. Your actual sound and popup behavior were already using the saved value — the settings panel was just showing the defaults. The time format, time source, and message bubble color choices had the same display issue and are fixed too.
- Party, raid, instance, guild, officer, and Battle.net group chats now show up in the messenger. Use the Whispers / Groups toggle at the bottom of the contacts list to switch, or hide Groups entirely in Behavior settings.
- Group history survives /reload, logout, and character switches. Rows from other characters are labeled with the character name ("Jaina — Guild") in that character's class color, and are read-only so you can't send from the wrong alt.
- Guild chat is shared across alts in the same guild — one conversation, with the guild tabard and name in the header. Alts in a different guild get their own row.
- Leaving a party, raid, or instance keeps the chat with a "Left party." note; sending is blocked until you rejoin.
- Only whispers trigger the minimap badge and the incoming popup. Group messages stay quiet.
- Unread counts on the Whispers and Groups tabs now show as a circular badge next to the label, matching the style used on contact rows and the chat icon, instead of a number in parentheses.
- Outgoing messages from other characters keep their original class icon in history, and the sender line reads "You · CharName" so you can tell which alt wrote what.
- Fixed: pressing Reply (or /wr) while a group is selected now jumps to your latest whisper instead of targeting the group.
- Sending a whisper while the Groups tab is active now switches the messenger back to the Whispers tab so you can see the new conversation. Incoming whispers still stay quiet when you're viewing groups — only the chat icon popup and unread count update.
- Fixed: when a whisper arrives while the messenger is open on the Groups tab, the chat icon popup now shows the sender and preview text. Before, the popup was hidden whenever the window was open, so whispers received on the Groups tab had no visible preview.
- Fixed: the conversation pane no longer pulls a whisper back into view while you're on the Groups tab. An incoming whisper or background refresh would previously re-surface the last-selected whisper on screen even though the tab hadn't changed; now the pane only shows conversations that belong to the current tab.
- Fixed: no more error popups during Mythic+ or boss fights — both the dim-while-moving check and group chat capture now behave while chat is restricted.
- Fixed: switching characters no longer spams "Left party." / "Left raid." into alts' group history.
- Fixed: turning "Auto-open on outgoing whisper" off now keeps outgoing whispers in WoW's chat box, and turning it back on no longer traps Enter in a reply loop.
- Fixed: the incoming popup renders Russian, Greek, and other non-Latin letters correctly instead of blank boxes.
- Fixed: new whispers reliably scroll to the newest message.

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

