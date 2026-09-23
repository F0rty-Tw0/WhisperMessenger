local ChannelType = require("WhisperMessenger.Model.Identity.ChannelType")

return function()
  -- Every constant has the expected string value
  assert(ChannelType.WHISPER == "WHISPER", "expected WHISPER")
  assert(ChannelType.BN_WHISPER == "BN_WHISPER", "expected BN_WHISPER")
  assert(ChannelType.BN_CONVERSATION == "BN_CONVERSATION", "expected BN_CONVERSATION")
  assert(ChannelType.PARTY == "PARTY", "expected PARTY")
  assert(ChannelType.RAID == "RAID", "expected RAID")
  assert(ChannelType.INSTANCE_CHAT == "INSTANCE_CHAT", "expected INSTANCE_CHAT")
  assert(ChannelType.GUILD == "GUILD", "expected GUILD")
  assert(ChannelType.OFFICER == "OFFICER", "expected OFFICER")
  assert(ChannelType.CHANNEL == "CHANNEL", "expected CHANNEL")
  assert(ChannelType.COMMUNITY == "COMMUNITY", "expected COMMUNITY")
end
