# Changelog

Player-friendly release notes for WhisperMessenger. This file covers the current 1.4.x series; older series live in [archive/changelog/](archive/changelog/).

All releases: **1.4.x (current)** · [1.3.x](archive/changelog/1.3.md) · [1.2.x](archive/changelog/1.2.md) · [1.1.x](archive/changelog/1.1.md) · [1.0.x](archive/changelog/1.0.md) · [0.1.x](archive/changelog/0.1.md)

## [Unreleased]

- Contacts now show where a Battle.net friend or guild/community member currently is (zone, arena, or dungeon), in a dimmed line under their name in the contact list and in the conversation header, like the Battle.net friends list.
- Fixed: Battle.net friends who are also logged into the Battle.net app or another Blizzard game now show their WoW character, class, faction, and zone again, and no longer appear as "Away" when they are online in WoW.
- Fixed: whispers that arrived while the messenger was open no longer pop up as a preview on the widget a few seconds after you close the window.
- Fixed: after replying to a whisper in the default chat during a Mythic+ run, pressing Enter once the run is over no longer keeps opening the messenger to that person, so you can type in Say and General again.

## [1.4.1] - 2026-09-03

- Added a "?" button next to the Start New Whisper button and a What's New page in Options. The button glows after each update until you open the page, which lists what changed in the latest version.
- Fixed: reactions from character and Battle.net whispers now count as new activity, update the conversation preview, play the configured whisper sound, and open the messenger automatically when enabled; duplicate reactions and removed reactions stay silent.
- Fixed: incoming reaction previews now show emoji in the contact list and notification popup instead of raw reaction text.
- Fixed: reaction markers on sent messages now sit on the left edge, matching the alignment of sent message bubbles.
- Fixed: long status text in the conversation header now stays on one line, shortens with an ellipsis in narrow windows, and returns in full after resizing.
- Fixed: Battle.net conversations merged after friend details load now preserve the newest preview and unread reaction indicator, including activity received in the same second.
- Reduced background CPU use and temporary memory churn by checking Blizzard chat edit boxes only when their focus or text changes, while still opening Battle.net whispers started from an active chat box.
- Reduced background CPU use while other addons communicate, including when the messenger is hidden.
- Reduced CPU use while the messenger is open, especially with many contacts or a high frame rate.
- Long conversations now use less memory and scroll more reliably by rendering only the messages currently visible while keeping the full history available when scrolling.
- Options pages now load when first opened instead of all at once, while keeping their controls and saved settings in sync.
- Fixed: automatic history cleanup now continues during long play sessions, removing stale conversations and old message data while preserving pinned messages.
- Fixed: saved chat history now respects the message limit after a reload, preventing old conversations from keeping excess messages in memory.
- Fixed: delayed or out-of-order messages from expired conversations no longer revive old chats or change their preview, unread count, or contact details.
- Fixed: reaction fallbacks no longer disappear when conversations are automatically cleaned up or merged after Battle.net friend details load.
- Fixed: clearing all chats now cleans up leftover contact status and availability data without interrupting whispers already in progress.
- Fixed: memory usage no longer jumps by a couple of megabytes every 30 seconds when you are in a large guild or community. Contact online status is now looked up per contact instead of scanning every member.
- Fixed: the messenger no longer redraws the conversation and the contact list on every background status refresh when nothing has changed, which cuts memory churn while the window is open.
- Fixed: the window's fade-when-moving check no longer creates memory garbage ten times per second while the messenger is open.

## [1.4.0] - 2026-08-31

- Added message reactions for character and Battle.net whispers plus party, raid, instance, guild, and officer chats. Right-click an incoming message to add or remove a reaction; friends using WhisperMessenger see it attached to the original message, while other players receive a readable fallback.
- Added an emoji picker beside the message composer. Selected emoji appear inline in sent messages and scale with the configured chat font size.
- Fixed readable whisper reaction fallbacks showing your character name, bringing them in line with group reactions.
- Fixed Battle.net reactions from friends not being applied to the original outgoing message.
- Fixed Battle.net whispers causing Secret Value comparison errors during restricted content.
- Fixed unrestricted and legacy boss fights incorrectly pausing the messenger; encounter locks now follow Blizzard's restricted-content signal.
- Fixed Mists Classic Challenge Modes incorrectly activating Retail Mythic+ suspension.
- Appearance - Font Family now lists optional fonts from SharedMedia addons in a scrollable selector instead of three fixed choices, and safely uses Default if SharedMedia or your selected font is unavailable.
- Added an Appearance - Window Scale setting that resizes the entire messenger from 75% to 150%.
- The Options sidebar now scrolls when the window is shortened, and the messenger can be resized 100 pixels shorter without hiding its navigation and reset controls.

