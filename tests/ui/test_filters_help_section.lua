local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local Localization = require("WhisperMessenger.Locale.Localization")
local FiltersSettings = require("WhisperMessenger.UI.MessengerWindow.FiltersSettings")

local HELP_TITLE = "How filters work"
local HELP_LINES = {
  "Blocked players: their whispers, group and channel messages are hidden in WhisperMessenger, and their say, yell, emote and channel messages in the game's chat too.",
  "Keyword rules: hide matching group and channel messages in WhisperMessenger, and matching channel messages in the game's chat. Never whispers or your own messages.",
  "Ready-made rules only filter channels such as Trade, never group chats.",
  "WhisperMessenger never hides anything from the game's chat in Mythic+, boss fights or PvP.",
  "gold + cheap: both words must appear, in any order.",
  "wts/wtb: either word is enough.",
  '"lf": whole word only, so "half" doesn\'t match.',
}
local OLD_SYNTAX_HINT = 'Words joined by + must all appear; words split by / need only one; "quoted" words match whole words only'
local CLICK_HINT = "Click a rule to edit its words."

local function create()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  return FiltersSettings.Create(factory, parent, { filters = { ignored = {}, rules = {} } }, { onChange = function() end })
end

local function startsWith(root, prefix)
  return FindUI.find(root, function(node)
    return node.frameType == "FontString" and type(node.text) == "string" and string.sub(node.text, 1, #prefix) == prefix
  end)
end

return function()
  Localization.Configure({ language = "enUS" })

  -- test_help_block_lists_every_line
  do
    local result = create()
    assert(FindUI.text(result.frame, HELP_TITLE) ~= nil, "help title shown")
    for _, line in ipairs(HELP_LINES) do
      assert(FindUI.text(result.frame, line) ~= nil, "help line shown: " .. line)
    end
  end

  -- test_help_block_sits_above_ignored_players
  do
    local result = create()
    local ignoredTitle = assert(startsWith(result.frame, "Blocked players ("), "ignored players title")
    local lastLine = FindUI.text(result.frame, HELP_LINES[#HELP_LINES])
    assert(ignoredTitle.point[2] == lastLine, "ignored players hangs below the last help line")
  end

  -- test_help_lines_wrap_to_the_page_width
  do
    local result = create()
    for _, line in ipairs(HELP_LINES) do
      local fontString = assert(FindUI.text(result.frame, line), "help line: " .. line)
      assert(fontString.wordWrap == true, "help line wraps: " .. line)
      assert(fontString.width == Theme.LAYOUT.SETTINGS_CONTROL_WIDTH, "help line spans the page")
    end
    result.refreshLayout(200)
    for _, line in ipairs(HELP_LINES) do
      assert(FindUI.text(result.frame, line).width == 200, "help line follows the page width")
    end
  end

  -- test_syntax_hint_replaced_by_click_to_edit
  do
    local result = create()
    assert(FindUI.text(result.frame, OLD_SYNTAX_HINT) == nil, "syntax is not stated twice")
    assert(FindUI.text(result.frame, CLICK_HINT) ~= nil, "rules say click to edit")
  end

  -- test_set_language_translates_help_block
  do
    local result = create()
    Localization.Configure({ language = "deDE" })
    result.setLanguage()
    assert(Localization.Text(HELP_TITLE) ~= HELP_TITLE, "help title has a German translation")
    assert(FindUI.text(result.frame, Localization.Text(HELP_TITLE)) ~= nil, "help title switches language")
    for _, line in ipairs(HELP_LINES) do
      assert(Localization.Text(line) ~= line, "help line has a German translation: " .. line)
      assert(FindUI.text(result.frame, Localization.Text(line)) ~= nil, "help line switches language: " .. line)
    end
    assert(FindUI.text(result.frame, Localization.Text(CLICK_HINT)) ~= nil, "click hint switches language")
    Localization.Configure({ language = "enUS" })
  end
end
