# Changelog


## [Unreleased]

### Added

- **"Azeroth" theme preset (native WoW look — Phase 1).** A new entry in Appearance → Theme Preset that swaps the messenger's palette to Blizzard's native UI colors: gold accents (`NORMAL_FONT_COLOR`), white primary text (`HIGHLIGHT_FONT_COLOR`), grey timestamps (`GRAY_FONT_COLOR`), green/orange/red status dots (`GREEN/ORANGE/RED_FONT_COLOR`), near-black chat surfaces, and whisper-magenta tinted outgoing bubbles.
- **Native WoW chrome auto-applies with the Azeroth preset (Phase 2A).** Selecting "Azeroth" now also paints the messenger window with Blizzard's standard frame backdrop (gold tooltip border + dark dialog inset) and switches the close button to Blizzard's `common-iconbutton-close` atlas (with `Interface\Buttons\UI-Panel-MinimizeButton-Up` fallback for Classic flavors). Switching back to any other preset clears the backdrop and restores the modern flat surface.
- **Send button + scrollbar adopt native WoW look under Azeroth (Phase 2B).** The composer's Send button now paints with Blizzard's `UI-Panel-Button-Up`/`-Down`/`-Highlight`/`-Disabled` textures (the standard WoW button look), and the scroll thumb switches to `UI-ScrollBar-Knob` (the classic Blizzard knob). Other presets keep the modern rounded pill button and slim flat-color thumb. Live preset switch requires `/reload` to pick up new send button / scrollbar paint (chrome backdrop still updates live).
- **Contact rows get Blizzard-style hover highlight under Azeroth (Phase 2C).** Hovered or selected contacts now show Blizzard's classic `UI-QuestTitleHighlight` gold gradient overlay (alpha 0.4 on hover, 0.6 on selected) on top of the existing row paint. Other presets keep the modern flat-color hover. Status dots already pick up Blizzard's standard `GREEN`/`ORANGE`/`RED_FONT_COLOR` via the Phase 1 Azeroth palette, so no extra texturing was needed.
- **Conversation header gains a 4px right margin.** The contact-name/status header (`HeaderElements.createHeaderFrame`) was anchored at `TOPRIGHT + 3` — extending 3px *beyond* the pane's right edge and letting the header touch the chrome border. Now anchored at `-4` so the header breathes back inside the pane and aligns visually with the other small right-side margins.
- **Top status bar under Azeroth gains 2px of right padding.** The `blizzardTopBarExtension` texture now anchors at `-6` (was `-4`) on the TOPRIGHT, aligning its right edge with the frame's Inset `BOTTOMRIGHT` inset so the top bar and the content area share the same right margin and the corner breathes next to the resize grip.
- **Composer container extends flush to the window's bottom-right corner.** The old 8px right-inset (and Apply.lua's 20px relayout margin) was reserving space for the resize grip, which left an awkward gap between the composer and the window edge. Removed both so the composer pane dual-anchors to `contentPane`'s right edge; the resize grip sits on the outer frame at a higher frame level and visually overlays the composer's corner without pushing the pane inward.
- **Composer container shows its subtle chrome border at runtime.** `LayoutBuilder`'s `composer_pane_border` was drawn on the parent `composerPane` and covered by the Composer's child frame, so the border was never visible. Moved the border onto the Composer's own pane (drawn on `OVERLAY` via `createBorderBox`) using the theme's `divider` color at `DIVIDER_THICKNESS` (1px) — the same faint line used by the contacts and search dividers — so it reads as consistent chrome across all presets instead of a highlighted frame. `refreshTheme` repaints the color on live preset switches.

### Fixed

- **Offline BNet friends now correctly show "Offline" in the conversation status bar.** Three converging bugs were hiding real-world offline BNet friends behind "Away", "Busy", or "Online (App)" labels: (1) `BNetAccountInfo.isAFK`/`isDND` are sticky flags that persist on the account after a friend goes offline, and `AvailabilityEnricher.EnrichContactsAvailability` was treating those flags as proof of presence (`isOnline = accountInfo.isOnline or accountInfo.isAFK or accountInfo.isDND or ...`) — presence now requires `accountInfo.isOnline == true` or game-account evidence (`gameAccountInfo.isOnline`/`characterName`), and the same sticky-flag check was removed from `BNetResolver.resolveByGUID` (different-person branch) and `BNetResolver.ResolveFriendByBattleTag` GUID fallback; (2) when `accountInfo.isOnline == nil` (API still loading or mobile user) with an explicit `offline` signal from the guild/community presence cache, the enricher was falling back to "Online (App)" instead of trusting the positive offline signal — the `nil`-branch now maps `presence=="offline"` to `Offline` and only returns `BNetOnline` when presence is genuinely unknown; (3) when `ResolveAccountInfo` returned `nil` entirely (e.g. friend removed from Battle.net list, or BNet API has no record for the stored account id), the BN branch left `item.availability` unset, so the conversation status bar showed stale / no status — a final BN-specific fallback now sets `Offline` (or `CanWhisper` if guild/community presence says online) so the status bar always reflects a concrete state. New regression tests: `tests/model/test_bnet_offline_sticky_flags.lua` covers all three paths (sticky `isAFK`/`isDND` on offline account, `isOnline=nil` with presence=offline, `accountInfo=nil` with presence=offline).
- **Messenger no longer drops behind other windows on mouse-over alone.** Previously, `OnLeave` and the idle `OnUpdate` tick would demote strata to `MEDIUM` whenever the cursor wandered off the frame — so moving the mouse onto the Auction House (or any other UI) sent the messenger to the back even if the user was still typing. Demotion is now driven exclusively by `GLOBAL_MOUSE_DOWN` clicks *outside* our frame: hovering other windows keeps us on top, but clicking into another window brings that window forward as expected. `OnMouseDown` on our own frame still promotes (and now also restores composer focus if the click would have cleared it).
- **Strata promotions/demotions no longer drop composer focus.** Clicking the messenger frame (or hovering in/out of it) triggers `SetFrameStrata` + `frame:Raise()`, which in WoW can clear a focused EditBox as a side effect. `promoteStrata` and `demoteStrataIfIdle` now wrap the strata transition in a focus-preservation helper that snapshots `composerInput:HasFocus()` before the change and calls `SetFocus` after if the composer lost focus during the transition. Typing in the composer is no longer interrupted when the window jumps forward or back.
- **"Native WoW chrome" toggle renamed to "Native WoW HUD" and no longer appears reversed.** `SettingsPanels.lua` wasn't forwarding `settingsConfig.nativeChrome` into the Appearance panel, so the toggle always initialized from `nil` — it showed OFF even after the setting had been turned ON, making repeat toggles look inverted. The config now passes `nativeChrome` through alongside the other appearance values so the toggle reflects the persisted state. Label in the Appearance panel and the `/reload` reminder now read "Native WoW HUD".
- **Contacts pane nudged 4px to the left.** `contactsPane`'s `TOPLEFT`/`BOTTOMLEFT` anchors against `frame.Inset` went from `(8, -24)` / `(5, 0)` to `(4, -24)` / `(1, 0)`, shifting the whole contact list column 4px closer to the window's left border for a tighter fit inside the chrome.
- **Conversation top header tightened to 2px padding.** `HEADER_HEIGHT` in `ConversationPane.Create`/`Relayout` and `HeaderView.Create`'s default dropped from `56` to `36` (32px class-icon + 2px top/bottom breathing room), and `HeaderElements.createContactName` now anchors the contact name at `TOPLEFT (58, -2)` (was `-12`). The header no longer dominates the pane — more vertical space goes to the transcript.
- **Contacts list and conversation top status bar shifted 8px upward.** `contactsPane`'s top anchor against `frame.Inset` went from `(2, -28)` to `(2, -20)` and its bottom anchor from `(3, 0)` to `(3, 6)` — a net 8px top shift with the bottom raised just 6px so the contacts list reaches 2px further into the chrome footer. `contentPane`'s `BOTTOMRIGHT` against the Inset moved from `(-5, 5)` to `(-5, 10)` (mirrored in `LayoutBuilder/Apply.lua` so relayouts preserve the shift). The whole content area rises, no overflow past the chrome bottom, and the composer rides up with the content.
- **Composer input now keeps its right padding after window resize.** `Composer.relayout` was computing the input/inputBg width from the caller's content-width hint, but the composer pane itself is narrower than that (by 20px in tests, 8px in production WoW) due to its `BOTTOMRIGHT` anchor offset. On resize the input overflowed past the pane's right edge, eating the gap to the Send button. `relayout` now self-measures its own pane's live width (falling back to the passed hint only if unavailable) so the input always stays inside the padded area.
- **Send button no longer keeps the Blizzard texture after switching away from Azeroth.** `Composer.refreshTheme` now re-evaluates the active skin and clears (or re-applies) the native button textures, so live preset switches return the button to the modern rounded pill without requiring `/reload`.
- **Scroll thumb no longer shows in panes that don't need scrolling under Azeroth.** `Navigation.Sync` now hides the thumb explicitly alongside the scrollBar (the textured Blizzard knob was leaking through the parent hide). Modern slim thumb is unaffected.
- **Scroll thumb texture now updates live on preset switch.** `ScrollView` exposes a `refreshSkin()` that `ConversationPane.refreshTheme` calls so the transcript scrollbar can swap thumb paint without requiring `/reload`. Contact rows already pick up new skin paint via the existing `runtime.refreshWindow()` rebind on preset change.

### Polished (Azeroth tuning from in-game screenshot review)

- **Uniform near-black surface under Azeroth.** Equalized `surface_primary`/`surface_secondary`/`surface_chrome` to the same opaque `(0.04, 0.04, 0.06, 1.0)` so the contacts list and conversation pane stop looking two-tone, and the right-edge bleed-through of background WoW UI is gone.
- **Visible gold trim on the messenger frame.** ~~Swapped the backdrop edge file to `DialogFrame\UI-DialogBox-Border` at edgeSize 32~~ — reverted in the same release. The fatter edge zone covered the "WM" title text and rendered as half-visible borders against the inset bg. Backdrop stays at the safer `UI-Tooltip-Border` / edgeSize 16 / insets 4 — a more subtle gold trim that doesn't break layout. Will revisit with a different approach (e.g. manual gold overlay textures) in a future release.
- **Close button (`common-iconbutton-close` atlas) reverted to `UI-StopButton`.** The atlas rendered blank on some clients, leaving the X invisible. The original modern X is reliable across all flavors.
- **Incoming whisper bubble brightened under Azeroth.** `bg_bubble_in` was `(0.08, 0.08, 0.10)` — almost indistinguishable from the now-opaque near-black surface. Changed to `(0.18, 0.20, 0.26, 1.0)` slate gray with a cool tint so incoming messages clearly stand out from the surface.
- **Contacts pane and conversation area paint with the Blizzard inset texture under Azeroth.** New `pane_inset_texture` skin field (`Interface\DialogFrame\UI-DialogBox-Background-Dark`, same as the window backdrop bgFile) is painted on `chrome.background` and `contactsPaneBg` via a new `UIHelpers.applyPaneBackground` helper. Modern presets continue to paint flat color via `applyColorTexture`. Live preset switch swaps between texture and color paint cleanly via `chrome.applyTheme` and `LayoutThemeApply.applyTheme` (both already wired to fire on `themePreset` change).
- **Send button stays as the modern rounded pill under all presets.** The native `UI-Panel-Button-*` textures didn't fit the composer layout cleanly (cramped at the small button footprint, awkward when widened to native ratios). The rounded pill — which already picks up the gold accent color via the Azeroth palette — gives the button the right feel without forcing native textures. Stage 2B's `Composer.refreshSkin` machinery and `applySendSkin` helper were removed; the send button no longer participates in skin-aware paint.
- **Dropped the classic scrollbar knob texture under Azeroth.** `UI-ScrollBar-Knob` is designed for ~16px-wide native scrollbars; in our 4px slim slider it rendered as a thin yellow stripe rather than a knob. Modern Blizzard UI (12.0) uses `MinimalScrollBar` which is closer to our slim color thumb anyway, so the gold-tinted scrollbar palette from Phase 1 carries the look on its own.
- **Option checkbox unchecked state is now clearly dim under Draenor and Azeroth.** Both presets previously defined `option_toggle_border` in the same hue/brightness as `option_toggle_on` (light tan for Draenor, full gold for Azeroth). The 14px dot was dominated by the bright rim when unchecked, reading almost identical to the fully-filled checked state. Borders are now muted dark tones (`(0.42, 0.32, 0.24, 0.75)` warm brown for Draenor, `(0.40, 0.32, 0.10, 0.70)` dim gold for Azeroth) so unchecked toggles read as off at a glance.
- **Composer container border is now visible under Shadowlands and Azeroth.** The composer pane's border was painted with the shared `divider` token, which rendered too close to the surface behind it under Shadowlands (near-black divider on near-black bg) and Azeroth (dim gold on a textured Blizzard dialog backdrop). Introduced a dedicated `composer_pane_border` theme token: Midnight and Draenor keep their existing edge (`(0.15, 0.16, 0.22, 1.0)` / `(0.42, 0.29, 0.20, 1.0)`), Shadowlands gets a brighter slate (`(0.48, 0.50, 0.58, 1.0)`), and Azeroth gets a brighter muted gold (`(0.62, 0.50, 0.16, 1.0)`). `LayoutBuilder` and `LayoutBuilder.ThemeApply` now read this token (falling back to `strongDividerThemeColor`), so the composer rectangle reads as a distinct container in every theme without affecting other dividers in the window.


## [1.1.7] - 2026-04-16

### Added

- **"Double ESC to close" behavior toggle.** New setting under Behavior (default: off). When on, the first ESC press clears focus from the chat input and the second ESC closes the window (via the standard `UISpecialFrames` path). When off, ESC closes the window immediately as before.

### Changed

- **Messenger window now drops behind other active windows when it loses focus, and jumps to the front when you interact with it.** The idle strata is now `MEDIUM` (matching Blizzard's default UI panels). Clicking anywhere on the messenger frame promotes it to `HIGH` so it sits above other active windows. When the mouse leaves the window and the composer input has no keyboard focus, strata drops back to `MEDIUM` automatically. Tooltips, popups, and dialogs (which use higher strata) continue to layer above it as expected.

### Fixed

- **Contact statuses now refresh when you open the messenger or click a contact.** Previously, availability (CanWhisper / Offline / WrongFaction / Away / Busy) only updated after you sent a whisper — opening the window or selecting a contact fired the request but never re-rendered when the async response arrived. Status responses now trigger a debounced window refresh when they actually change a contact's state, so the list updates live.
- **Contact statuses stay fresh while the window is open.** A 30-second background refresh ticks while the messenger is visible and cancels when you close it. Each WoW contact is re-queried at most once every 10 seconds to avoid API thrash. BNet contacts keep their existing push-event path (`BN_FRIEND_INFO_CHANGED`).
- **Same-faction cross-realm contacts no longer show "Unavailable" when they're actually reachable.** The WoW whisper-availability API returns "WrongFaction" as a generic cross-realm/unreachable signal for same-faction players too. When we have no corroborating presence data (not in guild/community/party/BNet), the contact now defaults to online/CanWhisper instead of a grey "Unavailable" state — whispers will still reach them.
- **Opposite-faction contacts no longer show as "Offline" when the API response is ambiguous.** When the API returns "Offline" for a known opposite-faction contact and we can't confirm online/offline via guild or community presence, the status now shows "WrongFaction" (the real reason you can't whisper them), not "Offline".
- **Channel context (/1, /2, etc.) no longer disappears when switching characters.** Per-channel "last message" snapshots (used by contact rows and conversation context) are now stored at the account level instead of keyed by character profile. Legacy per-profile data is flattened on load — the newest entry per sender wins.


## [1.1.6] - 2026-04-16

### Added

- **Midnight (12.0) `C_RestrictedActions` integration.** Subscribes to `ADDON_RESTRICTION_STATE_CHANGED` and caches state from the event payload. Drives the competitive-content gate on 12.0+, with full fallback to `InCombatLockdown` / `IsEncounterInProgress` / `C_ChallengeMode.IsChallengeModeActive` on 11.x clients.
- **`/wr` and `/wreply` slash commands.** Taint-safe replacement for Blizzard's `/r` during or after Mythic+. Opens the messenger focused on your most recent incoming whisper. Bypasses `ChatEdit_SetLastTellTarget` / `GetLastTellTarget` so it works even after Blizzard's `chatEditLastTell` has been tainted by a during-M+ secret-string sender.
- **Automatic R-key override when "Hide whispers from default chat" is on.** A hidden `SecureActionButton` fires `/wr` so the R key uses our messenger reply instead of Blizzard's tainted `ReplyTell`. Toggling the setting off restores the original binding.
- **Whisper actions route to the messenger.** Right-click "Whisper", `/w name`, and reply actions (`/r`, R-key) now open the messenger window instead of the default chat editbox. During Mythic+ or encounter lockdown, the action is queued and delivered when lockdown clears.

### Changed

- **Reverted v1.1.5 taint-guard and deferred-replay rework.** Blizzard's chat-secrecy API blocks whispers from reaching any addon while chat is locked — the replay scaffolding could never see the messages it was trying to recover. The addon is back to v1.1.4 behavior during encounters: whispers fall through to the default chat frame, and the messenger shows a "Whispers paused" banner until the fight or run ends.
- **Mythic raid lockdown switched to encounter-based detection.** The lock indicator and "Whispers paused" banner now trigger only during actual boss encounters in Mythic raids, not for the entire instance.

### Fixed

- **Enter and post-Mythic+ `/r` crashed on `UpdateHeader` arithmetic.** Link-hook overrides (`ChatEdit_GetActiveWindow`, `ChatEdit_InsertLink`) were installed at module-load time, permanently tainting Blizzard's secure call stack. Overrides now install only while the composer input has focus and restore originals on focus-lost.
- **`/r` and R-keybind crash during encounters with "Hide whispers from default chat" enabled.** Chat filter registration via raw `ChatFrame_AddMessageEventFilter` tainted Blizzard's filter dispatch table. Fixed by routing all register/unregister calls through `securecall`.
- **Stale reply target after leaving Mythic+.** Cached `lastIncomingWhisperKey` was pre-M+ stale and could misroute a post-M+ `/r`. Resume now clears it.
- **Taint from deferred edit-box cleanup during encounters.** `C_Timer.After(0, …)` callbacks now re-check `isCompetitiveContent` before touching secure state.
- **OnUpdate poller reading Blizzard edit boxes during competitive content.** Hard-bail moved to the top of the handler to prevent taint propagation.
- **Removed `hooksecurefunc` on `ChatFrame_ReplyTell` / `ChatFrame_ReplyTell2`.** WoW attributed taint crashes to WhisperMessenger for merely having a hook attached, even when our suffix never executed.
- **Bare Enter hijacking default chat.** Pressing Enter without a whisper target no longer opens the messenger.
- **Invalid edit-box state when sticky channel was whisper.** The auto-open coordinator no longer plants state on Blizzard's editbox when the sticky type is already set to whisper.
- **Messenger window not refreshing on encounter transitions.** The window now updates immediately on `ENCOUNTER_START` / `ENCOUNTER_END`.
- **Empty-string compare on tainted `playerName` during Mythic+.**
- **Key input leaking into composer from whisper-routing hooks.**

### Known limitations

- **`/r` and R-key are incompatible with "Hide whispers from default chat" in Midnight (12.0).** The chat filter closure taints `SetLastTellTarget` on Blizzard's event-dispatch stack; there is no taint-safe alternative. Use `/wr` (or bind `/wr` to R via macro) instead. On entering Mythic+ with the setting enabled, the addon prints a one-time reminder.
- **Shift-click-from-quest-log into the messenger composer only works while the composer is focused.** The module-load override is no longer taint-safe on 12.0. Click inside the composer first, then shift-click. Chat-bubble link clicks continue to work regardless of focus.


## [1.1.5] - 2026-04-08

> Rolled back in v1.1.6 — see the v1.1.6 entry above. The items listed here shipped briefly before testing confirmed that Blizzard's chat-secrecy API blocks whispers from ever reaching addons while chat is locked, making the deferred-replay rework unable to do its job.

### Added

- **Whispers no longer lost during Mythic+** — whispers that arrive while you're inside a Mythic+ keystone (or any other content where Blizzard locks down chat) are now held safely in the background and delivered to your messenger the moment you finish the run. Previously these messages were dropped entirely.
- **Smarter lockdown detection** — the messenger now asks the game directly whether chat is locked instead of guessing from the content type. The "chat paused" banner and the lock indicator now trigger correctly across every situation Blizzard restricts whispers in, not just Mythic+ keystones and Mythic raids.

### Fixed

- **Lock indicator wrongly showing in normal raids** — fixed the "Whispers paused" banner and the lock icon appearing on every boss pull in LFR, Normal, and Heroic raids. The messenger now only shows the lock indicator in content where the game actually restricts whispers.
- **Item / quest / spell links going into the messenger when it isn't focused** — fixed shift-clicking items, quest log links, and chat-bubble link clicks being silently captured by the messenger composer even when its input wasn't the focused widget. Links now only insert into the composer when the messenger input has keyboard focus, matching how Blizzard's default chat editbox behaves.
- **Mythic+ taint error** — fixed `attempt to compare ... a secret string value tainted by 'WhisperMessenger'` spam from `ChannelMessageStore` while inside Mythic+ keystones.
- **Stuck "Competitive Mode" after Mythic+** — fixed the toggle-icon lock indicator and the "Whispers paused in competitive content" banner remaining stuck after returning to a capital city from a Mythic+ run.


## [1.1.4] - 2026-04-07

### Added

- **Timestamp format customization** — new "Time Format" selector in General settings lets you switch between 12-hour (2:30 PM) and 24-hour (14:30) time display in chat bubbles.
- **Local / Server time source** — new "Time Source" selector in General settings lets you choose between your computer's local clock and the game server's clock for all timestamps, including chat bubble times, date separators, and contact preview times.
- **Separate auto-open controls** — the single "Auto-open on whisper" toggle has been split into two independent toggles in Behavior settings: "Auto-open on incoming whisper" and "Auto-open on outgoing whisper", so you can control each direction separately.
- **Scroll to latest on open** — the messenger now scrolls to the most recent message when opened. Controllable via a "Scroll to latest on open" toggle in Behavior settings (enabled by default).

## [1.1.3] - 2026-04-06

### Added

- **Font customization** — new controls in Appearance settings for font size (9–17px slider), font outline (None / Outline / Thick), chat font color (Default, Gold, Blue, Green, Purple, Rose), and a Morpheus fantasy font option alongside Default and System.
- **Icon size customization** — new slider in Notification settings lets you resize the toggle icon from 24px to 64px.
- **Icon desaturation** — the toggle icon is now greyed-out by default and colorizes when you have unread whispers, making notification state visible at a glance. Controlled via a "Desaturate icon when idle" toggle in Notification settings.
- **Bubble color presets** — new "Bubble Colors" selector in Appearance settings lets you customize chat bubble colors independently of the theme. Choose from Default (follows theme), Shadow, Ember, Arcane, Frost, or Fel. Switching back to Default restores the active theme's bubble colors.
- **Competitive content indicator** — a lock icon now appears on the toggle icon when you're in competitive content (M+ keystones, battlegrounds, arenas, or boss encounters). Sending is blocked with a visible notice banner in the messenger (like M+ lockdown), and whispers fall back to the default WoW chat frame so you never miss a message. The tooltip also shows "Chat unavailable — in competitive content" so you know at a glance why messaging is paused.
- **Censored message reveal** — Blizzard-censored whispers now show a "(click to reveal)" indicator on the chat bubble. Left-click to uncensor the message directly in the messenger, even when the default chat is hidden.
- **Start New Whisper** button in the empty conversation pane — when no conversation is selected, a "Start New Whisper" button appears below the prompt text so you can begin a conversation without scrolling to the header.

### Fixed

- Unread badge size and position adjusted for better alignment.
- Title color now updates correctly across theme changes.
- Fixed a parameter name bug in channel event registration.
- Fixed scrollbar jumping when hovering or dragging in the message list.
- Removed unused `Theme` import in competitive content indicator.

## [1.1.2] - 2026-04-05

### Added

- Clickable URL detection in chat bubbles and transcript text for plain `http://`, `https://`, and `www.` links.

- New **Start New Whisper** header action next to `WM` opens a player-name prompt so you can start or jump to a whisper conversation without typing `/w`.
- Start-conversation and manual-copy dialogs now share the same messenger popup styling, including a wider near full-width input field for easier text entry.
- **Channel message context** — when opening a conversation, the contact's most recent message from public channels (Trade, General, LFG, etc.) now appears as a chat bubble with a gold "· via Trade" tag, so you know why you're whispering them.

### Fixed

- URL hyperlink clicks no longer trigger protected-function taint errors (`ADDON_ACTION_FORBIDDEN`).
- URL clicks now use a safe copy fallback flow (clipboard or manual copy dialog) in WoW addon context.

## [1.1.1] - 2026-04-01

### Fixed

- Pinned chats now keep their history while pinned (still capped by your max messages per contact setting).
- Unpinned chats now immediately follow your retention settings.
- Shift-click links now insert into WhisperMessenger only when its window is open. If the window is closed, WoW does the default action.
- Outgoing whispers are now properly hidden from default chat when "Hide whispers from default chat" is enabled.
- Reply (/r) now works reliably with "Hide whispers from default chat" enabled.
- Fixed a whisper-filter taint error (`secret string value`).
- "Hide whispers from default chat" now auto-disables in battlegrounds, arenas, and rated PvP.
- Fixed a race where pressing Enter, then quickly pressing Esc, could reopen the window when the delayed outgoing whisper event arrived.

### Improved

- Auto-open detection is more reliable for reply, right-click whisper, and name-click whisper.
- Incoming whispers no longer steal focus when you already have the messenger open on an active conversation.
- Draft text in the whisper edit box is now preserved across combat transitions.
- Contacts row interactions are cleaner: better action-button visibility, hover-pointer behavior, and spacing.

## [1.1.0] - 2026-04-01

- Added runtime-switchable theme presets in Appearance settings, including Midnight, Shadowlands, and Draenor.
- Improved the messenger's visual polish with stronger section framing, clearer settings toggles, and distinct accent identities for each preset.
- Improved theme consistency by reducing redundant theme tokens, pruning dead preset colors, and making preset changes repaint search/input/settings surfaces immediately.
- Fixed theme startup and preset application issues so the addon loads cleanly and live theme changes update the window reliably.
- Added full Classic compatibility — the addon now runs on Classic Era, Season of Discovery, TBC Classic Anniversary, Cata Classic, and MoP Classic in addition to Retail.
- Fixed a crash caused by the removed UIDropDownMenuTemplate on Retail 10.0+ clients.

## [1.0.10] - 2026-03-31

- Added contacts-list search with live filtering across character names and message history, plus an inline clear (X) action to reset results.
- Improved UI contrast and added deferred window resize with a ghost preview (stable positioning + smooth commit on release) for lag-free resizing.

- Added right-click chat-bubble context menu actions with **Copy Text** support.
- Improved chat-bubble copy flow with safer clipboard fallbacks and a messenger-styled manual copy dialog that pre-fills and highlights message text when direct clipboard APIs are unavailable.

## [1.0.9] - 2026-03-31

- Added independent contacts-pane resizing with persisted width, plus compact spacing/truncation fixes to prevent overlap in narrow layouts.
- Added native right-click contact context menu support in the contacts list, so contact rows now open the standard WoW player menu (including entries added by other addons).

## [1.0.8] - 2026-03-30

### Added

- Auto-open window on incoming whisper, right-click "Whisper", click-on-name whisper, or BNet friend whisper — configurable in Behavior settings, disabled during combat
- Notification sounds now play even when in-game audio is muted
- Choose from five notification sounds: Whisper, Ping, Chime, Bell, or Raid Warning

### Fixed

- Whisper messages received during combat were queued and never stored — they now record immediately
- Shift-clicking quests, achievements, spells, and professions now correctly links them into the messenger chat instead of triggering the default action (tracking, inspecting, etc.)

### Improved

- Settings toggles now show helpful descriptions on hover, starting with the auto-focus option

## [1.0.7] - 2026-03-29

### Added

- Font family selector in Appearance settings — choose between Default (Friz Quadrata), System (Arial Narrow), or Custom (inherits fonts from addons like ElvUI)

### Improved

- Large behind-the-scenes cleanup to make the messenger feel more consistent and easier to maintain going forward
- Contact details now stay in sync more reliably, especially when Battle.net friend details change while the addon is open
- Scrolling is now more consistent in long contact lists and long conversations
- Message headers and chat bubbles now line up more consistently

### Fixed

- Fixed cases where contact details could lag behind until the window was reopened
- Fixed inconsistent spacing between sender names and chat bubbles
- Fixed refresh behavior so unread counts and contact updates stay accurate even while the window is hidden
- Fixed Mythic content confusion by showing an in-window pause notice and disabling the send box until whispers are available again
- Fixed a Classic startup error caused by unsupported whisper-related events, so the addon now loads cleanly on clients that do not provide them
- Fixed drag-resizing the messenger window beyond the screen bounds so it no longer snaps to an unrecoverable fullscreen size or requires deleting SavedVariables to recover

## [1.0.6] - 2026-03-27

### Added

- Profanity filter toggle in Behavior settings — enable or disable WoW's built-in profanity filter directly from the messenger without opening game options

### Fixed

- Fixed lint warnings for unused variables in whisper chat filter tests and link hooks

## [1.0.5] - 2026-03-27

### Improved

- Mythic content suspension is now much more robust — the addon cleanly suspends all activity when you enter a Mythic+ dungeon or Mythic raid, and fully resumes when you leave
- Added support for abandoned or depleted keystones — the addon now correctly resumes if your group leaves a key early
- You will now see a chat message when the addon suspends and resumes for mythic content, so you always know the current state
- Contact list and presence lookups are paused during mythic content to avoid unnecessary background work

### Fixed

- Fixed an issue where whispering from guild or community rosters could break the chat input during mythic content
- Fixed a rare issue where the reply target (/r) could become corrupted after receiving a whisper with "Hide from default chat" enabled
- Fixed the addon not resuming properly if a mythic keystone was abandoned or depleted without completing
- Fixed the addon sometimes not resuming after leaving a mythic dungeon — zone transitions now reliably detect when you are no longer in mythic content

## [1.0.4] - 2026-03-27

### Fixed

- Fix sending whispers during combat — sends are now blocked with a friendly status message instead of causing an error
- Fix occasional crashes with player names during mythic lockdown
- Fix rare crash in faction detection during mythic content
- Prevent broken conversations from appearing when receiving whispers during restricted content

### Added

- Automatic mythic content suspension — the addon fully disables itself in Mythic+ dungeons and Mythic raids. Your window auto-hides and restores when you leave. Whispers fall through to the default chat frame during this time.
- "Hide whispers from default chat" toggle in Behavior settings — disable to show whispers in both WhisperMessenger and the default chat frame (defaults to off)

## [0.1.0] - 2025-01-01

### Added

- Messenger-style whisper UI window
- Contact list with online status and unread badges
- Conversation pane with chat bubbles and date separators
- Composer with whisper and BNet sending
- Toggle icon with unread badge
- Settings panels (General, Appearance, Behavior, Notifications)
- Message retention and conversation age limits
- Drag-to-reorder contacts
- BNet friend resolution
- SavedVariables persistence with migrations
