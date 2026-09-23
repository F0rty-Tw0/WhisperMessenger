local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local LayoutMetrics = require("WhisperMessenger.UI.MessengerWindow.LayoutBuilder.Metrics")
local ContactsSection = require("WhisperMessenger.UI.MessengerWindow.LayoutBuilder.ContactsSection")
local ContactsResize = require("WhisperMessenger.UI.MessengerWindow.WindowScripts.Frame.ContactsResize")

local function sameRgb(actual, expected)
  return actual ~= nil and actual[1] == expected[1] and actual[2] == expected[2] and actual[3] == expected[3]
end

local function build(presetKey)
  Theme.SetPreset(presetKey)
  local factory = FakeUI.NewFactory()
  local frame = factory.CreateFrame("Frame", "MainFrame", nil)
  frame:SetSize(920, 580)
  local sizing = LayoutMetrics.CalculateRelayout({}, 920, 580, nil, Theme)
  local section = ContactsSection.Build(factory, frame, sizing, { theme = Theme })
  local resize = ContactsResize.New({
    contactsResizeHandle = section.contactsResizeHandle,
    frameTheme = Theme,
    layout = { contactsDivider = section.contactsDivider },
    frame = frame,
    getCursorX = function()
      return 300
    end,
    getFrameLeft = function()
      return 100
    end,
    relayoutWindow = function() end,
    frameWidth = function()
      return 920
    end,
    frameHeight = function()
      return 580
    end,
    buildState = function()
      return {}
    end,
  })
  return section.contactsResizeHandle, section.contactsDivider, resize
end

return function()
  -- test_modern_rest_shows_only_hairline
  do
    local handle = build("wow_default")
    assert(handle.line ~= nil, "expected a hover line texture on the resize handle")
    assert(handle.line:IsShown() == false, "expected hover line hidden at rest")
    assert(handle.hoverBg == nil and handle.outline == nil, "no background fill or outline box parts")
  end

  -- test_modern_hover_fades_in_neutral_line_without_box
  do
    local handle, divider, resize = build("wow_default")
    local idle = Theme.COLORS.contacts_divider
    local hover = Theme.COLORS.contacts_divider_hover
    resize.setHighlight(true)
    assert(handle.line:IsShown() == true, "expected hover line shown on hover")
    assert(sameRgb(handle.line.color, hover), "expected hover line in neutral hover color")
    assert(handle.line:GetAlpha() == hover[4], "expected hover line alpha to match hover color alpha")
    assert(sameRgb(divider.color, idle), "expected hairline divider to keep its idle color on modern hover")

    resize.setHighlight(false)
    assert(handle.line:IsShown() == false, "expected hover line hidden after leave")
  end

  -- test_modern_drag_uses_accent_until_release
  do
    local handle, _, resize = build("wow_default")
    resize.start("LeftButton")
    assert(handle.line:IsShown() == true, "expected line shown while dragging")
    assert(sameRgb(handle.line.color, Theme.COLORS.accent_primary), "expected accent line while dragging")
    resize.stop("LeftButton")
    assert(handle.line:IsShown() == false, "expected line hidden after release")
  end

  -- test_azeroth_hover_fades_in_the_same_line
  do
    local handle, divider, resize = build("wow_native")
    resize.setHighlight(true)
    assert(handle.line:IsShown() == true, "expected hover line under Azeroth too")
    assert(sameRgb(handle.line.color, Theme.COLORS.contacts_divider_hover), "expected neutral hover line")
    assert(sameRgb(divider.color, Theme.COLORS.contacts_divider), "expected hairline divider to keep its idle color")
    resize.setHighlight(false)
    assert(handle.line:IsShown() == false, "expected hover line hidden after leave")
  end

  Theme.SetPreset(Theme.DEFAULT_PRESET)
end
