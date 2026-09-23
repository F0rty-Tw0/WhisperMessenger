local MessengerWindow = require("WhisperMessenger.UI.MessengerWindow")
local ComposerSurface = require("WhisperMessenger.UI.Composer.ComposerSurface")
local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local TabToggle = require("WhisperMessenger.UI.ContactsList.TabToggle")

local function bottomAnchorY(scrollFrame)
  for i = #(scrollFrame.points or {}), 1, -1 do
    if scrollFrame.points[i][1] == "BOTTOMRIGHT" then
      return scrollFrame.points[i][5]
    end
  end
  return nil
end

local function buildWindow(nativeChrome)
  local factory = FakeUI.NewFactory()
  local savedUIParent = _G.UIParent
  _G.UIParent = factory.CreateFrame("Frame", "UIParent", nil)
  _G.UIParent:SetSize(1280, 720)
  local window = MessengerWindow.Create(factory, {
    contacts = {},
    settingsConfig = { showGroupChats = true, nativeChrome = nativeChrome },
  })
  _G.UIParent = savedUIParent
  return window
end

local function hasNativeInputBorder(composer)
  return FindUI.find(composer.input, function(node)
    return node.texturePath == ComposerSurface.NATIVE_BORDER_TEXTURE
  end) ~= nil
end

local function emptyStateButton(window)
  return FindUI.ofType(window.conversation.headerEmpty, "Button")[1]
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
    assert(window.tabToggle.frame.points[1][2] == window.contactsPane, "HUD window: tabs inside the contacts pane")
    local listBottom = bottomAnchorY(window.contacts.scrollFrame)
    assert(listBottom == TabToggle.NATIVE_HEIGHT, "HUD window: list stops above the tabs, got " .. tostring(listBottom))
    window.refreshTheme()
    window.refreshLanguage()
  end

  -- test_modern_window_keeps_custom_widgets
  do
    local window = buildWindow(false)
    assert(window.contactsSearchInput.template == nil, "modern window: search box")
    assert(FindUI.ofType(window.tabToggle.frame, "Button")[1].template == nil, "modern window: tabs")
    assert(not hasNativeInputBorder(window.composer), "modern window: composer")
    assert(emptyStateButton(window).template == nil, "modern window: Start New Whisper button")
    assert(window.resetWindowButton.template == nil, "modern window: Reset Window button")
  end
end
