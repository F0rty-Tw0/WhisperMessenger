local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local Fonts = require("WhisperMessenger.UI.Theme.Fonts")
local Localization = require("WhisperMessenger.Locale.Localization")
local FiltersSettings = require("WhisperMessenger.UI.MessengerWindow.FiltersSettings")
local IgnoreRow = require("WhisperMessenger.UI.MessengerWindow.FiltersSettings.IgnoreRow")
local BehaviorSettings = require("WhisperMessenger.UI.MessengerWindow.BehaviorSettings")

-- Text the player typed into the settings lists (rule names, blocked players
-- and reasons, quick replies) shows "ő" or "ű" in the chat font.
local function label(root, text)
  return FindUI.find(root, function(node)
    return node.frameType == "FontString" and node.text == text
  end)
end

local function isWide(fontString)
  local font = fontString and fontString:GetFontObject()
  return font ~= nil and font.name ~= nil and string.find(font.name, "_Wide$") ~= nil
end

return function()
  Localization.Configure({ language = "enUS" })
  Fonts.Initialize("default")
  local factory = FakeUI.NewFactory({ fontColors = true })
  local parent = factory.CreateFrame("Frame", "UIParent", nil)

  -- test_keyword_rule_name_uses_the_wide_font
  do
    local filters = { ignored = {}, rules = { { name = "ő/ű", words = { "ő" }, enabled = true, blocked = 0 } } }
    local result = FiltersSettings.Create(factory, parent, { filters = filters }, { onChange = function() end })
    assert(isWide(label(result.frame, "ő/ű")), "the rule name needs the chat font")
  end

  -- test_blocked_player_name_and_reason_use_the_wide_font
  do
    local row = IgnoreRow.Create(factory, factory.CreateFrame("Frame", nil, parent), function() end)
    IgnoreRow.Bind(row, { name = "Kőszívű", blocked = 0, reason = "szőr" }, "kőszívű")
    assert(isWide(row.nameText), "the player name needs the chat font")
    assert(isWide(row.detailText), "the reason needs the chat font")
  end

  -- test_quick_reply_row_uses_the_wide_font
  do
    local result = BehaviorSettings.Create(factory, parent, { quickReplies = { "Szép napot ő" } }, { onChange = function() end })
    assert(isWide(label(result.frame, "Szép napot ő")), "the quick reply needs the chat font")
  end
end
