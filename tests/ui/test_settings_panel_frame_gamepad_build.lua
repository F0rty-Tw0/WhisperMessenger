-- On WoW: Forever the game re-scans a whole registered window on every
-- CreateFrame under it. A page is built outside the window while the gamepad
-- UI is on, and moved in once it is whole.
local FakeUI = require("tests.helpers.fake_ui")
local SettingsPanelFrame = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.SettingsPanelFrame")

local function isUnder(frame, ancestor)
  while frame do
    if frame == ancestor then
      return true
    end
    frame = frame.parent
  end
  return false
end

-- Builds `pages` pages with the gamepad UI on or off. Returns the content
-- frame, the built panels, how many frames were created under the content
-- frame, and the parents the pages were built under.
local function build(padOn, pages)
  local savedInput, savedUIParent = _G.InputUtil, _G.UIParent
  _G.InputUtil = {
    IsGamepadUIEnabled = function()
      return padOn
    end,
  }
  local plain = FakeUI.NewFactory()
  _G.UIParent = plain.CreateFrame("Frame", "UIParent", nil)
  local window = plain.CreateFrame("Frame", nil, _G.UIParent)
  window:SetScale(0.8)
  local content = plain.CreateFrame("Frame", nil, window)
  content:SetSize(600, 400)
  content:SetFrameStrata("HIGH")
  content:SetFrameLevel(7)

  local result = { content = content, panels = {}, createdInside = 0, builtUnder = {}, looks = {} }
  local factory = setmetatable({
    CreateFrame = function(kind, name, parent, template)
      if isUnder(parent, window) then
        result.createdInside = result.createdInside + 1
      end
      return plain.CreateFrame(kind, name, parent, template)
    end,
  }, { __index = plain })
  for i = 1, pages or 1 do
    result.panels[i] = SettingsPanelFrame.Create(factory, content, function(pageFactory, panel)
      result.builtUnder[i] = panel.parent
      result.looks[i] = { strata = panel.parent:GetFrameStrata(), level = panel.parent:GetFrameLevel(), scale = panel:GetEffectiveScale() }
      return { frame = pageFactory.CreateFrame("Frame", nil, panel) }
    end, {}, function() end)
  end
  _G.InputUtil, _G.UIParent = savedInput, savedUIParent
  return result
end

return function()
  -- test_pad_on_creates_no_frame_inside_the_window
  do
    local result = build(true)
    assert(result.createdInside == 0, "each one re-scans the window, got " .. result.createdInside)
  end

  -- test_pad_on_moves_the_built_page_into_the_window
  do
    local result = build(true)
    assert(result.panels[1].parent == result.content, "the page ends up in the settings pane")
  end

  -- test_pad_on_builds_at_the_pane_strata_level_and_scale
  do
    local result = build(true)
    local look = result.looks[1]
    assert(look.strata == "HIGH", "strata, got " .. tostring(look.strata))
    assert(look.level == 7, "level, got " .. tostring(look.level))
    assert(math.abs(look.scale - 0.8) < 0.0001, "scale, got " .. tostring(look.scale))
  end

  -- test_pad_on_reuses_one_holder
  do
    local result = build(true, 2)
    assert(result.builtUnder[1] == result.builtUnder[2], "pages share one holder")
  end

  -- test_pad_off_builds_the_page_in_place
  do
    local result = build(false)
    assert(result.builtUnder[1] == result.content, "without the gamepad UI nothing re-scans")
  end
end
