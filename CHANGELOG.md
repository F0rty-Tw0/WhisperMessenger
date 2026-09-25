# Changelog

Player-friendly release notes for WhisperMessenger. This file covers the current 2.x series; older series live in [archive/changelog/](archive/changelog/).

All releases: **2.0.x (current)** · [1.4.x](archive/changelog/1.4.md) · [1.3.x](archive/changelog/1.3.md) · [1.2.x](archive/changelog/1.2.md) · [1.1.x](archive/changelog/1.1.md) · [1.0.x](archive/changelog/1.0.md) · [0.1.x](archive/changelog/0.1.md)

## [Unreleased]

## [2.0.0] - 2026-09-23

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
- Fixed: new whispers flash the taskbar icon again while you're tabbed out, even with whispers hidden from normal chat. You can turn this off under Options > Notifications.
- Fixed: the message box stopped one letter short of a full-length whisper.
- Fixed: old chats weren't removed by your Message Retention setting while the window was open.
- Fixed: contacts you had whispered could stay "Online" after they logged off.
- Fixed: whispering an offline guildmate showed a blank contact with no class, race or portrait.
- Fixed: the unread count on a contact pressed against the edge of the list.
- Fixed: a channel post shown in a whisper chat vanished after a reload.
- Fixed: reloading while in a group started a second group chat.
- Fixed: long button names in settings touched the button edges.
