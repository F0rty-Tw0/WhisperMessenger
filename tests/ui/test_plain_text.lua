local PlainText = require("WhisperMessenger.UI.ChatBubble.PlainText")

-- PlainText.Map rewrites only the text between escape sequences; links,
-- colour runs, textures and atlases are copied byte-exact.

local function upper(segment)
  return string.upper(segment)
end

local function test_plain_text_is_mapped()
  assert(PlainText.Map("hello", upper) == "HELLO", "plain text mapped")
end

local function test_escape_sequences_are_copied()
  local link = "|cffa335ee|Hitem:123::|h[Fine Sword]|h|r"
  local texture = "|TInterface\\Icons\\abc:0|t"
  local atlas = "|Aquest-icon:0:0|a"
  local text = "buy " .. link .. " now " .. texture .. atlas .. " ok"
  local expected = "BUY " .. link .. " NOW " .. texture .. atlas .. " OK"
  assert(PlainText.Map(text, upper) == expected, "escape sequences untouched, got " .. PlainText.Map(text, upper))
end

local function test_unclosed_link_runs_to_the_end()
  local text = "see |Hitem:1|h[open"
  assert(PlainText.Map(text, upper) == "SEE |Hitem:1|h[open", "an unclosed link is not mapped")
end

local function test_non_string_returned_unchanged()
  assert(PlainText.Map(nil, upper) == nil, "nil passes through")
end

return function()
  test_plain_text_is_mapped()
  test_escape_sequences_are_copied()
  test_unclosed_link_runs_to_the_end()
  test_non_string_returned_unchanged()
end
