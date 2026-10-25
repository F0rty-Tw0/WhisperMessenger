# Changelog

Player-friendly release notes for WhisperMessenger. This file covers the current 2.x series; older series live in [archive/changelog/](archive/changelog/).

All releases: **2.1.x (current)** · [2.0.x](archive/changelog/2.0.md) · [1.4.x](archive/changelog/1.4.md) · [1.3.x](archive/changelog/1.3.md) · [1.2.x](archive/changelog/1.2.md) · [1.1.x](archive/changelog/1.1.md) · [1.0.x](archive/changelog/1.0.md) · [0.1.x](archive/changelog/0.1.md)

## [Unreleased]

- Other addons can now show their alerts on the messenger's widget and open a chat with a player. They can also add their own page to the messenger window, opened from a tab next to Whispers, Groups and Channels.
- The buttons along the top of the messenger window are larger and easier to hit.
- With the Native WoW HUD on, the message preview next to the messenger button now uses the game's tooltip border.
- The message preview next to the messenger button is now larger, with bigger text and more room, so item links no longer touch its border.
- Left-clicking the message preview next to the messenger button now opens that player's chat.
- The number on the messenger button and minimap icon now also counts items waiting in addon pages (for example Craft Alert leads you haven't answered yet).
- Clicking the messenger button, minimap icon or Broker icon while only an addon page has something waiting (like a Craft Alert lead) now opens that page instead of your whispers. Unread whispers still open your whispers first.
- Notes that other addons show under a player's name in a chat can now show more detail when you hover them (for example, Craft Alert can show how a request was matched).
- New setting under Behavior: Allow addon integration. Turn it off to stop other addons (like Craft Alert) from adding pages, previews or notes to Whisper Messenger. Changing it asks to reload the interface.
- Shift-clicking the messenger button, minimap icon or Broker icon (or choosing Mark all as read) now also clears alerts from other addons, like Craft Alert.
- Fixed: hovering an item link in the message preview now shows the item's tooltip.
- Fixed: a whisper from the chat you had open no longer counts as read while another addon's page or the settings cover it, so its preview and unread number show. Going back to the chat marks it read.

## [2.1.1] - 2026-10-23

- The chat header now shows the player's race next to their level and class. When the race is known, Horde and Alliance show only as the icon next to the name.
- Chat bubbles now show the sender's level after their name, like "Nergrom (20)".
- When someone you have a whisper chat with talks in group or channel chat, their whisper chat now picks up the level learned from that message. Needs "Show player levels" turned on.
- Looking a player up with /who (or Shift+clicking their name) now shows their level on their earlier messages in channel and group chats. Needs "Show player levels" turned on.
- The Modern window style now has a smooth dark background behind your chat list, messages and settings, so text is easier to read.
- Settings pages now sit centered in a wide window; as the window narrows, the side space shrinks until the page lines up as before.
- Azeroth theme: your sent messages and the selected or hovered buttons in settings now use white text instead of gold, so they're easier to read. Titles stay gold.
- Player names in chats and in the new-message preview are now always shown in their class color; the "Class-colored names" setting is gone.
- While you're using the messenger, Escape closes it before other windows, like an open profession window. The messenger's own menus, pop-up dialogs and spell targeting still close first, and in combat Escape works as usual, so it still stops your casts.
- Fixed: with the Native WoW HUD on, the bottom of the settings page no longer spills over the window border.
- Fixed: the chat list's scrollbar no longer slides under the top bar of the open chat.
- Fixed: clicking a window that sits over the messenger, like the Auction House, no longer pulls the messenger in front of it.
- Fixed: after you click another window, like the Auction House, Escape closes that window and leaves the messenger open; the next press closes the messenger. With the reaction picker or a message's delivery menu open, Escape closes just that first.
- Fixed: on WoW: Forever, clicking a chat no longer pops open the Group Finder's Who list.
- Fixed: while chat is locked for addons (Mythic+, boss fights, rated PvP), channel messages no longer fill the game's taint log with "blocked because of taint from WhisperMessenger" warnings.

## [2.1.0] - 2026-10-15

- Whispers you get or send during Mythic+, boss fights and rated PvP now show up in the messenger once the fight is over.
- After you look a player up with /who, their whisper chat shows the zone they were in and how long ago (for players outside your guild and communities). For chats where the game cannot tell if the player is online, the zone replaces the guessed "Offline" label. Needs "Show player levels" turned on.
- Shift-click a name in the contacts list, the chat header, or a group or channel chat to look that player up with /who.
- You can now hide the "(Invite to WM)" link in the chat header under Options > Whispers ("Show invite link"). With it off, the addon never sends the invite whisper.
- Fixed: replying to a whisper while chat was locked for addons caused an error instead of waiting to be sent.
- Fixed: dragging a pinned chat to reorder it no longer crashes the game on WoW: Forever.
- Fixed: on WoW: Forever, typing `/w John Doe` in the chat box no longer pops the messenger open after the first name. It now waits for the full first and last name.
- Fixed: the "whispers arrived during the fight" count could include whispers from an earlier fight.
- Fixed: a long whisper that arrived just as a fight ended could play the alert sound twice.
- Fixed: after leaving Mythic+, a raid or a locked fight through a loading screen, your whispers could stay stuck as "Queued" in the open world because the addon still thought you were locked in.
- Fixed: pressing R in housing edit mode removes the selected decor again. The addon now lets go of the reply key while you decorate.
- Fixed: other windows (the AddOn List, Edit Mode outlines, raid frames) no longer half-cover the messenger with only their border or outline drawn on top of it.
- Fixed: clicking the Whispers, Groups or Channels tabs, or a chat in the list, now brings the messenger to the front like clicking the window does.
