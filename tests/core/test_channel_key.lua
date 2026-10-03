local ChannelKey = require("WhisperMessenger.Core.Ingest.ChannelChatIngest.ChannelKey")

-- Built-in channels key by their zone channel ID (names are localized);
-- custom channels key by their lowercased base name.
return function()
  -- test_known_zone_id_keys_by_slug
  assert(ChannelKey.ContactKey(2, "Trade - City") == "CHANNEL::trade", "Trade keys by its zone ID")

  -- test_custom_channel_keys_by_lowercased_name
  assert(ChannelKey.ContactKey(0, "CraftScan") == "CHANNEL::c:craftscan", "custom channels key by name")

  -- test_unknown_zone_id_falls_back_to_name
  assert(ChannelKey.ContactKey(99, "Mystery") == "CHANNEL::c:mystery", "an unknown ID falls back to the name")

  -- test_name_keying_drops_the_zone
  assert(ChannelKey.ContactKey(nil, "General - Elwynn Forest") == "CHANNEL::c:general", "without an ID, one chat spans every zone")

  -- test_missing_id_and_name_gives_nil
  assert(ChannelKey.ContactKey(nil, nil) == nil, "no ID and no name gives no key")

  -- test_zone_label_is_the_suffix
  assert(ChannelKey.ZoneLabel("1. General - Elwynn Forest") == "Elwynn Forest", "the zone label is the part after the dash")

  -- test_zone_label_is_nil_without_a_zone
  assert(ChannelKey.ZoneLabel("5. CraftScan") == nil, "a channel without a zone has no label")

  -- test_setting_key_is_the_slug
  assert(ChannelKey.SettingKey("trade") == "trade", "the setting key is the slug")
end
