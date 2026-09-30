local ContactPrefsDialog = require("WhisperMessenger.UI.ContactsList.ContactPrefsDialog")

return function()
  local shown = {}
  _G.StaticPopupDialogs = {}
  rawset(_G, "StaticPopup_Show", function(name, textArg)
    shown.name, shown.textArg = name, textArg
  end)

  -- test_dialog_prompt_hides_battletag_numbers
  ContactPrefsDialog.ShowNickname({ displayName = "Arthas#1234", battleTag = "Arthas#1234" }, function() end)
  assert(shown.textArg == "Arthas", "prompt names the BattleTag without its number, got " .. tostring(shown.textArg))

  rawset(_G, "StaticPopup_Show", nil)
  _G.StaticPopupDialogs = nil
end
