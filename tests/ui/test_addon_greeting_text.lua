local AddonGreetingText = require("WhisperMessenger.UI.ChatBubble.AddonGreetingText")

-- Addon-tagged whispers show CraftScan as "Craft Alert". Only the shown text
-- changes; links and untagged whispers are left alone.

local function tagged(text)
  return { text = text, addonGreeting = "CraftScan" }
end

local function test_tagged_whisper_names_craft_alert()
  local shown = AddonGreetingText.ForDisplay(tagged("Found you via CraftScan: hi"))
  assert(shown == "Found you via Craft Alert: hi", "CraftScan shown as Craft Alert, got " .. shown)
end

local function test_every_spelling_is_rewritten()
  local shown = AddonGreetingText.ForDisplay(tagged("craftscan, CRAFT SCAN and Craft Scan"))
  assert(shown == "Craft Alert, Craft Alert and Craft Alert", "case and spacing variants rewritten, got " .. shown)
end

local function test_untagged_whisper_keeps_craftscan()
  local message = { text = "I use CraftScan" }
  assert(AddonGreetingText.ForDisplay(message) == "I use CraftScan", "untagged whisper never rewritten")
end

local function test_links_stay_intact()
  local link = "|cffa335ee|Hitem:1:CraftScan|h[CraftScan Hammer]|h|r"
  local shown = AddonGreetingText.ForDisplay(tagged("CraftScan: " .. link))
  assert(shown == "Craft Alert: " .. link, "link data and name untouched, got " .. shown)
end

local function test_stored_text_unchanged()
  local message = tagged("Found you via CraftScan")
  AddonGreetingText.ForDisplay(message)
  assert(message.text == "Found you via CraftScan", "the stored text stays as received")
end

local function test_text_with_pattern_characters_is_safe()
  local shown = AddonGreetingText.ForDisplay(tagged("50% off (%d) [craftscan]"))
  assert(shown == "50% off (%d) [Craft Alert]", "pattern characters copied as-is, got " .. shown)
end

local function test_longer_words_stay_unchanged()
  local text = "CraftScanner, MyCraftScan, Craft Scanning, craftscan2"
  local shown = AddonGreetingText.ForDisplay(tagged(text))
  assert(shown == text, "only whole words are renamed, got " .. shown)
end

local function test_quotes_and_symbols_end_a_word()
  local shown = AddonGreetingText.ForDisplay(tagged("«CraftScan» ¡CraftScan!"))
  assert(shown == "«Craft Alert» ¡Craft Alert!", "punctuation is not part of the word, got " .. shown)
end

local function test_localized_names_are_rewritten()
  for _, name in ipairs({ "КрафтСкан", "크래프트스캔", "制造扫描" }) do
    local shown = AddonGreetingText.ForDisplay(tagged("via " .. name .. ": [x]"))
    assert(shown == "via Craft Alert: [x]", name .. " shown as Craft Alert, got " .. shown)
  end
end

local function test_localized_name_next_to_its_script()
  -- Korean and Chinese write particles straight after the name.
  local shown = AddonGreetingText.ForDisplay(tagged("크래프트스캔으로 / 通过制造扫描找到"))
  assert(shown == "Craft Alert으로 / 通过Craft Alert找到", "CJK neighbours are no word boundary, got " .. shown)
  local cyrillic = AddonGreetingText.ForDisplay(tagged("КрафтСканер"))
  assert(cyrillic == "КрафтСканер", "a longer Cyrillic word stays, got " .. cyrillic)
end

local function test_untagged_localized_name_unchanged()
  assert(AddonGreetingText.ForDisplay({ text = "КрафтСкан" }) == "КрафтСкан", "untagged never rewritten")
end

local function test_preview_of_a_tagged_newest_line_is_renamed()
  local conversation = { messages = { { text = "hi" }, tagged("via CraftScan") } }
  local shown = AddonGreetingText.ForPreview(conversation, "via CraftScan")
  assert(shown == "via Craft Alert", "tagged preview renamed, got " .. tostring(shown))
end

local function test_preview_of_an_untagged_newest_line_is_kept()
  local conversation = { messages = { tagged("via CraftScan"), { text = "I use CraftScan" } } }
  assert(AddonGreetingText.ForPreview(conversation, "I use CraftScan") == "I use CraftScan", "untagged newest line kept")
end

local function test_preview_not_from_the_newest_line_is_kept()
  local conversation = { messages = { tagged("via CraftScan") } }
  assert(AddonGreetingText.ForPreview(conversation, "CraftScan joined") == "CraftScan joined", "other preview text kept")
  assert(AddonGreetingText.ForPreview(nil, "x") == "x", "no conversation, preview kept")
end

local function test_incoming_preview_uses_the_newest_incoming_line()
  local incoming = tagged("via CraftScan")
  incoming.direction, incoming.kind = "in", "user"
  local conversation = { messages = { incoming, { text = "my reply", direction = "out", kind = "user" } } }
  local shown = AddonGreetingText.ForIncomingPreview(conversation, "via CraftScan")
  assert(shown == "via Craft Alert", "incoming preview renamed past my reply, got " .. tostring(shown))
end

return function()
  test_preview_of_a_tagged_newest_line_is_renamed()
  test_preview_of_an_untagged_newest_line_is_kept()
  test_preview_not_from_the_newest_line_is_kept()
  test_incoming_preview_uses_the_newest_incoming_line()
  test_longer_words_stay_unchanged()
  test_quotes_and_symbols_end_a_word()
  test_localized_names_are_rewritten()
  test_localized_name_next_to_its_script()
  test_untagged_localized_name_unchanged()
  test_tagged_whisper_names_craft_alert()
  test_every_spelling_is_rewritten()
  test_untagged_whisper_keeps_craftscan()
  test_links_stay_intact()
  test_stored_text_unchanged()
  test_text_with_pattern_characters_is_safe()
end
