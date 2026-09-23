local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local LayoutBuilder = require("WhisperMessenger.UI.MessengerWindow.LayoutBuilder")
local MessengerWindow = require("WhisperMessenger.UI.MessengerWindow")

-- Last SetPoint for `anchor` (WoW replaces per anchor point).
local function lastPoint(region, anchor)
  local found = nil
  for _, pt in ipairs(region.points or {}) do
    if pt[1] == anchor then
      found = pt
    end
  end
  return found
end

local function build()
  local factory = FakeUI.NewFactory()
  local uiParent = factory.CreateFrame("Frame", "UIParent", nil)
  uiParent:SetSize(920, 580)
  local frame = factory.CreateFrame("Frame", "MainFrame", uiParent)
  frame:SetSize(920, 580)
  local layout = LayoutBuilder.Build(factory, frame, { width = 920, height = 580 }, {})
  return layout
end

local function assertPaneInsets(layout, expected, label)
  local topLeft = lastPoint(layout.contactsPane, "TOPLEFT")
  local bottomLeft = lastPoint(layout.contactsPane, "BOTTOMLEFT")
  local bottomRight = lastPoint(layout.contentPane, "BOTTOMRIGHT")
  assert(topLeft ~= nil, label .. ": contacts TOPLEFT anchor missing")
  assert(bottomLeft ~= nil, label .. ": contacts BOTTOMLEFT anchor missing")
  assert(bottomRight ~= nil, label .. ": content BOTTOMRIGHT anchor missing")
  assert(topLeft[4] == expected.left, label .. ": contacts TOPLEFT x, got " .. tostring(topLeft[4]))
  assert(bottomLeft[4] == expected.bottomLeft, label .. ": contacts BOTTOMLEFT x, got " .. tostring(bottomLeft[4]))
  assert(bottomLeft[5] == expected.bottom, label .. ": contacts BOTTOMLEFT y, got " .. tostring(bottomLeft[5]))
  assert(bottomRight[4] == -expected.right, label .. ": content BOTTOMRIGHT x, got " .. tostring(bottomRight[4]))
  assert(bottomRight[5] == expected.contentBottom, label .. ": content BOTTOMRIGHT y, got " .. tostring(bottomRight[5]))
  if layout.composerPane then
    for _, anchor in ipairs({ "BOTTOMLEFT", "BOTTOMRIGHT" }) do
      local pt = lastPoint(layout.composerPane, anchor)
      assert(pt ~= nil, label .. ": composer " .. anchor .. " anchor missing")
      assert(pt[5] == -expected.composerDrop, label .. ": composer " .. anchor .. " y, got " .. tostring(pt[5]))
    end
  end
end

-- Clear only the 1px window hairline; composer flush with its pane.
local MODERN = { left = 1, bottomLeft = 1, bottom = 1, right = 1, contentBottom = 1, composerDrop = 0 }

return function()
  local previousPreset = Theme.GetPreset()

  -- test_insets_resolve_flush_to_window_border
  do
    local L = Theme.LAYOUT
    assert(L.CONTACTS_PANE_LEFT_INSET == 1, "contacts left inset")
    assert(L.CONTACTS_PANE_BOTTOM_LEFT_INSET == 1, "contacts bottom-left inset matches top-left")
    assert(L.CONTACTS_PANE_BOTTOM_INSET == 1, "contacts bottom inset")
    assert(L.CONTENT_PANE_RIGHT_INSET == 1, "content right inset")
    assert(L.CONTENT_PANE_BOTTOM_INSET == 1, "content bottom inset")
  end

  -- test_every_preset_build_anchors_panes_with_the_same_insets
  for _, key in ipairs(Theme.ListPresets()) do
    Theme.SetPreset(key)
    assertPaneInsets(build(), MODERN, key .. " build")
  end

  -- test_relayout_after_preset_switch_keeps_insets
  do
    Theme.SetPreset("wow_native")
    local layout = build()
    Theme.SetPreset("jade_dark")
    LayoutBuilder.Relayout(layout, 920, 580)
    assertPaneInsets(layout, MODERN, "azeroth->jade relayout")
  end

  -- test_window_refresh_theme_reanchors_panes
  do
    Theme.SetPreset("wow_native")
    local factory = FakeUI.NewFactory()
    local savedUIParent = _G.UIParent
    _G.UIParent = factory.CreateFrame("Frame", "UIParent", nil)
    local window = MessengerWindow.Create(factory, { title = "WhisperMessenger", contacts = {} })
    Theme.SetPreset("wow_default")
    window.refreshTheme()
    assertPaneInsets(
      { contactsPane = window.contactsPane, contentPane = window.contentPane, composerPane = window.composerPane },
      MODERN,
      "window refreshTheme"
    )
    _G.UIParent = savedUIParent
  end

  Theme.SetPreset(previousPreset)
  print("PASS: test_pane_window_insets")
end
