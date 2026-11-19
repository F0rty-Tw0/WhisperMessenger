-- Player links shown in our frames come out encoded as addon links, so the
-- secure link template's SetItemRef ignores them and our click hook routes them.
local Hyperlinks = require("WhisperMessenger.UI.Hyperlinks")
local PlayerLinkCodec = require("WhisperMessenger.UI.Hyperlinks.PlayerLinkCodec")

local PLAYER_ENCODED = "|Haddon:WhisperMessenger:player:Name-Realm:12|h[Name]|h"

return function()
  -- test_format_text_for_display_encodes_player_links
  do
    local shown = Hyperlinks.FormatTextForDisplay("hi |Hplayer:Name-Realm:12|h[Name]|h")
    assert(string.find(shown, PLAYER_ENCODED, 1, true) ~= nil, "player link is encoded, got " .. tostring(shown))
  end

  -- test_encode_player_links_is_the_codec_encode
  do
    assert(Hyperlinks.EncodePlayerLinks == PlayerLinkCodec.Encode, "EncodePlayerLinks is the codec's Encode")
  end
end
