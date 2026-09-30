local GroupHeaderViewModel = require("WhisperMessenger.UI.ConversationPane.GroupHeaderViewModel")
local ChannelType = require("WhisperMessenger.Model.Identity.ChannelType")

return function()
  -- test_whisper_title_hides_battletag_numbers
  local vm = assert(GroupHeaderViewModel.Build({ displayName = "BnetFriend#1234", channel = ChannelType.BN_WHISPER }, nil))
  assert(vm.title == "BnetFriend", "title hides the BattleTag number, got " .. tostring(vm.title))
end
