local FakeUI = require("tests.helpers.fake_ui")
local UIHelpers = require("WhisperMessenger.UI.Helpers")

local ELLIPSIS = "..."

-- True when a "|c" is not followed by 8 hex digits ("||" is a literal pipe).
local function hasBrokenEscape(s)
  local i = 1
  while i <= #s do
    local pair = string.sub(s, i, i + 1)
    if pair == "||" then
      i = i + 2
    elseif pair == "|c" then
      if not string.find(s, "^|c%x%x%x%x%x%x%x%x", i) then
        return true
      end
      i = i + 10
    else
      i = i + 1
    end
  end
  return false
end

local function visibleText(s)
  local plain = string.gsub(s, "|c%x%x%x%x%x%x%x%x", "")
  plain = string.gsub(plain, "|r", "")
  if string.sub(plain, -#ELLIPSIS) == ELLIPSIS then
    plain = string.sub(plain, 1, -#ELLIPSIS - 1)
  end
  return plain
end

return function()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", nil, nil)
  local label = parent:CreateFontString(nil, "OVERLAY")

  -- test_colour_escape_is_never_split

  do
    local text = "|cffff0000Level 80|r Shaman"
    for maxWidth = 7, #text * 7 do
      local result = UIHelpers.fitTextWithEllipsis(label, text, maxWidth)
      assert(not hasBrokenEscape(result), "width " .. maxWidth .. " split an escape: " .. result)
      assert(string.sub(result, -4, -4) ~= "|", "width " .. maxWidth .. " left a lone pipe: " .. result)
      local cutInsideColour = string.find(result, "|cffff0000", 1, true) and #visibleText(result) < #"Level 80"
      if cutInsideColour then
        assert(string.sub(result, -5) == "|r" .. ELLIPSIS, "width " .. maxWidth .. " left the colour open: " .. result)
      end
    end
  end

  -- test_plain_text_cuts_as_before

  do
    local text = "Thrall-Draenor  -  Shaman"
    assert(UIHelpers.fitTextWithEllipsis(label, text, 30) == "T...", "width 30 keeps one character")
    assert(UIHelpers.fitTextWithEllipsis(label, text, 60) == "Thral...", "width 60 keeps five characters")
    assert(UIHelpers.fitTextWithEllipsis(label, text, 100) == "Thrall-Drae...", "width 100 keeps eleven characters")
  end

  -- test_literal_pipe_is_never_split

  do
    local text = "a||b long text"
    for maxWidth = 7, #text * 7 do
      local result = UIHelpers.fitTextWithEllipsis(label, text, maxWidth)
      local withoutPairs = string.gsub(result, "||", "")
      assert(not string.find(withoutPairs, "|", 1, true), "width " .. maxWidth .. " split a literal pipe: " .. result)
    end
  end
end
