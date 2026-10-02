local MessengerWindow = require("WhisperMessenger.UI.MessengerWindow")
local ContactsList = require("WhisperMessenger.UI.ContactsList")
local Hud = require("WhisperMessenger.UI.Theme.Hud")
local Theme = require("WhisperMessenger.UI.Theme")
local FakeUI = require("tests.helpers.fake_ui")
local RetailHud = require("tests.helpers.retail_hud")

local RAIL = Theme.LAYOUT.CONTACTS_RAIL_WIDTH

-- Settings opened while the contacts pane is the rail lay the window out as
-- expanded, so everything pinned to the contacts pane (the Modern HUD's
-- panel border, the divider and its drag handle) lines up with the settings
-- menu instead of standing at the rail edge across it. Closing settings
-- brings the rail back; the saved collapsed state never changes.

local function build(hudStyle)
  Hud.Configure(hudStyle or "off")
  local factory = FakeUI.NewFactory()
  local savedUIParent = _G.UIParent
  _G.UIParent = factory.CreateFrame("Frame", "UIParent", nil)
  _G.UIParent:SetSize(1920, 1080)
  local saved = {}
  local window = MessengerWindow.Create(factory, {
    contacts = ContactsList.BuildItems({
      ["me::WOW::jaina"] = { displayName = "Jaina", channel = "WOW", lastActivityAt = 1 },
    }),
    state = { width = 900, height = 560, contactsWidth = 280, contactsCollapsed = true },
    settingsConfig = { showGroupChats = true },
    onPositionChanged = function(nextState)
      saved.state = nextState
    end,
  })
  rawset(window.frame, "GetEffectiveScale", function()
    return 1
  end)
  rawset(window.frame, "GetLeft", function()
    return 0
  end)
  _G.UIParent = savedUIParent
  return window, saved
end

local function openSettings(window)
  window.optionsButton.scripts.OnClick(window.optionsButton)
end

local function closeSettings(window)
  window.backButton.scripts.OnClick(window.backButton)
end

local function checkSkin(label, window, saved)
  -- test_settings_lay_the_pane_out_at_the_nav_width
  openSettings(window)
  assert(window.optionsPanel.shown == true, label .. ": settings open")
  assert(
    window.contactsPane.width == window.optionsMenu.width,
    label .. ": pane matches the settings nav, got " .. tostring(window.contactsPane.width)
  )
  assert(window.optionsMenu.width == 280, label .. ": nav keeps the expanded width")
  assert(saved.state == nil or saved.state.contactsCollapsed ~= false, label .. ": collapsed state not saved as expanded")

  -- test_handle_drag_in_settings_cannot_expand_or_collapse
  local cursorX = 400
  rawset(_G, "GetCursorPosition", function()
    return cursorX, 0
  end)
  local handle = window.contactsResizeHandle
  handle.scripts.OnMouseDown(handle, "LeftButton")
  window.frame.scripts.OnUpdate(window.frame, 0)
  cursorX = 20
  window.frame.scripts.OnUpdate(window.frame, 0)
  handle.scripts.OnMouseUp(handle, "LeftButton")
  assert(window.contactsPane.width == window.optionsMenu.width, label .. ": a drag in settings leaves the layout")

  -- test_closing_settings_brings_the_rail_back
  closeSettings(window)
  assert(window.contactsPane.width == RAIL, label .. ": rail again, got " .. tostring(window.contactsPane.width))
  assert(window.contacts.rows[1]._wmCompact == true, label .. ": rows icon-only again")
  assert(saved.state == nil or saved.state.contactsCollapsed == true, label .. ": still saved collapsed")
  assert(window.optionsMenu.width == 280, label .. ": expanded width kept, got " .. tostring(window.optionsMenu.width))
end

return function()
  local savedCursor = _G.GetCursorPosition

  do
    local window, saved = build("off")
    checkSkin("modern", window, saved)
  end

  do
    local window, saved = build("classic")
    checkSkin("classic HUD", window, saved)
  end

  -- test_modern_hud_panel_border_follows_the_pane
  RetailHud.With(function()
    local window, saved = build("retail")
    local inset = window.frame.contactsInset
    assert(inset ~= nil and inset.points[2][2] == window.contactsPane, "Modern HUD: contacts panel border pinned to the pane")
    checkSkin("Modern HUD", window, saved)
  end)

  Hud.Configure("off")
  rawset(_G, "GetCursorPosition", savedCursor)
end
