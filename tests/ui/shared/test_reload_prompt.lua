local GlobalWriteSpy = require("tests.helpers.global_write_spy")
local ReloadPopups = require("tests.helpers.reload_popups")
local ReloadPrompt = require("WhisperMessenger.UI.Shared.ReloadPrompt")

return function()
  -- test_show_registers_and_shows_the_dialog
  ReloadPopups.With(function(popups)
    ReloadPrompt.Show("Reload now?")
    assert(popups.shown[1] == ReloadPrompt.DIALOG, "the reload prompt is shown")
    assert(_G.StaticPopupDialogs[ReloadPrompt.DIALOG].text == "Reload now?", "with the given text")
  end)

  -- test_show_does_not_reassign_existing_static_popup_dialogs
  ReloadPopups.With(function(popups)
    local writes, dialogs = GlobalWriteSpy.Writes("StaticPopupDialogs", function()
      ReloadPrompt.Show("Reload now?")
    end)
    assert(popups.shown[1] == ReloadPrompt.DIALOG and dialogs[ReloadPrompt.DIALOG] ~= nil, "the prompt is registered and shown")
    assert(writes == 0, "the game's StaticPopupDialogs is never reassigned")
  end)
end
