# Changelog

Player-friendly release notes for WhisperMessenger. This file covers the current 2.x series; older series live in [archive/changelog/](archive/changelog/).

All releases: **2.2.x (current)** · [2.1.x](archive/changelog/2.1.md) · [2.0.x](archive/changelog/2.0.md) · [1.4.x](archive/changelog/1.4.md) · [1.3.x](archive/changelog/1.3.md) · [1.2.x](archive/changelog/1.2.md) · [1.1.x](archive/changelog/1.1.md) · [1.0.x](archive/changelog/1.0.md) · [0.1.x](archive/changelog/0.1.md)

## [Unreleased]

## [2.2.0] - 2026-11-27

- On WoW: Forever, you can now use the messenger with a controller: move through your chats and buttons, scroll the chat, and press B to close.
- On WoW: Forever, the settings pages now work with a controller, including picking a choice from a drop-down list with the D-pad, however long the list is.
- On WoW: Forever, pop-up pickers and dialogs now work with a controller.
- On WoW: Forever with a controller, press A on the message box to start typing and A again to send; B leaves the message box. A small hint shows both buttons. Typing itself still needs an on-screen keyboard or a real one.
- On WoW: Forever with a controller, sliders now have − and + buttons (the D-pad stops on those, so pressing A can no longer make a slider jump) and the blocked players list has up and down buttons; they show only while the game's controller mode is on. The D-pad moves across the title bar, the settings list and the Whispers / Groups tabs in the order you see them, and on a settings page up and down go through its controls row by row, left and right stay in the row, and left from the first control goes back to the page's name in the list.
- On WoW: Forever with a controller, press X on a contact, a message or the chat header to open its menu.
- Fixed: on WoW: Forever with the game's controller mode on, right-clicking a contact, a message or a player name in a chat no longer causes "Interface action failed" in combat or blocks the Group Finder afterwards. Whisper Messenger shows its own menu there while controller mode is on; with the mouse, the game's usual menus are back.
- Fixed: on WoW: Forever with the game's controller mode on, settings drop-down lists open WhisperMessenger's own list (in the game's style under the Native look), so they no longer interfere with other game menus or the controller's back button. Under the Native look, the game's usual drop-down lists come back when you play with the mouse.
- Fixed: on WoW: Forever with the game's controller mode on, the New Whisper button no longer stops the controller from working or causes "Interface action failed" until a reload. It asks for the name in Whisper Messenger's own pop-up there.
- Fixed: the What's New title no longer runs under the scrollbar when the window is narrow; it drops the date, and if it still doesn't fit it ends in "...".
- Fixed: on WoW: Forever under the Native look, the settings drop-down lists are no longer see-through, and the chosen option is marked with a check in gold text.
- Fixed: on WoW: Forever, some settings drop-down lists no longer open as an empty box.
- Fixed: a drop-down list near the bottom of a settings page is no longer cut off: the page scrolls to show it, and where it can't, the list opens upward.
- Fixed: scrolling through the Filters or Behavior settings page could make the game slow down more and more until the page was closed.
- Receiving whispers costs less performance when you have many saved conversations.
- The chat window feels smoother while you type long messages or resize it.
- Fixed: with group chats turned off, guild, party and raid chat is no longer saved in the background and no longer pushes out older whisper conversations. Mention alerts from those chats also stay quiet while group chats are off.
- Fixed: starting a Battle.net whisper in the game's chat no longer adds an empty conversation to the messenger or pushes out an older one.
