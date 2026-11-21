local Theme = require("WhisperMessenger.UI.Theme")
local Fonts = require("WhisperMessenger.UI.Theme.Fonts")
-- Installs the fake CreateFont that font changes need.
require("tests.helpers.fake_ui")

return function()
  local previousPreset = Theme.GetPreset()
  local previousSize = Fonts.GetFontSize()

  -- test_revision_is_stable_without_changes
  do
    assert(Theme.Revision() == Theme.Revision(), "revision should not move by itself")
  end

  -- test_preset_switch_raises_the_revision
  do
    local before = Theme.Revision()
    Theme.SetPreset(previousPreset == "wow_default" and "elvui_dark" or "wow_default")
    assert(Theme.Revision() > before, "a preset switch should raise the revision")
  end

  -- test_rejected_preset_keeps_the_revision
  do
    local before = Theme.Revision()
    assert(Theme.SetPreset("no_such_preset") == false, "unknown preset should be rejected")
    assert(Theme.Revision() == before, "a rejected preset should not raise the revision")
  end

  -- test_font_change_raises_the_revision
  do
    local before = Theme.Revision()
    local fontsBefore = Fonts.Revision()
    Fonts.SetFontSize(previousSize + 1)
    assert(Fonts.Revision() > fontsBefore, "a font change should raise the font revision")
    assert(Theme.Revision() > before, "a font change should raise the theme revision")
  end

  Fonts.SetFontSize(previousSize)
  Theme.SetPreset(previousPreset)
end
