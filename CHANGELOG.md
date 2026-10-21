# Changelog

Player-friendly release notes for WhisperMessenger. This file covers the current 2.x series; older series live in [archive/changelog/](archive/changelog/).

All releases: **2.1.x (current)** · [2.0.x](archive/changelog/2.0.md) · [1.4.x](archive/changelog/1.4.md) · [1.3.x](archive/changelog/1.3.md) · [1.2.x](archive/changelog/1.2.md) · [1.1.x](archive/changelog/1.1.md) · [1.0.x](archive/changelog/1.0.md) · [0.1.x](archive/changelog/0.1.md)

## [Unreleased]

- The chat header now shows the player's race next to their level and class. When the race is known, Horde and Alliance show only as the icon next to the name.
- Chat bubbles now show the sender's level after their name, like "Nergrom (20)".
- Player names in chats and in the new-message preview are now always shown in their class color; the "Class-colored names" setting is gone.
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
