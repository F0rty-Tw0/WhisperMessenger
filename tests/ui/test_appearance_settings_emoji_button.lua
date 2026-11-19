local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local AppearanceSettings = require("WhisperMessenger.UI.MessengerWindow.AppearanceSettings")
local WindowStyleSpecs = require("WhisperMessenger.UI.MessengerWindow.AppearanceSettings.WindowStyleSpecs")

local LABEL = "Show emoji button"
local TOOLTIP = "Shows the emoji button next to the message box. Turn it off to give the message box more room. Typed emoji codes still work."

local function create(config)
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  local changes = {}
  local result = AppearanceSettings.Create(factory, parent, config or {}, {
    onChange = function(key, value)
      changes[#changes + 1] = { key = key, value = value }
    end,
  })
  return result, changes
end

return function()
  -- test_the_switch_lives_on_the_appearance_page
  do
    local result = create()
    assert(FindUI.byLabel(result.frame, LABEL) ~= nil, "on Appearance")
  end

  -- test_it_starts_on_when_nothing_is_saved
  do
    local result = create()
    assert(FindUI.isToggleOn(FindUI.toggle(result.frame, LABEL)), "missing means on")
  end

  -- test_a_saved_off_shows_off
  do
    local result = create({ showEmojiButton = false })
    assert(not FindUI.isToggleOn(FindUI.toggle(result.frame, LABEL)), "saved off")
  end

  -- test_clicking_it_saves_off
  do
    local result, changes = create()
    local toggle = FindUI.toggle(result.frame, LABEL)
    toggle.scripts.OnClick(toggle)
    assert(#changes == 1 and changes[1].key == "showEmojiButton" and changes[1].value == false, "asks for off")
  end

  -- test_reset_turns_it_back_on
  do
    local result, changes = create({ showEmojiButton = false })
    local reset = FindUI.byLabel(result.frame, "Reset to Defaults")
    reset.scripts.OnClick(reset)
    local saved
    for _, change in ipairs(changes) do
      if change.key == "showEmojiButton" then
        saved = change
      end
    end
    assert(saved ~= nil and saved.value == true, "the default is on")
  end

  -- test_the_row_sits_below_the_saved_spot_row
  do
    local result = create()
    local spot = FindUI.byLabel(result.frame, "Open at saved spot")
    assert(select(2, FindUI.byLabel(result.frame, LABEL):GetPoint()) == spot, "anchored under the saved spot row")
  end

  -- test_the_label_survives_a_language_refresh
  do
    local result = create()
    result.setLanguage()
    assert(FindUI.byLabel(result.frame, LABEL) ~= nil, "relabelled with the page")
  end

  -- test_the_tooltip_says_typed_codes_still_work
  do
    local found
    local specs = WindowStyleSpecs.Build({}, function() end, function(s)
      return s
    end, 0)
    for _, spec in ipairs(specs) do
      if spec.key == "showEmojiButton" then
        found = spec
      end
    end
    assert(found ~= nil and found.tooltipLines[2] == TOOLTIP, "the tooltip explains typed codes")
  end
end
