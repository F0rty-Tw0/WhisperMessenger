# Changelog

Player-friendly release notes for WhisperMessenger. This file covers the current 2.x series; older series live in [archive/changelog/](archive/changelog/).

All releases: **2.0.x (current)** · [1.4.x](archive/changelog/1.4.md) · [1.3.x](archive/changelog/1.3.md) · [1.2.x](archive/changelog/1.2.md) · [1.1.x](archive/changelog/1.1.md) · [1.0.x](archive/changelog/1.0.md) · [0.1.x](archive/changelog/0.1.md)

## [Unreleased]

- Busy group chats no longer slow the game down while the window is open.
- Repeated messages from the same player now show once with a counter.
- Trade, General, Local Defense, LFG and your custom channels can now appear as chats (turn them on in Options).
- Channel chats only count as unread when someone says your name, so a busy Trade chat doesn't bury your other unread chats. Muting a channel chat also silences the alert for your name.
- Right-click a player in your contacts and choose Ignore…, or right-click one of their messages in a group or channel chat and choose Ignore sender…, to stop seeing anything they send. You can add a note saying why.
- Options are split into Behavior, Whispers, Chats and Filters pages; the new Filters page manages ignored players and keyword rules.
- The "Max Messages Per Contact" option is now called "Max Messages Per Chat", since it covers group and channel chats too.
- Fixed: Opening the window now jumps to the newest unread chat on the tab you're looking at, instead of skipping it when an unread chat on another tab is newer.

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
