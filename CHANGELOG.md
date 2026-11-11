# Changelog

Player-friendly release notes for WhisperMessenger. This file covers the current 2.x series; older series live in [archive/changelog/](archive/changelog/).

All releases: **2.1.x (current)** · [2.0.x](archive/changelog/2.0.md) · [1.4.x](archive/changelog/1.4.md) · [1.3.x](archive/changelog/1.3.md) · [1.2.x](archive/changelog/1.2.md) · [1.1.x](archive/changelog/1.1.md) · [1.0.x](archive/changelog/1.0.md) · [0.1.x](archive/changelog/0.1.md)

## [Unreleased]

- New option under Whispers: hide the player's last channel message that shows above a new whisper.
- Party, raid and instance chats now show the dungeon, raid or battleground they started in, e.g. "Party - Halls of Atonement - Current".
- New sound options under Notifications: pick a different sound for mentions, and turn on a sound for whispers you send (off by default).
- Community chats now show the community's name, and say that replies go through the game's Communities window instead of looking like you could type there.
- Reading a whisper in the game's own chat now clears it in Whisper Messenger too: click the game's whisper tab for that player, or start a whisper to them there.
- New option under Notifications: play a sound when a whisper lands in Requests, with its own sound so you can tell it apart from a friend's whisper. Off by default.
- New Behavior option "Esc closes the window". Turn it off to keep Whisper Messenger open when you press Esc; close it with its button or your Toggle Window key. Dying or opening a big game panel no longer closes it either while the option is off.
- With "Show player levels" on, opening a chat by clicking a contact, the message preview, or the Whisper Messenger button or minimap icon, by pressing your Reply or Toggle Window key, starting a new whisper, clicking the chat header, or right-clicking a player and choosing Whisper now refreshes that player's level, zone and guild when the info is more than 10 minutes old. Before, a player was looked up only once.
- Fixed: players who are offline no longer show as online in your contact list and chat header, and cross-faction guild or community members who are online no longer show as offline.
- Fixed: with the compact window open, Craft Alert no longer pops its own alert at the top of the screen for a new lead. The Craft Alert tab shows the new lead, and if you close the window soon after, the preview shows on the button.

## [2.1.6] - 2026-11-10

- The message preview can now be detached: pick "Detached" under Preview Position and drag the card anywhere on screen. It keeps its spot after a reload, and with both the widget and the minimap button on you get just one preview.
- Behavior settings now list every addon that uses Whisper Messenger under "Allow addon integration", each with its own checkbox. Untick one and it stops adding pages, previews and notes right away, with no reload. Addons that aren't loaded this session are greyed out and can be removed from the list with Forget.
- Fixed: after you had typed in Whisper Messenger once, linking an item in normal chat during a boss fight could make the game block your message and blame Whisper Messenger.
- Fixed: clicking an item link in the message preview or the Whisper Messenger window during combat no longer shows an "Interface action failed because of an AddOn" message. The item tooltip still opens.
- Fixed: shift-clicking a player's name in Whisper Messenger while you're typing a message now puts the name in your message without also running a /who.
- Fixed: the Link button at the top of the Professions window puts your profession link into the Whisper Messenger message box again.
- Fixed: right-clicking a player's name in chat while typing in Whisper Messenger no longer puts a broken link in your message that the game refuses to send.
- Fixed: the "Start a new conversation" box opened from an empty chat no longer sticks out past the edges of its window.
- Fixed: the Whisper Messenger button can no longer be dragged off the screen, and a button that was already off screen comes back to the edge.
- Fixed: opening Whisper Messenger with a key binding on a letter key (like Shift-G) no longer types that letter into the message box.
- Other addons can now drop their chat links straight into your Whisper Messenger message while you're typing it. Total RP 3 needs an update on its side before its links show up there.
- Fixed: a trade or general chat line from a different player with the same name on another realm no longer shows up inside your whisper with someone.
- "Same position on every character" (Icons settings) now also keeps the messenger window, its size and the minimap button in the same place on all your characters, not just the widget. A new character opens everything where you left it. If you already had it on, the first character you log in with after updating sets the shared window spot and minimap button angle.
- New option under Icons: Widget layer. Pick Low or Background to keep your bags and the character sheet on top of the widget; High (the default) keeps the widget above them.
- With the Native WoW look, the arrows at the ends of the chat tab row now light up when you point at them.

## [2.1.5] - 2026-11-08

- New compact window, off by default: turn it on with "Compact window" under Appearance settings. The messenger button grows into the window's top-left icon and opens a tall, narrow list of your chats. Click a chat to slide into it, and use the back arrow to slide back. The button keeps your unread count the whole time, and the window opens at the button, which flies onto it. New message pop-ups stay hidden while the window is open, so they never cover its title bar.
- Closing the compact window sends the icon back to where it came from. Settings open wider while they're showing, then the window returns to compact size.
- Addons that support it (Craft Alert) now open their page inside the compact window without widening it.
- The regular (non-compact) window now grows out of its icon when it opens and shrinks back into it when it closes.
- New option under Appearance: Window animation, to turn the opening and closing animation off. With it off, the compact window's pages also switch at once instead of sliding between the chat list and a chat.
- New option under Appearance: Dock button on the window. Turn it off and the floating button stays where it is while the window is open.
- New option under Appearance: Open at saved spot (on by default). Off, the window opens at the floating button, and the button follows when you move the window (while Dock button on the window is on). On, the window opens where you last moved it and the button stays where it is.
- The regular (non-compact) window now holds the floating button in its top-left corner while it is open, like the compact window does. A square button turns into the same round corner icon while it sits on the window; its border and background settings only change the floating button. You can still click the button to close the window or drag it to move the window. New message pop-ups stay hidden while the button sits on the open window.
- In the compact window, the tabs now stay below the window while a conversation is open; tap a tab to go back to its list.
- The Export conversation window now shows the whole saved conversation at once, with a taller text box; the Show more and Show all buttons are gone.
- Clicking the floating button while a message preview is showing now opens that conversation, in both the compact and the regular window. With no preview showing, the button works as before.
- Right-clicking a player in the contact list now offers "Guild invite" when you're allowed to invite: it types the invite command into your chat box, and you press Enter to send it. When the game wouldn't let that invite go through (often until you've used a chat command such as /say since logging in), it shows the command in a small box instead, ready to copy with Ctrl+C and paste into chat. Players on your own realm are named without the realm. It's hidden for your guildmates, and (with "Show player levels" on) for players the game has shown you in another guild this session.
- The square floating button now has slightly rounded corners, and its unread glow pulses along its edge like the round button's.
- When the tabs below the window don't all fit, arrows appear at the window's edges to scroll through the rest, and the tabs squeeze together slightly so more of them fit; the mouse wheel works too. With the Native WoW HUD style, tabs now show their full names instead of being cut short.
- With the Native WoW HUD on, the message box now uses the game's newer input box look on Retail and WoW: Forever, and the quick-reply box on the message preview matches it on every version.
- Fixed: In the compact window, the title no longer runs into the buttons next to it.
- Fixed: Turning off a tab such as Requests or Channels could leave it on screen on top of another tab until a reload.
- Fixed: Dragging the button while it sits on the open window no longer makes the window jump.
- Fixed: Messages from addon chat channels (like Forever Item Finder's) and other custom channels you haven't turned on as chats no longer show up inside your whisper chats. Channels you turned on as chats, and the game's own channels like Trade, still show their latest message there.
- Fixed: With "Auto-open on outgoing whisper" turned off, a greeting sent by clicking another addon's pop-up (like Craft Alert's) no longer opens the messenger.
- Fixed: The floating button no longer stays invisible when its transparency is set high. While you have anything unread it shows fully, and it fades back to your chosen transparency once you have read them.
- Fixed: Copy Character Name in the right-click menu of a chat or a message no longer shows an error. It opens a small box with the name selected, ready to copy with Ctrl+C. In WoW: Forever it copies the name without the realm, like the game's own menu does.
- Fixed: In WoW: Forever, a Battle.net friend's character name at the top of the chat no longer ends in a long server code.
- Fixed: Typing /r and a space in the game's chat box now opens the messenger on the last whisper you received, like the reply key does. Anything you typed after /r carries over into the messenger's text box.
- Fixed: Slash commands like /roll or /dance typed in the messenger's text box now run as if you typed them in the game's chat box, instead of being sent to your contact as a whisper.
- Fixed: Closing the messenger with Escape no longer pops up a widget preview for a whisper that came in while the window was open.
- Fixed: Hiding the game's interface with Alt+Z and bringing it back no longer closes the messenger with its shrink animation. The window comes back just as you left it.
- Fixed: Clicking another player's profession link in the messenger opens their profession again instead of showing an "Interface action failed" error.
- Fixed: The square floating button now has a solid dark background behind the chat bubbles, like the round one, instead of letting the ground show through.
- Fixed: The widget's message preview closes on its timer again after you click out of its Reply box, even with text left in it (the text is kept as a draft for that chat). The timer now also waits while your mouse is over the preview, and starts over once you move away.
- Fixed: In WoW: Forever, the Export conversation window no longer opens as an empty black box. The conversation's text now shows, scrolls, and you can select all of it or just part of it to copy.
- Fixed: With "Deselect chat input after sending" on, pressing Enter in combat no longer opens the game's chat box; it puts the cursor back in the messenger while your mouse is over it. With your mouse elsewhere, Enter does nothing until the fight ends.

## [2.1.4] - 2026-11-05

- New option in Behavior settings, off by default: Deselect chat input after sending. After you send a message, the cursor leaves the text box so your keys control the game again, and Enter puts it back while the messenger is open.
- Smaller download, and the addon now uses less memory by keeping only your language loaded.
- Changing to a language that isn't loaded now asks you to reload the interface.
- The messenger button and the minimap button now share one look on every theme: a dark circle with the two chat bubbles on it, framed by a ring. The minimap button's ring is always gold; the messenger button's ring takes your theme's color, or gold if you prefer. Hovering lifts the circle a little so the bubbles stay easy to see on any theme, and the minimap button now reacts to the mouse as well.
- When there are no unread messages, only the back chat bubble turns gray, and it is brighter than before so it stands out on the dark circle. The front bubble and the circle keep their colors.
- The sender's name on the message preview next to the button is smaller, so it fits the small card better.
- New Icons setting, Widget shape: pick a round or a square messenger button on any theme, and it changes right away without a reload.
- New options in Icons settings for the messenger button: Show border and Color border with theme (the minimap button always keeps its gold ring), and Button background now works on the round widget too.
- EllesmereUI theme: the messenger button is now round like on the other themes. To get the square back, open Settings, go to Icons, and set Widget shape to Square.
- The addon's own icon, shown in the addon list, the minimap addon menu, the empty chat picture and the window portrait, now matches the new button look.

## [2.1.3] - 2026-11-04

- New EllesmereUI theme preset, shown when EllesmereUI is installed: the messenger takes on your EllesmereUI accent color, panel color and font, and follows along when you change them. Picking it with the Native WoW HUD on offers to turn the HUD off, since the HUD's frame hides most of the theme. With it, the messenger button is a square drawn like your EllesmereUI action buttons (their slot background, border, and Bar Animations hover and pushed effects) with a sharp new icon whose back bubble takes your accent color, and the minimap button uses the same icon without its extra ring. When idle, only the colored bubble turns gray. A character without EllesmereUI uses the default theme for that session and keeps the EllesmereUI theme chosen for the others. A new Icons setting, Square button background (grayed out with the other themes), hides the square to show just the two bubbles, with a thin black outline so they stand out on any ground. Hovering fills the gray bubble with your accent color, and the new-whisper pulse glows around the outline of the bubbles. With the square hidden, hovering also glows around them.
- Whisper Messenger now has an entry in the addon list button by the minimap (Retail), showing your unread count next to its name. Clicking it opens or closes the messenger, Shift-click marks everything as read, and it works even with both messenger buttons hidden.
- If something goes wrong while saving a whisper you're hiding from the game's chat, the whisper now still shows in the game's chat instead of being lost. After repeated errors, whispers stop being hidden from chat until you reload.
- When "Hide on entering combat" hides the messenger, it now opens again once combat ends, without putting your typing cursor in the message box, so your movement keys keep working. If you close it yourself during combat, it stays closed.
- Message Retention is now a menu with longer choices: keep your chats for up to 30 days, 90 days, or forever. A retention time you picked before stays as it was until you choose a new one.
- You can now export a conversation as plain text: right-click a contact (or the conversation's title) and pick Export conversation. A window in the messenger's own look shows every message with its date, time and sender, without colors or icons, selected and ready to copy with Ctrl+C. It opens with the latest 200 messages; Show more adds the 200 before them and Show all loads the rest. Close it with the X or Esc. Works for whispers, Battle.net, group and channel chats.
- New setting under Whispers: Close the game's whisper tab too (off by default). If the game opens each whisper in its own chat tab, removing a chat in the messenger now closes that player's tab as well.
- The notification sound is now picked from one dropdown instead of a grid of buttons. Besides the messenger's 16 sounds, it lists the sounds your other addons share through SharedMedia (for example from ElvUI or WeakAuras), each group under its own heading. Picking a sound plays it once so you can hear it. If you later remove the addon that provided your chosen sound, the default Whisper sound plays instead.
- Right-clicking a contact now offers Copy profile link, with the player's Raider.IO, Warcraft Logs and Armory pages (only the sites that cover your version of the game). Picking one shows the link ready to copy with Ctrl+C. It also works for a Battle.net friend while they're online in the same game version and region as you.
- Long dropdown lists, like the font and notification sound pickers, now open scrolled to your current choice instead of the top.
- Picking a shorter Message Retention now asks before deleting older chats, and so does Reset to Defaults when it would shorten it. Cancel keeps your current settings.
- The Behavior settings now show which key opens and closes the messenger, with a Set keybind button that takes you straight to Whisper Messenger in the game's Key Bindings. The button is grayed out during combat.
- Right-clicking a player in the contacts list now offers Add friend, unless they are already on your friends list.
- Right-click a Battle.net friend who is in World of Warcraft, or a guild or community member, and pick "Notify when they change zone" to get one chat message (and the whisper sound, if it is on) the next time they move to another zone. It turns itself off after that one message; going offline in between keeps it waiting.
- Automated whispers from crafting addons such as Craft Alert are now marked "Sent by Craft Alert", so you can tell them apart from a real person typing. That covers every line of a crafter's automated greeting and the whisper a customer's crafting addon sends when it picks you as their crafter. A new Whispers setting, Addon greetings, lets you show them (the default), send the conversations they start to Requests, or hide them. Hidden whispers are thrown away, not saved, and while "Hide whispers from default chat" is on you won't see them in the game's chat either.
- The messenger does less background work while closed when your Battle.net friends log in, log out, or change zones or characters.
- Fixed: Replying to your last whisper no longer opens an empty chat when that chat was deleted, cleared with Clear all chats, or removed by message history cleanup.
- Show player levels now sits at the top of the General settings page instead of Appearance. Your choice is kept.
- New option on the Whispers page: reply from the widget preview. Answer a whisper straight from the widget's message preview without opening the window.
- Show widget message preview now sits on the Whispers settings page, next to the new reply option, instead of Icons. Your choice is kept.

## [2.1.2] - 2026-10-30

- Updated for the latest World of Warcraft patch (interface 20505 → 20506).
- Other addons can now show their alerts on the messenger's widget and open a chat with a player. They can also add their own page to the messenger window, opened from a tab next to Whispers, Groups and Channels.
- The buttons along the top of the messenger window are larger and easier to hit.
- With the Native WoW HUD on, the message preview next to the messenger button now uses the game's tooltip border.
- With the Native WoW HUD on, the settings page list now shows an icon next to each page, like the other looks.
- The message preview next to the messenger button is now larger, with bigger text and more room, so item links no longer touch its border.
- Left-clicking the message preview next to the messenger button now opens that player's chat, even with the settings or another addon's page open.
- The number on the messenger button and minimap icon now also counts items waiting in addon pages (for example Craft Alert leads you haven't answered yet).
- Clicking the messenger button, minimap icon or Broker icon while only an addon page has something waiting (like a Craft Alert lead) now opens that page instead of your whispers. Unread whispers still open your whispers first.
- Notes that other addons show under a player's name in a chat can now show more detail when you hover them (for example, Craft Alert can show how a request was matched).
- New setting under Behavior: Allow addon integration. Turn it off to stop other addons (like Craft Alert) from adding pages, previews or notes to Whisper Messenger. Changing it asks to reload the interface.
- Shift-clicking the messenger button, minimap icon or Broker icon (or choosing Mark all as read) now also clears message previews from other addons, like Craft Alert, and tells them everything was marked read so they can clear their own counts.
- Other addons (like Craft Alert) can now check, add and remove players on the messenger's block list. Turning off Allow addon integration stops this too.
- Other addons (like Craft Alert) can now see which players have unread whispers, so they can highlight those players. Turning off Allow addon integration stops this too.
- Addons that add a tab to WhisperMessenger can now match its look and colour theme.
- Previews from other addons can show one extra line under the message (for example, Craft Alert can say which of your characters can craft the item). Your own whisper previews are unchanged.
- Fixed: hovering an item link in the message preview now shows the item's tooltip.
- Fixed: with the Native WoW HUD look, the message preview's background is now solid like the game's tooltips, so names and item links stay readable over bright ground.
- Fixed: a whisper from the chat you had open no longer counts as read while another addon's page or the settings cover it, so its preview and unread number show. Going back to the chat marks it read.
- Fixed: the addon no longer shows as out of date on Burning Crusade Classic Anniversary realms.
- Fixed: starting or replying to a whisper (/w, /r, or sending one from chat) while another addon's page or the settings are open in the messenger now shows that chat instead of leaving it hidden behind them. Whispers you receive still leave the page open.

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
