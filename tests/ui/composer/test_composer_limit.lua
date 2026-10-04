local ComposerLimit = require("WhisperMessenger.UI.Composer.ComposerLimit")

return function()
  -- test_whisper_channels_get_the_long_cap
  do
    assert(ComposerLimit.InputMaxBytes("WOW") == 800, "WoW whisper cap")
    assert(ComposerLimit.InputMaxBytes("BN") == 800, "Battle.net whisper cap")
  end

  -- test_group_and_unknown_channels_keep_one_message
  do
    for _, channel in ipairs({ "PARTY", "RAID", "INSTANCE_CHAT", "GUILD", "OFFICER", "CHANNEL", "COMMUNITY" }) do
      assert(ComposerLimit.InputMaxBytes(channel) == 256, channel .. " keeps the 255-byte cap")
    end
    assert(ComposerLimit.InputMaxBytes(nil) == 256, "no conversation keeps the 255-byte cap")
  end
end
