-- Player links in our frames are rewritten into addon links so the secure link
-- template's SetItemRef ignores them and our click hook routes them. The codec encodes
-- and decodes that form; BNplayer, item and URL links stay as they are.
local Codec = require("WhisperMessenger.UI.Hyperlinks.PlayerLinkCodec")

local PLAYER = "|Hplayer:Name-Realm:12|h[Name]|h"
local PLAYER_ENCODED = "|Haddon:WhisperMessenger:player:Name-Realm:12|h[Name]|h"

local function eq(actual, expected, label)
  assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

return function()
  -- test_encode_prefixes_player_link
  eq(Codec.Encode(PLAYER), PLAYER_ENCODED, "player link")

  -- test_encode_keeps_player_subtypes
  eq(Codec.Encode("|HplayerGM:Gm-Realm:1|h[Gm]|h"), "|Haddon:WhisperMessenger:playerGM:Gm-Realm:1|h[Gm]|h", "playerGM link")
  eq(Codec.Encode("|HplayerCommunity:Name:club|h[Name]|h"), "|Haddon:WhisperMessenger:playerCommunity:Name:club|h[Name]|h", "playerCommunity link")

  -- test_encode_handles_every_player_link_in_text
  eq(Codec.Encode(PLAYER .. " and " .. PLAYER), PLAYER_ENCODED .. " and " .. PLAYER_ENCODED, "two player links")

  -- test_encode_leaves_other_links_unchanged
  for _, text in ipairs({
    "|HBNplayer:Acc:7|h[Acc]|h",
    "|Hitem:19019::::|h[Thunderfury]|h",
    "|Haddon:WhisperMessenger:url:https://x.y|h[x.y]|h",
  }) do
    eq(Codec.Encode(text), text, "unchanged link")
  end

  -- test_encode_is_idempotent
  eq(Codec.Encode(Codec.Encode(PLAYER)), PLAYER_ENCODED, "encode twice")

  -- test_encode_returns_non_strings_unchanged
  eq(Codec.Encode(nil), nil, "nil text")
  eq(Codec.Encode(5), 5, "number text")

  -- test_decode_link_strips_prefix_from_player_links_only
  eq(Codec.DecodeLink("addon:WhisperMessenger:player:Name-Realm:12"), "player:Name-Realm:12", "decode player link")
  eq(Codec.DecodeLink("addon:WhisperMessenger:url:https://x.y"), "addon:WhisperMessenger:url:https://x.y", "decode url link")
  eq(Codec.DecodeLink("player:Name"), "player:Name", "decode plain link")
  eq(Codec.DecodeLink(nil), nil, "decode nil")

  -- test_is_encoded_only_for_prefixed_player_links
  eq(Codec.IsEncoded("addon:WhisperMessenger:player:Name-Realm:12"), true, "encoded player link")
  eq(Codec.IsEncoded("addon:WhisperMessenger:playerGM:Gm-Realm:1"), true, "encoded playerGM link")
  eq(Codec.IsEncoded("addon:WhisperMessenger:url:https://x.y"), false, "url link")
  eq(Codec.IsEncoded("player:Name"), false, "plain player link")
  eq(Codec.IsEncoded(nil), false, "nil link")

  -- test_decode_text_reverses_encode
  eq(Codec.DecodeText(Codec.Encode(PLAYER)), PLAYER, "round trip")
  eq(Codec.DecodeText("|Haddon:WhisperMessenger:url:https://x.y|h[x.y]|h"), "|Haddon:WhisperMessenger:url:https://x.y|h[x.y]|h", "decode text url")
  eq(Codec.DecodeText(nil), nil, "decode text nil")
end
