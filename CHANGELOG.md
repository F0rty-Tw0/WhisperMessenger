# Changelog

Player-friendly release notes for WhisperMessenger. This file covers the current 2.x series; older series live in [archive/changelog/](archive/changelog/).

All releases: **2.0.x (current)** · [1.4.x](archive/changelog/1.4.md) · [1.3.x](archive/changelog/1.3.md) · [1.2.x](archive/changelog/1.2.md) · [1.1.x](archive/changelog/1.1.md) · [1.0.x](archive/changelog/1.0.md) · [0.1.x](archive/changelog/0.1.md)

## [Unreleased]

- Whispers can now be about three times longer. Long messages are sent in a few parts and show as one message when your friend also uses Whisper Messenger. Group chats keep the old length.
- The addon now goes by "Whisper Messenger" everywhere: the AddOns list, the window title, the icon tooltips, chat messages and the options.
- A burst of whispers from one person now plays the alert sound once instead of once per line.
- Busy group chats no longer slow the game down while the window is open.
- Uses less CPU while the window is closed: incoming whispers, friends changing status, busy Trade and General chat, and clicking around the game now do much less work behind the scenes for a window you can't see. Searching your contacts also stays smooth while you type.
- Repeated messages from the same player now show once with a counter (like ×3) in your theme's accent color.
- Right-click the top of a conversation (the name or status) to open its menu. For a player, that includes invite to group, ignore and report.
- Fixed: scrolling up through a long chat, like a busy Trade channel, used a lot of CPU. The window now only draws the messages that scroll into view, and new messages no longer redraw the ones you're reading.
- Fixed: after clicking somewhere else, your action bars and other addons' buttons drew on top of the window.
- Fixed: with the Native WoW HUD look, the unread counter on the Whispers, Groups and Channels tabs was half hidden behind the window's bottom border.
- Fixed: with "Hide whispers from default chat" on, your reply key did nothing if the game's "Cast action keybinds on key down" option was turned off.
- Fixed: choosing "Whisper" after right-clicking a player's name in the window (in guild, group and channel chats, or on a contact) did nothing.
- Fixed: right-clicking the name of a guild or group member who isn't your Battle.net friend showed a menu without "Whisper".
- Trade, General, Local Defense, LFG and your custom channels can now appear as chats (turn them on in Options). Each one is named after its channel and lives in a new Channels tab, which shows up once you turn on at least one channel. Trade, General, Local Defense, World Defense, LFG and Trade (Services) each get their own icon, and in the narrow contact list channel chats show their initials like your contacts do.
- New option in Appearance: Show player levels (off by default). It shows a player's level, colored like the quest log by how it compares to yours, at the top of a chat next to their class ("Level 80 Shaman") for Battle.net friends and guild or community members, and before names in group and channel chats ("20:Nergrom"). Offline contacts keep the last level seen. Levels before names show on messages that arrive after you turn the option on.
- Channel chats such as General and Local Defense show their zone (like Durotar) under the channel name at the top of the chat.
- Channel chats only count as unread when someone says your name, so a busy Trade chat doesn't bury your other unread chats. Muting a channel chat also silences the alert for your name.
- When someone says your name in a group or channel chat, with or without an @ in front, your name in their message now shows in your class color.
- New option in Appearance: show player names above their messages in their class color, in whispers, group and channel chats, and in the new-message preview next to the messenger icon. On by default; turn it off there if you prefer plain names.
- Right-click a player in your contacts and choose Block…, or right-click one of their messages in a group or channel chat and choose Block sender…, to stop seeing anything they send. You can add a note saying why. A chat with a player you blocked shows "Blocked" in red at the top. Right-click a blocked player in your contacts, or their name in a group or channel chat, and choose Unblock to see their messages again.
- Options are split into Behavior, Whispers, Chats and Filters pages; the new Filters page manages blocked players and keyword rules, and starts with a short guide to what each one hides and how to write rules.
- Keyword rules come with ready-made spam filters borrowed from Global Ignore List: "Anal" link spam and Thunderfury links (on), plus Mythic+ and raid sellers, profession sellers, power-leveling sellers, guild recruitment, community recruitment and WTS / WTB / LFW (off until you turn them on). The ready-made filters only apply to channels such as Trade, never to your guild, party or raid. Click any rule to change its words; separate words with / when any one of them should count, and put a word or phrase in "quotes" to match only that whole word or phrase (so "anal" no longer catches canal or analysis). A ready-made filter you remove stays removed until you press Reset to Defaults, which brings them all back and clears your own rules.
- The "Max Messages Per Contact" option is now called "Max Messages Per Chat", since it covers group and channel chats too.
- The notice shown during Mythic+ and PvP now says messages are paused, not just whispers, since group and channel chats pause too. In a whisper chat it also tells you how to reply right away from the game's own chat.
- Fixed: the Mythic+ pause notice now shows in your game's language instead of always in English.
- Blocked players are now also hidden from the game's own chat window (say, yell, emotes and channels), and so are channel lines your keyword rules block. Channels you read in WhisperMessenger stay in the game's chat too, unless you turn on "Hide channels from default chat" under Options > Chats. None of this hiding happens in Mythic+, boss fights or PvP.
- Entering or leaving a Mythic+ dungeon no longer posts "Suspended" and "Resumed" lines in your chat; the window and its icon already show that messages are paused.
- Fixed: right-clicking a player's name in a group or channel chat now opens that player's menu instead of the chat's own menu, with WhisperMessenger's Block… at the bottom.
- Fixed: Opening the window now jumps to the newest unread chat on the tab you're looking at, instead of skipping it when an unread chat on another tab is newer.
- Fixed: with the Native WoW HUD on, the Whispers, Groups and Channels tabs under the window are now the same size as the game's own window tabs instead of oversized. Unread counts sit on each tab's top corner.
- Fixed: the tabs under the window now always fit its width, even with Requests turned on; a long tab name is shortened and shows in full when you point at it.
- Fixed: on Classic game versions, text boxes in pop-ups (editing a filter rule, starting a whisper, copying a message) no longer stick out past the pop-up's edges, and the pop-up no longer gets wider each time it opens.
- Fixed: on Classic game versions, the tabs under the window with the Native WoW HUD on were about twice as wide as they should be.
- Fixed: on the Filters page, long rule and player names no longer run into the blocked count at large font sizes. Each row now shows the name on one line with "Blocked N this session" underneath.
- Point at a player in the Filters page's block list to read their full last blocked message, the reason and this session's count.
- You can name your own keyword rules: Add rule asks for a name and the words, and clicking one of your rules lets you change both.
- Blocked counts on the Filters page now count only the current session and start again from zero every time you log in or reload.
- Fixed: with a large font size, the welcome message no longer runs past the edges of the chat area, and the right edge of Options pages is no longer cut off.
- The search box, and the magnifier on the narrow contact list, are hidden on a tab that has no chats to search.
- Fixed: scrolling the Filters page with the mouse wheel no longer stops when the blocked players list passes under the pointer.
- Fixed: after you accept a message request, the Requests tab no longer keeps showing that chat; it shows its empty page.
- The Classic look's scrollbars are slimmer: a smaller gold knob with no dark strip behind it, so lists and Options pages keep more room.
- Fixed: with a large font size, the name, status and zone at the top of a chat no longer spill into the messages below, and the paused-in-Mythic+ notice no longer covers the last message.
- Fixed: with a large font size, the message request bar above the text box grows to fit its text instead of spilling over the chat, and a long name at the top of a chat is shortened so "(Invite to WM)" stays inside the window.
- Fixed: with the Native WoW HUD on, buttons in Options and pop-ups (like Add rule) now light up when you point at them.
- Each page in the Options menu now has a small icon next to its name, so you can find pages at a glance. With the Native WoW HUD on, the menu stays text only like the game's own.
- Deleting a message request now opens the next one, so the empty Requests page only shows once none are left.
- Changing the Native WoW HUD style now only sticks if you press Reload UI in the pop-up. Pressing Cancel keeps the style you have now, instead of switching on your next reload.

## [2.0.2] - 2026-10-02

- Battle.net friends now show without the #1234 part of their BattleTag, handy for streaming and screenshots. Two friends with the same name keep their numbers so you can tell them apart. Turn it off under Options > General > Privacy ("Hide BattleTag numbers").
- Shift-click the floating icon or the minimap icon to mark every chat as read without opening the window.
- The Native WoW HUD option is now a choice: Off, Classic or Modern. If you had it turned on, you get Classic, the look you already know. Find it under Options > Appearance.
- New Modern style: the window looks like the modern game's own windows, such as the professions window. It has the addon's round portrait in the corner, separate panels for your contacts and the chat, slim rounded scrollbars, and the title bar buttons on the right next to the settings gear. Options pages show their titles on the ornate banners from the character window. Modern is greyed out on game versions that can't show it.
- Classic and Modern now dress the whole window, not just its frame: pop-ups and menus, chat bubbles, the contact list, the options, and the window's icon buttons and resize corner all use the game's own borders, highlights, checkboxes, sliders, scrollbars, buttons and menus, while keeping your theme's colors.
- With Classic or Modern, the title bar icons are now easier to see against the game's frame art.
- The Send button now shows a simple arrow instead of a paper plane.
- The Whispers, Groups and Requests tabs now hang below the window like the game's own tabs, in every look, and the contact list gets that space back.
- New installs now start with the Modern style and the Azeroth theme on Retail and WoW: Forever, and with whispers hidden from the default chat window on every game version. "Reset to Defaults" in the options now picks these too. If you already use the addon, your settings stay as they are.
- Changing the Native WoW HUD style now offers to reload the interface right away, so you don't have to type /reload. Turning on Classic or Modern from Off and pressing Reload UI also switches the theme to Azeroth to match; you can still pick any other theme afterwards, and moving between Classic and Modern keeps your theme.
- The Azeroth theme's sent messages now sit on a dark bronze bubble instead of purple, to match its gold accents.
- The options menu no longer shows an "Options" title, so the page list starts higher.
- Drag the line between your contacts and the chat far to the left to fold the contact list into a slim strip of portraits: each friend's usual class icon, dimmed, with their initials on top (group chats keep their pictures). Drag back to the right and the full list follows your mouse out again; you can go back and forth as often as you like without letting go. Unread counts and online dots stay on each picture, hovering one shows who it is, their zone, status and last message, and the window can be made much narrower. The magnifier at the top of the strip opens search, and pinned friends can still be dragged into a new order. The window remembers which one you used.
- Right-click a contact, in the full list or the slim strip, to pin, unpin or remove it.
- Fixed: pressing R to reply no longer types an "r" into the message box, even when the chat already had a half-typed message.
- Fixed: with a big font size (14 and up), a contact's zone and last message no longer overlap in the contact list. Rows now get taller as the font grows.
- Fixed: clicking the Window Scale slider's bar no longer jumps the window to a new size. Drag the handle to change the scale.
- Fixed: an empty contact list no longer shows a scrollbar after you make the window smaller, and its hint text stays centered and wraps to fit the list.
- Fixed: the scrollbars on the options pages and in the chat no longer slide out of view after you resize the window.
- Fixed: the WoW: Forever beta no longer lists the addon as out of date.
- Fixed: long option names in the settings no longer run underneath their on/off switch on a narrow window; they now wrap onto a second line.

## [2.0.1] - 2026-09-26

- Now works on World of Warcraft: Forever (beta). Mythic+ features stay off there.
- New "Pandaria" theme: dark charcoal with jade-green accents (pairs well with EllesmereUI).
- Fresh modern look for every theme, including Azeroth:
  - Cleaner window: no more boxes inside boxes, a soft shadow, and thin crisp lines.
  - Matching line icons in the title bar, a centered window title, a paper-plane Send button, and smooth hover fades.
  - Softer highlight on the selected contact; pin and remove buttons only appear on hover.
  - Compact contact rows and a slimmer message area, so more fits on screen.
  - Unread count circles all match the theme color and look smooth.
  - Whispers / Groups switch is now a footer tab bar.
  - Messages fade softly at the top and bottom of the chat as you scroll.
  - For a game-style frame, turn on the Native WoW HUD option.
- Writing messages:
  - Each chat keeps its own half-typed message, even after a reload. It no longer follows you to the next contact, and the contact list shows a red "Draft:".
  - Reply to a message: right-click a whisper and pick "Reply". Friends who use WhisperMessenger see the quoted line too.
  - Quick replies: a new button next to the emoji button drops in a saved reply like "On my way". Edit your list (up to 10) under Options > Behavior.
  - Messages that didn't go out now show "(Queued)" or "(Not sent)" next to the time. Click it to send, retry or discard.
  - Pressed Send just as whispers got paused (Mythic+, boss fight, arena, battleground)? Your message now waits as "Queued" instead of being lost. Nothing is sent until you click.
- Contacts:
  - Right-click a contact to mute them, give them a nickname, add a private note, or get told when they come online. These options now sit under their own gold "WhisperMessenger" heading.
  - Muted chats stay silent: no sound, popup or taskbar flash, and their unread count turns grey.
  - Nicknames show instead of the real name, and notes show at the top of the chat. Contact search finds both.
  - Offline contacts now show when they were last online, for example "Last online 2h".
  - Requests (optional): turn it on under Options > Behavior, and whispers from strangers wait quietly in a new Requests tab until you accept or delete them.
  - Dragging a pinned contact shows a card under your pointer and a line where it will land.
- Reading:
  - A "New messages" line marks where your unread messages start. Long backlogs open at that line.
  - A new "Mark all as read" button in the top-left corner clears every unread count at once.
  - Group chats highlight messages that mention your name and show an "@" on the chat.
  - A welcome message shows when no chat is open, and the Groups tab explains where party, raid, instance and guild chats show up.
  - Custom channels show just their name (like "CraftScan") without the channel number.
- Native WoW HUD option now looks like the game all the way through:
  - A standard search box, game-style Whispers / Groups tabs, a classic message box, and red-gold buttons.
  - The "Start a new conversation" and copy-message popups use the game's standard dialog look.
  - Cleaner layout: no empty strip above the chat, one even background behind both sides, and the full addon name in the title.
- Refreshed settings: simple page list, on/off switches, slim sliders and cleaner choice buttons.
- The "(Invite to WM)" link is now gold and translated into every supported language.
- Hovering the WhisperMessenger button or minimap icon shows the key that opens the messenger.
- What's New: the button now pulses with the same soft glow as the WhisperMessenger button and minimap icon, and the page puts a thin line between changes so it's easier to scan.
- Fixed: new whispers flash the taskbar icon again while you're tabbed out, even with whispers hidden from normal chat. You can turn this off under Options > Notifications.
- Fixed: the message box stopped one letter short of a full-length whisper.
- Fixed: old chats weren't removed by your Message Retention setting while the window was open.
- Fixed: contacts you had whispered could stay "Online" after they logged off.
- Fixed: whispering an offline guildmate showed a blank contact with no class, race or portrait.
- Fixed: the unread count on a contact pressed against the edge of the list.
- Fixed: a channel post shown in a whisper chat vanished after a reload.
- Fixed: reloading while in a group started a second group chat.
- Fixed: long button names in settings touched the button edges.
- Fixed: an "Invalid import" error on login in World of Warcraft: Forever.
