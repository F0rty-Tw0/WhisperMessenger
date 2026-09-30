local StatusLine = require("WhisperMessenger.UI.ConversationPane.StatusLine")

return function()
  -- test_realm_line_hides_battletag_numbers
  local line1 = StatusLine.Build({ displayName = "Arthas#1234", realmName = "Illidan" }, { status = "CanWhisper" })
  assert(string.find(line1, "Arthas-Illidan", 1, true), "realm line hides the BattleTag number: " .. line1)
  assert(not string.find(line1, "#1234", 1, true), "no BattleTag number on line1: " .. line1)
end
