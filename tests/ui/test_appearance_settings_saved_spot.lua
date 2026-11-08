local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local AppearanceSettings = require("WhisperMessenger.UI.MessengerWindow.AppearanceSettings")

local LABEL = "Open at saved spot"

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
  -- test_the_saved_spot_toggle_lives_on_the_appearance_page
  do
    local result = create()
    assert(FindUI.byLabel(result.frame, LABEL) ~= nil, "on Appearance")
  end

  -- test_the_saved_spot_starts_off_when_nothing_is_saved
  do
    local result = create()
    assert(not FindUI.isToggleOn(FindUI.toggle(result.frame, LABEL)), "missing means off")
  end

  -- test_a_saved_on_shows_on
  do
    local result = create({ openAtSavedSpot = true })
    assert(FindUI.isToggleOn(FindUI.toggle(result.frame, LABEL)), "saved on")
  end

  -- test_clicking_it_saves_the_choice
  do
    local result, changes = create()
    local toggle = FindUI.toggle(result.frame, LABEL)
    toggle.scripts.OnClick(toggle)
    assert(#changes == 1 and changes[1].key == "openAtSavedSpot" and changes[1].value == true, "asks for on")
  end

  -- test_reset_turns_the_saved_spot_back_off
  do
    local result, changes = create({ openAtSavedSpot = true })
    local reset = FindUI.byLabel(result.frame, "Reset to Defaults")
    reset.scripts.OnClick(reset)
    local saved
    for _, change in ipairs(changes) do
      if change.key == "openAtSavedSpot" then
        saved = change
      end
    end
    assert(saved ~= nil and saved.value == false, "the default is off")
  end

  -- test_the_saved_spot_row_sits_below_the_dock_row
  do
    local result = create()
    local dock = FindUI.byLabel(result.frame, "Dock button on the window")
    local spot = FindUI.byLabel(result.frame, LABEL)
    assert(select(2, spot:GetPoint()) == dock, "anchored under the Dock button row")
    assert(FindUI.text(result.frame, "Button glide") == nil, "the Button glide row is gone")
  end

  -- test_the_saved_spot_label_survives_a_language_refresh
  do
    local result = create()
    result.setLanguage()
    assert(FindUI.byLabel(result.frame, LABEL) ~= nil, "relabelled with the page")
  end
end
