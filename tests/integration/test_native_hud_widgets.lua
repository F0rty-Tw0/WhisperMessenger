local MessengerWindow = require("WhisperMessenger.UI.MessengerWindow")
local Hud = require("WhisperMessenger.UI.Theme.Hud")
local Theme = require("WhisperMessenger.UI.Theme")
local ComposerSurface = require("WhisperMessenger.UI.Composer.ComposerSurface")
local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local RetailHud = require("tests.helpers.retail_hud")
local TabToggle = require("WhisperMessenger.UI.ContactsList.TabToggle")
local RowHoverOverlay = require("WhisperMessenger.UI.ContactsList.RowHoverOverlay")

local SCROLL_KNOB = "Interface\\Buttons\\UI-ScrollBar-Knob"
local ICON_GLOW = "Interface\\Buttons\\UI-Common-MouseHilight"
local SIZE_GRABBER = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up"

local function bottomAnchorY(scrollFrame)
  for i = #(scrollFrame.points or {}), 1, -1 do
    if scrollFrame.points[i][1] == "BOTTOMRIGHT" then
      return scrollFrame.points[i][5]
    end
  end
  return nil
end

local function buildWindow(nativeChrome, withMessage, style)
  Hud.Configure(style or (nativeChrome and "classic" or "off"))
  local factory = FakeUI.NewFactory()
  local savedUIParent = _G.UIParent
  _G.UIParent = factory.CreateFrame("Frame", "UIParent", nil)
  _G.UIParent:SetSize(1280, 720)
  local contact = { conversationKey = "me::WOW::jaina", displayName = "Jaina", channel = "WOW" }
  local window = MessengerWindow.Create(factory, {
    contacts = withMessage and { contact } or {},
    selectedContact = withMessage and contact or nil,
    conversation = withMessage and { displayName = "Jaina", messages = { { direction = "in", kind = "user", text = "hi" } } } or nil,
    -- The window follows the session's HUD style; the saved legacy flag is
    -- set to the opposite to prove it is not what decides the chrome.
    settingsConfig = { showGroupChats = true, nativeChrome = not nativeChrome },
  })
  Hud.Configure("off")
  _G.UIParent = savedUIParent
  return window
end

local function hasNativeInputBorder(composer)
  return FindUI.find(composer.input, function(node)
    return node.texturePath == ComposerSurface.NATIVE_BORDER_TEXTURE
  end) ~= nil
end

local function bubbleBackdrop(window)
  return FindUI.find(window.frame, function(node)
    return node._textFS ~= nil and node._nativeBackdrop ~= nil
  end)
end

local function hasBubble(window)
  return FindUI.find(window.frame, function(node)
    return node._textFS ~= nil and node._textFS.text == "hi"
  end) ~= nil
end

local function hasTemplate(window, template)
  return FindUI.find(window.frame, function(node)
    return node.template == template
  end) ~= nil
end

local function emptyStateButton(window)
  return FindUI.ofType(window.conversation.headerEmpty, "Button")[1]
end

local function hasTexture(root, path)
  return FindUI.find(root, function(node)
    return node.texturePath == path
  end) ~= nil
end

local function hasSizeGrabber(window)
  return FindUI.find(window.frame, function(node)
    return node.normalTexture == SIZE_GRABBER
  end) ~= nil
end

return function()
  -- test_hud_window_swaps_every_widget_to_blizzard_templates
  do
    local window = buildWindow(true)
    assert(window.contactsSearchInput.template == "SearchBoxTemplate", "HUD window: search box")
    assert(FindUI.ofType(window.tabToggle.frame, "Button")[1].template == "PanelTabButtonTemplate", "HUD window: tabs")
    assert(hasNativeInputBorder(window.composer), "HUD window: composer input border art")
    assert(emptyStateButton(window).template == "UIPanelButtonTemplate", "HUD window: Start New Whisper button")
    assert(window.resetWindowButton.template == "UIPanelButtonTemplate", "HUD window: Reset Window button")
    assert(window.clearAllChatsButton.template == "UIPanelButtonTemplate", "HUD window: Clear All Chats button")
    assert(window.composer.emojiPicker.frame.template == "TooltipBackdropTemplate", "HUD window: emoji picker panel")
    assert(hasTemplate(window, "UICheckButtonTemplate"), "HUD window: options toggles are checkboxes")
    assert(hasTemplate(window, "OptionsSliderTemplate"), "HUD window: options sliders are Blizzard sliders")
    assert(FindUI.selectorButtons(window.frame, "Time Format")[1].template == "UIPanelButtonTemplate", "HUD window: choice buttons")
    local tabPoint = window.tabToggle.frame.points[1]
    assert(tabPoint[2] == window.frame and tabPoint[3] == "BOTTOMLEFT", "HUD window: tabs hang below the window")
    local listBottom = bottomAnchorY(window.contacts.scrollFrame)
    assert(listBottom == Theme.LAYOUT.HUD_PANEL_PADDING, "HUD window: list stops above the panel border, got " .. tostring(listBottom))
    assert(select(4, window.frame:GetClampRectInsets()) == -(TabToggle.NATIVE_HEIGHT - 2), "HUD window: clamp keeps the tabs on screen")
    window.refreshTheme()
    window.refreshLanguage()
    assert(
      window.conversation.transcript.scrollBar.thumb.texturePath == SCROLL_KNOB,
      "HUD window: transcript scrollbar keeps the knob after a theme refresh"
    )
    assert(hasTexture(window.composer.sendButton, ICON_GLOW), "HUD window: send button hovers with the Blizzard glow")
    assert(hasSizeGrabber(window), "HUD window: resize corner is the chat frame size grabber")
  end

  -- test_modern_window_keeps_custom_widgets
  do
    local window = buildWindow(false)
    assert(window.contactsSearchInput.template == nil, "modern window: search box")
    assert(FindUI.ofType(window.tabToggle.frame, "Button")[1].template == nil, "modern window: tabs")
    assert(not hasNativeInputBorder(window.composer), "modern window: composer")
    assert(emptyStateButton(window).template == nil, "modern window: Start New Whisper button")
    assert(window.resetWindowButton.template == nil, "modern window: Reset Window button")
    assert(window.composer.emojiPicker.frame.template == nil, "modern window: emoji picker panel")
    assert(not hasTemplate(window, "UICheckButtonTemplate"), "modern window: options toggles stay switches")
    assert(not hasTemplate(window, "OptionsSliderTemplate"), "modern window: options sliders keep the custom skin")
    assert(FindUI.selectorButtons(window.frame, "Time Format")[1].template == nil, "modern window: choice buttons")
    assert(window.conversation.transcript.scrollBar.thumb.texturePath == nil, "modern window: transcript scrollbar stays a flat bar")
    assert(not hasTexture(window.composer.sendButton, ICON_GLOW), "modern window: send button keeps the hover circle")
    assert(not hasSizeGrabber(window), "modern window: resize corner keeps the dotted grip")
  end

  -- test_hud_window_bubbles_sit_on_the_tooltip_border
  do
    local window = buildWindow(true, true)
    assert(bubbleBackdrop(window) ~= nil, "HUD window: chat bubble tooltip border")
    local row = window.contacts.rows[1]
    assert(row.selectionFill.texturePath == RowHoverOverlay.SELECTED_ART, "HUD window: selected contact uses the quest log highlight")
    assert(row.accentBar == nil, "HUD window: selected contact has no accent bar")
  end

  -- test_modern_window_bubbles_keep_the_rounded_fill
  do
    local window = buildWindow(false, true)
    assert(hasBubble(window), "modern window: chat bubble rendered")
    assert(bubbleBackdrop(window) == nil, "modern window: chat bubble has no tooltip border")
    local row = window.contacts.rows[1]
    assert(row.selectionFill.texturePath == nil, "modern window: selected contact keeps the gradient fill")
    assert(row.accentBar.shown == true, "modern window: selected contact shows the accent bar")
  end

  -- test_retail_window_uses_the_button_frame_template
  RetailHud.With(function()
    local window = buildWindow(true, false, "retail")
    local frame = window.frame
    assert(frame.template == "ButtonFrameTemplate", "Retail window: frame template, got " .. tostring(frame.template))
    assert(frame.contentArea ~= nil, "Retail window: content area")
    assert(window.contactsPane.parent == frame.contentArea, "Retail window: contacts pane in the content area")
    assert(window.contentPane.parent == frame.contentArea, "Retail window: conversation pane in the content area")
    assert(frame.contactsInset.points[1][2] == window.contactsPane, "Retail window: contacts inset follows the contacts pane")
    assert(frame.Inset.points[1][2] == window.contentPane, "Retail window: template inset follows the conversation pane")
    assert(window.contactsSearchInput.template == "SearchBoxTemplate", "Retail window: keeps the HUD search box")
    window.refreshTheme()
    local transcriptTrack = window.conversation.transcript.scrollBar.track
    assert(
      transcriptTrack.atlas == "!minimal-scrollbar-track-middle",
      "Retail window: transcript scrollbar is the minimal scrollbar after a theme refresh"
    )
    local privacyLabel = assert(FindUI.text(window.generalSettings.frame, "Privacy"), "Retail window: Privacy section label")
    assert(privacyLabel.points[1][2].atlas == "UI-Character-Info-Title", "Retail window: settings sections sit on the character-info banner")
  end)
end
