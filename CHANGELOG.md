# Changelog

Player-friendly release notes for WhisperMessenger. This file covers the current 2.x series; older series live in [archive/changelog/](archive/changelog/).

All releases: **2.0.x (current)** · [1.4.x](archive/changelog/1.4.md) · [1.3.x](archive/changelog/1.3.md) · [1.2.x](archive/changelog/1.2.md) · [1.1.x](archive/changelog/1.1.md) · [1.0.x](archive/changelog/1.0.md) · [0.1.x](archive/changelog/0.1.md)

## [Unreleased]

## [2.0.0] - 2026-09-23

- Now works on World of Warcraft: Forever (beta). Mythic+ features stay off there.
- New "Pandaria" theme: dark charcoal with jade-green accents (pairs well with EllesmereUI).
- Fresh modern look for every theme, including Azeroth:
  - Cleaner window: no more boxes inside boxes, a soft shadow, and thin crisp lines.
  - Matching line icons in the title bar, a paper-plane Send button, and smooth hover fades.
  - Softer highlight on the selected contact; pin and remove buttons only appear on hover.
  - Compact contact rows and a slimmer message area, so more fits on screen.
  - Unread count circles all match the theme color and look smooth.
  - Whispers / Groups switch is now a footer tab bar.
  - For a game-style frame, turn on the Native WoW HUD option.
- The Groups tab now has its own welcome screen that explains where party, raid, instance and guild chats show up, instead of offering to start a whisper.
- Native WoW HUD option now looks like the game all the way through:
  - A standard search box, game-style Whispers / Groups tabs, a classic message box, and red-gold buttons.
  - The "Start a new conversation" and copy-message popups use the game's standard dialog look.
  - Cleaner layout: no empty strip above the chat, one even background behind both sides, and the full addon name in the title.
- Refreshed settings: simple page list, on/off switches, slim sliders and cleaner choice buttons.
- A welcome message shows when no chat is open.
- Custom channels show just their name (like "CraftScan") without the channel number.
- Dragging a pinned contact shows a card under your pointer and a line where it will land.
- Fixed: a channel post shown in a whisper chat no longer vanishes after a reload.
- Fixed: reloading while in a group no longer starts a second group chat.
- Fixed: the "Enter to send" hint and title bar buttons could be nearly invisible in some themes.
- Fixed: button outlines could show gaps or lose sides, especially after changing window scale.
- Fixed: long button names no longer touch the edges, and tab unread counts no longer push names off-center.
