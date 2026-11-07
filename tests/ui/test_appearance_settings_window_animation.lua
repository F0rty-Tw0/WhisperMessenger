local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local AppearanceSettings = require("WhisperMessenger.UI.MessengerWindow.AppearanceSettings")

local WindowStyleSpecs = require("WhisperMessenger.UI.MessengerWindow.AppearanceSettings.WindowStyleSpecs")

local LABEL = "Window animation"

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
  -- test_the_window_animation_toggle_lives_on_the_appearance_page
  do
    local result = create()
    assert(FindUI.byLabel(result.frame, LABEL) ~= nil, "on Appearance")
  end

  -- test_the_animation_starts_on_when_nothing_is_saved
  do
    local result = create()
    assert(FindUI.isToggleOn(FindUI.toggle(result.frame, LABEL)), "missing means on")
  end

  -- test_a_saved_off_shows_off
  do
    local result = create({ windowAnimation = false })
    assert(not FindUI.isToggleOn(FindUI.toggle(result.frame, LABEL)), "saved off")
  end

  -- test_clicking_it_saves_the_choice
  do
    local result, changes = create()
    local toggle = FindUI.toggle(result.frame, LABEL)
    toggle.scripts.OnClick(toggle)
    assert(#changes == 1 and changes[1].key == "windowAnimation" and changes[1].value == false, "asks for off")
  end

  -- test_reset_turns_the_animation_back_on
  do
    local result, changes = create({ windowAnimation = false })
    local reset = FindUI.byLabel(result.frame, "Reset to Defaults")
    reset.scripts.OnClick(reset)
    local saved
    for _, change in ipairs(changes) do
      if change.key == "windowAnimation" then
        saved = change
      end
    end
    assert(saved ~= nil and saved.value == true, "the default is on")
  end

  -- test_the_animation_row_sits_below_the_compact_toggle
  do
    local result = create()
    local compactMode = FindUI.byLabel(result.frame, "Phone-style window")
    local animation = FindUI.byLabel(result.frame, LABEL)
    assert(select(2, animation:GetPoint()) == compactMode, "anchored under the compact toggle")
  end

  -- test_the_animation_label_survives_a_language_refresh
  do
    local result = create()
    result.setLanguage()
    assert(FindUI.byLabel(result.frame, LABEL) ~= nil, "relabelled with the page")
  end

  -- test_the_animation_tooltip_says_pages_slide_too
  do
    local specs = WindowStyleSpecs.Build({}, function() end, function(s)
      return s
    end, 0)
    local spec
    for _, candidate in ipairs(specs) do
      if candidate.key == "windowAnimation" then
        spec = candidate
      end
    end
    assert(spec ~= nil, "row exists")
    assert(
      spec.tooltipLines[2]
        == "The window grows out of its icon when it opens and shrinks back into it when it closes, and pages slide in. Turn it off to make everything appear at once.",
      "got " .. tostring(spec.tooltipLines[2])
    )
  end
end
