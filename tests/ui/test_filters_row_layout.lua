local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local Fonts = require("WhisperMessenger.UI.Theme.Fonts")
local Localization = require("WhisperMessenger.Locale.Localization")
local FiltersSettings = require("WhisperMessenger.UI.MessengerWindow.FiltersSettings")

-- Filters page rows: the name on one truncated line, the session count on a
-- smaller line below, and a row height that grows with the font size.
local NOW = 1000000
local BASE_ROW = Theme.LAYOUT.FILTER_ROW_HEIGHT

local function create(filters)
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  return FiltersSettings.Create(factory, parent, { filters = filters }, { onChange = function() end })
end

local function visibleText(root, text)
  return FindUI.find(root, function(node)
    return node.frameType == "FontString" and node.text == text and node.parent:IsShown()
  end)
end

local function ruleFilters()
  return {
    ignored = {},
    rules = {
      { name = "Mythic+ and raid sellers", words = { "wts" }, enabled = true, blocked = 5 },
      { words = { "gold" }, enabled = true, blocked = 0 },
    },
  }
end

local function ignoreFilters()
  return {
    ignored = {
      bob = { name = "Bob", addedAt = NOW, blocked = 3, reason = "gold spam", lastText = "cheap gold", lastChannel = "CHAT_MSG_WHISPER" },
      kim = { name = "Kim", addedAt = NOW, blocked = 0 },
    },
    rules = {},
  }
end

return function()
  Localization.Configure({ language = "enUS" })
  rawset(_G, "time", function()
    return NOW
  end)

  -- test_filter_row_height_grows_two_px_per_font_px
  Fonts.SetFontSize(12)
  assert(Theme.FilterRowHeight() == BASE_ROW, "12px font keeps the base row")
  Fonts.SetFontSize(17)
  assert(Theme.FilterRowHeight() == BASE_ROW + 10, "17px font adds 10px, got " .. Theme.FilterRowHeight())
  Fonts.SetFontSize(12)

  -- test_rule_name_is_one_truncated_line
  do
    local result = create(ruleFilters())
    local name = assert(visibleText(result.frame, "Mythic+ and raid sellers"), "rule name shown")
    assert(name.wordWrap == false, "rule name does not wrap")
    assert(name.maxLines == 1, "rule name keeps to one line")
    local row = name.parent:GetParent()
    assert(name.width < row.width, "rule name stops short of the row's controls")
  end

  -- test_rule_count_line_says_this_session
  do
    local result = create(ruleFilters())
    assert(visibleText(result.frame, "Blocked 5 this session") ~= nil, "rule session count shown")
    assert(visibleText(result.frame, "Blocked 5") == nil, "old count text gone")
  end

  -- test_rule_rows_grow_at_a_big_font
  do
    Fonts.SetFontSize(17)
    local result = create(ruleFilters())
    local first = visibleText(result.frame, "Mythic+ and raid sellers").parent:GetParent()
    local second = visibleText(result.frame, "gold").parent:GetParent()
    Fonts.SetFontSize(12)
    assert(first.height == BASE_ROW + 10, "rule row grows with the font, got " .. tostring(first.height))
    local _, _, _, _, secondY = second:GetPoint()
    assert(secondY == -(BASE_ROW + 10), "next rule sits one grown row lower, got " .. tostring(secondY))
  end

  -- test_ignore_name_is_one_truncated_line
  do
    local result = create(ignoreFilters())
    local name = assert(visibleText(result.frame, "Bob"), "player name shown")
    assert(name.wordWrap == false, "player name does not wrap")
    assert(name.maxLines == 1, "player name keeps to one line")
  end

  -- test_ignore_second_line_leads_with_the_session_count
  do
    local result = create(ignoreFilters())
    local detail = "Blocked 3 this session - gold spam - Last: [Whisper] cheap gold"
    assert(visibleText(result.frame, detail) ~= nil, "count, reason and last line share the second line")
    assert(visibleText(result.frame, "Blocked 0 this session") ~= nil, "a player with no reason shows the count alone")
  end

  -- test_ignore_rows_grow_at_a_big_font
  do
    Fonts.SetFontSize(17)
    local result = create(ignoreFilters())
    local first = visibleText(result.frame, "Bob").parent
    local second = visibleText(result.frame, "Kim").parent
    Fonts.SetFontSize(12)
    assert(first.height == BASE_ROW + 10, "ignore row grows with the font, got " .. tostring(first.height))
    local _, _, _, _, secondY = second:GetPoint()
    assert(secondY == -(BASE_ROW + 10), "next player sits one grown row lower, got " .. tostring(secondY))
  end

  rawset(_G, "time", nil)
end
