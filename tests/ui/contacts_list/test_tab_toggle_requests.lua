local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local TabToggle = require("WhisperMessenger.UI.ContactsList.TabToggle")
local Localization = require("WhisperMessenger.Locale.Localization")

-- Third footer tab "Requests" (Requests inbox on). Shown only when listed in
-- setModes; its unread badge is dim, never the accent colour.

local function colorsMatch(actual, expected)
  if type(actual) ~= "table" or type(expected) ~= "table" then
    return false
  end
  for i = 1, 4 do
    if math.abs((actual[i] or 1) - (expected[i] or 1)) > 0.0001 then
      return false
    end
  end
  return true
end

local function requestsTab(toggle)
  local btn = FindUI.ofType(toggle.frame, "Button")[3]
  return btn, FindUI.ofType(btn, "Frame")[1]
end

local function createToggle(nativeChrome)
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", nil, nil)
  parent:SetSize(300, 500)
  local changes = {}
  local toggle = TabToggle.Create(factory, parent, {
    initialMode = "whispers",
    nativeChrome = nativeChrome,
    onModeChanged = function(mode)
      changes[#changes + 1] = mode
    end,
  })
  toggle.frame:SetSize(300, 24)
  return toggle, changes
end

return function()
  Localization.Configure({ language = "enUS" })

  for _, nativeChrome in ipairs({ false, true }) do
    local skin = nativeChrome and "native" or "modern"

    -- test_requests_tab_hidden_by_default
    local toggle, changes = createToggle(nativeChrome)
    local btn, badge = requestsTab(toggle)
    assert(btn ~= nil, skin .. ": requests tab exists")
    assert(btn.shown == false, skin .. ": requests tab hidden until enabled")

    -- test_set_modes_shows_three_tabs
    toggle.setModes({ "whispers", "groups", "requests" })
    assert(btn.shown == true, skin .. ": requests tab shown")
    local label = nativeChrome and btn.text or FindUI.ofType(btn, "FontString")[1].text
    assert(label == "Requests", skin .. ": label is Requests, got " .. tostring(label))

    -- test_three_tabs_split_the_strip_in_thirds
    local first = FindUI.ofType(toggle.frame, "Button")[1]
    assert(first.points[2][1] == "BOTTOMRIGHT" and first.points[2][4] == 100, skin .. ": first tab is a third of 300px")
    assert(btn.points[1][1] == "TOPLEFT" and btn.points[1][4] == -100, skin .. ": last tab starts a third from the right")

    -- test_resize_reanchors_the_thirds
    toggle.frame:SetSize(600, 24)
    toggle.frame.scripts.OnSizeChanged(toggle.frame)
    assert(first.points[2][4] == 200, skin .. ": thirds follow the new width")

    -- test_clicking_requests_switches_mode
    btn.scripts.OnClick(btn)
    assert(toggle.getMode() == "requests", skin .. ": requests mode active")
    assert(changes[#changes] == "requests", skin .. ": mode change reported")

    -- test_requests_badge_is_dim
    toggle.setUnreadCounts(1, 0, 4)
    assert(badge.shown ~= false, skin .. ": requests badge shows its count")
    local bg = FindUI.ofType(badge, "Texture")
    local circle = bg[#bg]
    assert(colorsMatch(circle.vertexColor, Theme.COLORS.option_toggle_off), skin .. ": requests badge is dim, not accent")

    -- test_two_modes_hide_requests_again
    toggle.setModes({ "whispers", "groups" })
    assert(btn.shown == false, skin .. ": requests tab hidden again")
    assert(toggle.getMode() == "whispers", skin .. ": a hidden active tab falls back to Whispers")
  end
end
