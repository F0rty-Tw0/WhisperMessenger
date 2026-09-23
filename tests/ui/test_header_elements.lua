local FakeUI = require("tests.helpers.fake_ui")
local HeaderElements = require("WhisperMessenger.UI.ConversationPane.HeaderElements")
local Theme = require("WhisperMessenger.UI.Theme")
local FindUI = require("tests.helpers.find_ui")

local function findNewWhisperButton(emptyState)
  for _, child in ipairs(emptyState.children) do
    if child.frameType == "Button" then
      return child
    end
  end
  return nil
end

return function()
  local factory = FakeUI.NewFactory()
  local pane = factory.CreateFrame("Frame", nil, nil)
  pane:SetSize(600, 420)

  -- test_create_header_frame_returns_frame
  do
    local HEADER_HEIGHT = 56
    local headerFrame = HeaderElements.createHeaderFrame(factory, pane, HEADER_HEIGHT)
    assert(headerFrame ~= nil, "createHeaderFrame should return a frame")
    assert(headerFrame.height == HEADER_HEIGHT, "headerFrame should have correct height, got: " .. tostring(headerFrame.height))
  end

  -- test_create_class_icon_with_known_class
  do
    local headerFrame = HeaderElements.createHeaderFrame(factory, pane, 56)
    local contact = { classTag = "WARRIOR", displayName = "Arthas" }
    local result = HeaderElements.createClassIcon(factory, headerFrame, contact)
    assert(result ~= nil, "createClassIcon should return a result table")
    assert(result.frame ~= nil, "result should have a frame")
    assert(result.texture ~= nil, "result should have a texture")
    assert(result.texture.texturePath ~= nil, "texture should have a path set for known class")
  end

  -- test_create_class_icon_without_class_uses_bnet
  do
    local headerFrame = HeaderElements.createHeaderFrame(factory, pane, 56)
    local result = HeaderElements.createClassIcon(factory, headerFrame, nil)
    assert(result ~= nil, "createClassIcon should return a result table for nil contact")
    assert(result.texture ~= nil, "result should have a texture")
    -- With no classTag, should fall back to bnet_icon
    assert(result.texture.texturePath ~= nil, "texture should have a fallback bnet_icon path")
  end

  -- test_create_status_dot_returns_frame
  do
    local headerFrame = HeaderElements.createHeaderFrame(factory, pane, 56)
    local contact = { displayName = "Arthas", classTag = "WARRIOR" }
    local iconResult = HeaderElements.createClassIcon(factory, headerFrame, contact)
    local statusDot = HeaderElements.createStatusDot(factory, headerFrame, iconResult.frame, contact)
    assert(statusDot ~= nil, "createStatusDot should return a frame")
    assert(statusDot.bg ~= nil, "statusDot should have a bg texture")
    assert(statusDot.shown == true, "statusDot should be shown when contact is provided")
  end

  -- test_create_empty_state_shown_when_no_contact
  do
    local emptyState = HeaderElements.createEmptyState(pane, nil, factory)
    assert(emptyState ~= nil, "createEmptyState should return a frame")
    assert(emptyState.shown == true, "emptyState should be shown when contact is nil")
  end

  -- test_create_empty_state_has_new_whisper_button
  do
    _G.StaticPopupDialogs = {}
    _G.StaticPopup_Show = function() end
    local emptyState = HeaderElements.createEmptyState(pane, nil, factory)
    local btn = assert(findNewWhisperButton(emptyState), "emptyState should have a new whisper button")
    assert(btn.shown == true, "newWhisperButton should be shown when no contact selected")
  end

  -- test_create_empty_state_hidden_when_contact_selected
  do
    local contact = { displayName = "Arthas", classTag = "WARRIOR" }
    local emptyState = HeaderElements.createEmptyState(pane, contact, factory)
    assert(emptyState.shown == false, "emptyState should be hidden when contact is selected")
  end

  -- test_create_empty_state_button_triggers_start_conversation_popup
  do
    local popupShown = nil
    _G.StaticPopupDialogs = {}
    _G.StaticPopup_Show = function(dialogName)
      popupShown = dialogName
    end
    local emptyState = HeaderElements.createEmptyState(pane, nil, factory)
    local btn = assert(findNewWhisperButton(emptyState), "emptyState should have a new whisper button")
    assert(btn.scripts ~= nil and btn.scripts.OnClick ~= nil, "expected OnClick script on new whisper button")
    btn.scripts.OnClick(btn)
    assert(
      popupShown == "WHISPER_MESSENGER_START_CONVERSATION",
      "expected button click to show start conversation popup, got: " .. tostring(popupShown)
    )
  end
  -- test_empty_state_button_uses_title_bar_new_whisper_icon
  do
    local emptyState = HeaderElements.createEmptyState(pane, nil, factory)
    local btn = assert(findNewWhisperButton(emptyState), "emptyState should have a new whisper button")
    local icon = FindUI.ofType(btn, "Texture")[2]
    assert(icon ~= nil, "button should have an icon texture")
    assert(
      icon.texturePath == Theme.TEXTURES.title_new_whisper_icon,
      "button icon should match title-bar new whisper icon, got: " .. tostring(icon.texturePath)
    )
  end

  -- test_empty_state_shows_welcome_title
  do
    local emptyState = HeaderElements.createEmptyState(pane, nil, factory)
    assert(FindUI.text(emptyState, "Welcome to WhisperMessenger") ~= nil, "empty state should show welcome title")
  end

  -- test_empty_state_shows_pick_conversation_subtitle
  do
    local emptyState = HeaderElements.createEmptyState(pane, nil, factory)
    local subtitle = FindUI.text(emptyState, "Pick a conversation on the left, or start a new one.")
    assert(subtitle ~= nil, "empty state should show subtitle")
  end

  -- test_empty_state_shows_addon_logo
  do
    local emptyState = HeaderElements.createEmptyState(pane, nil, factory)
    local logo = FindUI.find(emptyState, function(node)
      return node.frameType == "Texture" and node.texturePath == "Interface\\AddOns\\WhisperMessenger\\Media\\icon.png"
    end)
    assert(logo ~= nil, "empty state should show addon logo")
  end

  -- test_empty_state_apply_theme_repaints_title
  do
    local emptyState = HeaderElements.createEmptyState(pane, nil, factory)
    assert(type(emptyState.applyTheme) == "function", "empty state should expose applyTheme")
    local title = assert(FindUI.text(emptyState, "Welcome to WhisperMessenger"), "expected welcome title")
    title.textColor = nil
    emptyState.applyTheme()
    assert(title.textColor ~= nil, "applyTheme should repaint title color")
  end
end
