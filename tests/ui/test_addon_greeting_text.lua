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

return function()
  test_tagged_whisper_names_craft_alert()
  test_every_spelling_is_rewritten()
  test_untagged_whisper_keeps_craftscan()
  test_links_stay_intact()
  test_stored_text_unchanged()
  test_text_with_pattern_characters_is_safe()
end
