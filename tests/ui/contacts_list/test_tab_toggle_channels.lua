local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local TabToggle = require("WhisperMessenger.UI.ContactsList.TabToggle")
local Localization = require("WhisperMessenger.Locale.Localization")

-- "Channels" footer tab: shown only when listed in setModes, placed between
-- Groups and Requests, with its own unread badge.

-- Errors when no tab carries the label.
local function tabByLabel(toggle, nativeChrome, text)
  for _, btn in ipairs(FindUI.ofType(toggle.frame, "Button")) do
    local label = nativeChrome and btn.text or (FindUI.ofType(btn, "FontString")[1] or {}).text
    if label == text then
      return btn, FindUI.ofType(btn, "Frame")[1]
    end
  end
  error("no tab labelled " .. text)
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

    -- test_channels_tab_hidden_by_default
    local toggle, changes = createToggle(nativeChrome)
    local btn, badge = tabByLabel(toggle, nativeChrome, "Channels")
    assert(btn.shown == false, skin .. ": channels tab hidden until listed")

    -- test_channels_tab_sits_between_groups_and_requests
    toggle.setModes({ "whispers", "groups", "channels", "requests" })
    assert(btn.shown == true, skin .. ": channels tab shown")
    local groupsBtn = tabByLabel(toggle, nativeChrome, "Groups")
    local requestsBtn = tabByLabel(toggle, nativeChrome, "Requests")
    assert(btn.points[1][2] == groupsBtn, skin .. ": channels follows groups")
    assert(requestsBtn.points[1][2] == btn, skin .. ": requests follows channels")

    -- test_clicking_channels_switches_mode
    btn.scripts.OnClick(btn)
    assert(toggle.getMode() == "channels", skin .. ": channels mode active")
    assert(changes[#changes] == "channels", skin .. ": mode change reported")

    -- test_channels_badge_shows_its_count
    toggle.setUnreadCounts(0, 0, 0, 5)
    assert(badge.shown ~= false, skin .. ": channels badge shows its count")
    toggle.setUnreadCounts(0, 0, 0, 0)
    assert(badge.shown == false, skin .. ": channels badge hidden at zero")

    -- test_hiding_channels_falls_back_to_whispers
    toggle.setModes({ "whispers", "groups" })
    assert(btn.shown == false, skin .. ": channels tab hidden again")
    assert(toggle.getMode() == "whispers", skin .. ": a hidden active tab falls back to Whispers")
  end
end
