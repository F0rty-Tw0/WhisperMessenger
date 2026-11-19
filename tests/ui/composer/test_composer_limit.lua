local FakeUI = require("tests.helpers.fake_ui")
local ComposerLimit = require("WhisperMessenger.UI.Composer.ComposerLimit")
local MessageSplit = require("WhisperMessenger.Util.MessageSplit")

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

  local function newLimit()
    return ComposerLimit.Create(FakeUI.NewFactory().CreateFrame("EditBox", nil, nil))
  end

  -- test_fits_group_keeps_255_bytes
  do
    local limit = newLimit()
    limit.setChannel("PARTY")
    assert(limit.fits(string.rep("a", 255)) == true, "255 bytes fit a group chat")
    assert(limit.fits(string.rep("a", 256)) == false, "256 bytes do not fit a group chat")
  end

  -- test_fits_no_chat_uses_the_group_cap
  do
    local limit = newLimit()
    limit.setChannel(nil)
    assert(limit.fits(string.rep("a", 256)) == false, "no chat keeps the group cap")
  end

  -- test_fits_whisper_keeps_799_bytes
  do
    local limit = newLimit()
    assert(MessageSplit.Count(string.rep("a", 799), 255) <= 4, "precondition: 799 bytes split into at most 4 parts")
    limit.setChannel("WOW")
    assert(limit.fits(string.rep("a", 799)) == true, "799 bytes fit a whisper")
    assert(limit.fits(string.rep("a", 800)) == false, "800 bytes do not fit a whisper")
    limit.setChannel("BN")
    assert(limit.fits(string.rep("a", 800)) == false, "800 bytes do not fit a Battle.net whisper")
  end

  -- test_fits_whisper_rejects_more_than_four_parts
  do
    local limit = newLimit()
    local word = string.rep("a", 150)
    local text = table.concat({ word, word, word, word, word }, " ")
    assert(MessageSplit.Count(text, 255) == 5, "precondition: text splits into 5 parts")
    limit.setChannel("WOW")
    assert(limit.fits(text) == false, "a 5-part whisper does not fit")
  end
end
