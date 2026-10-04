local ChannelType = require("WhisperMessenger.Model.Identity.ChannelType")

local function assertSetEquals(set, expected, label)
  assert(type(set) == "table", label .. " should be a table")
  local count = 0
  for key, value in pairs(set) do
    assert(value == true, label .. "[" .. tostring(key) .. "] should be true")
    count = count + 1
  end
  for _, key in ipairs(expected) do
    assert(set[key] == true, label .. " should contain " .. key)
  end
  assert(count == #expected, label .. " should hold exactly " .. #expected .. " channels, got " .. count)
end

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

  -- Group chats: every channel except one-to-one whispers
  assertSetEquals(ChannelType.GROUP_CHANNELS, {
    "BN_CONVERSATION",
    "PARTY",
    "RAID",
    "INSTANCE_CHAT",
    "GUILD",
    "OFFICER",
    "CHANNEL",
    "COMMUNITY",
  }, "GROUP_CHANNELS")

  -- Addon-message group channels: the group chats SendAddonMessage can reach
  assertSetEquals(ChannelType.ADDON_GROUP_CHANNELS, { "PARTY", "RAID", "INSTANCE_CHAT", "GUILD", "OFFICER" }, "ADDON_GROUP_CHANNELS")
end
