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

  -- IsKnown: true for every constant
  assert(ChannelType.IsKnown(ChannelType.WHISPER), "WHISPER should be known")
  assert(ChannelType.IsKnown(ChannelType.BN_WHISPER), "BN_WHISPER should be known")
  assert(ChannelType.IsKnown(ChannelType.BN_CONVERSATION), "BN_CONVERSATION should be known")
  assert(ChannelType.IsKnown(ChannelType.PARTY), "PARTY should be known")
  assert(ChannelType.IsKnown(ChannelType.RAID), "RAID should be known")
  assert(ChannelType.IsKnown(ChannelType.INSTANCE_CHAT), "INSTANCE_CHAT should be known")
  assert(ChannelType.IsKnown(ChannelType.GUILD), "GUILD should be known")
  assert(ChannelType.IsKnown(ChannelType.OFFICER), "OFFICER should be known")
  assert(ChannelType.IsKnown(ChannelType.CHANNEL), "CHANNEL should be known")
  assert(ChannelType.IsKnown(ChannelType.COMMUNITY), "COMMUNITY should be known")

  -- IsKnown: false for non-values
  assert(not ChannelType.IsKnown(nil), "nil should not be known")
  assert(not ChannelType.IsKnown(""), "empty string should not be known")
  assert(not ChannelType.IsKnown("WOW"), "WOW is a contact channel tag, not a ChannelType")
  assert(not ChannelType.IsKnown("BN"), "BN is a contact channel tag, not a ChannelType")
  assert(not ChannelType.IsKnown("garbage"), "garbage should not be known")
  assert(not ChannelType.IsKnown(42), "number should not be known")

  -- IsGroup: false only for WHISPER and BN_WHISPER
  assert(not ChannelType.IsGroup(ChannelType.WHISPER), "WHISPER is not a group channel")
  assert(not ChannelType.IsGroup(ChannelType.BN_WHISPER), "BN_WHISPER is not a group channel")
  assert(ChannelType.IsGroup(ChannelType.BN_CONVERSATION), "BN_CONVERSATION is a group channel")
  assert(ChannelType.IsGroup(ChannelType.PARTY), "PARTY is a group channel")
  assert(ChannelType.IsGroup(ChannelType.RAID), "RAID is a group channel")
  assert(ChannelType.IsGroup(ChannelType.INSTANCE_CHAT), "INSTANCE_CHAT is a group channel")
  assert(ChannelType.IsGroup(ChannelType.GUILD), "GUILD is a group channel")
  assert(ChannelType.IsGroup(ChannelType.OFFICER), "OFFICER is a group channel")
  assert(ChannelType.IsGroup(ChannelType.CHANNEL), "CHANNEL is a group channel")
  assert(ChannelType.IsGroup(ChannelType.COMMUNITY), "COMMUNITY is a group channel")

  -- IsPersistent: true for WHISPER, BN_WHISPER, BN_CONVERSATION, GUILD, OFFICER, CHANNEL, COMMUNITY
  assert(ChannelType.IsPersistent(ChannelType.WHISPER), "WHISPER should be persistent")
  assert(ChannelType.IsPersistent(ChannelType.BN_WHISPER), "BN_WHISPER should be persistent")
  assert(ChannelType.IsPersistent(ChannelType.BN_CONVERSATION), "BN_CONVERSATION should be persistent")
  assert(ChannelType.IsPersistent(ChannelType.GUILD), "GUILD should be persistent")
  assert(ChannelType.IsPersistent(ChannelType.OFFICER), "OFFICER should be persistent")
  assert(ChannelType.IsPersistent(ChannelType.CHANNEL), "CHANNEL should be persistent")
  assert(ChannelType.IsPersistent(ChannelType.COMMUNITY), "COMMUNITY should be persistent")

  -- IsPersistent: false for ephemeral group channels
  assert(not ChannelType.IsPersistent(ChannelType.PARTY), "PARTY is ephemeral, not persistent")
  assert(not ChannelType.IsPersistent(ChannelType.RAID), "RAID is ephemeral, not persistent")
  assert(not ChannelType.IsPersistent(ChannelType.INSTANCE_CHAT), "INSTANCE_CHAT is ephemeral, not persistent")

  -- IsSendable: false only for COMMUNITY (receive-only since patch 8.1.0)
  assert(ChannelType.IsSendable(ChannelType.WHISPER), "WHISPER should be sendable")
  assert(ChannelType.IsSendable(ChannelType.BN_WHISPER), "BN_WHISPER should be sendable")
  assert(ChannelType.IsSendable(ChannelType.BN_CONVERSATION), "BN_CONVERSATION should be sendable")
  assert(ChannelType.IsSendable(ChannelType.PARTY), "PARTY should be sendable")
  assert(ChannelType.IsSendable(ChannelType.RAID), "RAID should be sendable")
  assert(ChannelType.IsSendable(ChannelType.INSTANCE_CHAT), "INSTANCE_CHAT should be sendable")
  assert(ChannelType.IsSendable(ChannelType.GUILD), "GUILD should be sendable")
  assert(ChannelType.IsSendable(ChannelType.OFFICER), "OFFICER should be sendable")
  assert(ChannelType.IsSendable(ChannelType.CHANNEL), "CHANNEL should be sendable")
  assert(not ChannelType.IsSendable(ChannelType.COMMUNITY), "COMMUNITY is receive-only, not sendable")
end
