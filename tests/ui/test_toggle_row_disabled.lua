local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local Localization = require("WhisperMessenger.Locale.Localization")
local Theme = require("WhisperMessenger.UI.Theme")
local Hud = require("WhisperMessenger.UI.Theme.Hud")
local UIHelpers = require("WhisperMessenger.UI.Helpers")
local SettingsControls = require("WhisperMessenger.UI.Shared.SettingsControls")
local NotificationSettings = require("WhisperMessenger.UI.MessengerWindow.NotificationSettings")

-- A pad A press (or any scripted click) reaches a toggle's OnClick with no
-- mouse button and no cover in the way: a greyed toggle must ignore it.
return function()
  Localization.Configure({ language = "enUS" })
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  local colors = SettingsControls.ToggleColors(Theme)

  -- test_click_on_a_covered_toggle_changes_nothing
  do
    local changes = {}
    local toggle = UIHelpers.createToggleRow(factory, parent, "T", false, colors, { width = 280 }, function(v)
      changes[#changes + 1] = v
    end)
    local state = UIHelpers.attachDisabledState(factory, toggle.row)
    state.set(false, "why")
    toggle.dot:GetScript("OnClick")(toggle.dot, nil)
    assert(#changes == 0 and not FindUI.isToggleOn(toggle.dot), "covered toggle ignores the click")
    state.set(true)
    toggle.dot:GetScript("OnClick")(toggle.dot, nil)
    assert(changes[1] == true and FindUI.isToggleOn(toggle.dot), "uncovered toggle works")
  end

  -- test_mute_all_sounds_still_re_enables_the_sound_toggles
  do
    local changes = {}
    local page = NotificationSettings.Create(factory, parent, { muteAllSounds = true }, {
      onChange = function(k, v)
        changes[k] = v
      end,
    })
    local whisper = FindUI.toggle(page.frame, "Play sound on new whisper")
    whisper:GetScript("OnClick")(whisper, nil)
    assert(changes.playSoundOnWhisper == nil, "muted: sound toggle ignores the click")
    assert(FindUI.disabledCover(FindUI.byLabel(page.frame, "Play sound on new whisper")) ~= nil, "still greyed with its cover")
    local mute = FindUI.toggle(page.frame, "Mute all sounds")
    mute:GetScript("OnClick")(mute, "LeftButton")
    whisper:GetScript("OnClick")(whisper, "LeftButton")
    assert(changes.muteAllSounds == false and changes.playSoundOnWhisper ~= nil, "unmuted: the sound toggle works again")
  end

  -- test_click_on_a_covered_native_checkbox_undoes_its_own_toggle
  do
    Hud.Configure("classic")
    local changes = {}
    local toggle = UIHelpers.createToggleRow(factory, parent, "T", false, colors, { width = 280 }, function(v)
      changes[#changes + 1] = v
    end)
    UIHelpers.attachDisabledState(factory, toggle.row).set(false, "why")
    Hud.Configure("off")
    assert(toggle.dot.frameType == "CheckButton", "native look: a Blizzard checkbox")
    -- The game flips a CheckButton before its OnClick runs.
    toggle.dot:SetChecked(true)
    toggle.dot:GetScript("OnClick")(toggle.dot, nil)
    assert(#changes == 0 and toggle.dot:GetChecked() == false, "covered checkbox shows its real value again")
  end
end
