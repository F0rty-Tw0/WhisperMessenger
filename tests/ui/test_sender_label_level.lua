local FakeUI = require("tests.helpers.fake_ui")
local DisplayName = require("WhisperMessenger.Util.DisplayName")
local Localization = require("WhisperMessenger.Locale.Localization")
local SenderLabel = require("WhisperMessenger.UI.ChatBubble.SenderLabel")

local function nameText(result)
  return result.frame._wmSenderNameFS:GetText()
end

local function stubDifficulty(fn)
  _G.GetQuestDifficultyColor = fn
end

return function()
  local savedDifficulty = _G.GetQuestDifficultyColor
  stubDifficulty(function(_level)
    return { r = 1, g = 1, b = 0 }
  end)
  Localization.Configure({ language = "enUS" })

  local factory = FakeUI.NewFactory()
  local contentFrame = factory.CreateFrame("Frame", nil, nil)
  contentFrame:SetSize(400, 600)

  local function render(message, renderFactory)
    return SenderLabel.CreateSenderLabel(renderFactory or factory, contentFrame, message, 400, 0)
  end

  -- test_option_on_prefixes_coloured_level

  do
    DisplayName.Configure({ showPlayerLevels = true })
    local result = render({ direction = "in", playerName = "Nergrom", senderLevel = 20 })
    assert(nameText(result) == "|cffffff0020|r:Nergrom", "got: " .. tostring(nameText(result)))
  end

  -- test_option_off_shows_plain_name

  do
    DisplayName.Configure({ showPlayerLevels = false })
    local result = render({ direction = "in", playerName = "Nergrom", senderLevel = 20 })
    assert(nameText(result) == "Nergrom", "got: " .. tostring(nameText(result)))
  end

  -- test_option_on_without_level_shows_plain_name

  do
    DisplayName.Configure({ showPlayerLevels = true })
    local result = render({ direction = "in", playerName = "Nergrom" })
    assert(nameText(result) == "Nergrom", "got: " .. tostring(nameText(result)))
  end

  -- test_reused_frame_drops_the_level_prefix

  do
    DisplayName.Configure({ showPlayerLevels = true })
    local shared = factory.CreateFrame("Frame", nil, contentFrame)
    local sameFrameFactory = {
      CreateFrame = function()
        return shared
      end,
    }
    local first = render({ direction = "in", playerName = "Nergrom", senderLevel = 20 }, sameFrameFactory)
    assert(nameText(first) == "|cffffff0020|r:Nergrom", "first render shows the level")
    local second = render({ direction = "in", playerName = "Nergrom" }, sameFrameFactory)
    assert(second.frame == first.frame, "expected the same frame on both renders")
    assert(nameText(second) == "Nergrom", "a reused frame drops the level prefix, got: " .. tostring(nameText(second)))
  end

  -- test_outgoing_label_is_unchanged

  do
    DisplayName.Configure({ showPlayerLevels = true })
    local result = render({ direction = "out", senderLevel = 20 })
    assert(nameText(result) == "You", "got: " .. tostring(nameText(result)))
  end

  DisplayName.Configure({ showPlayerLevels = false })
  stubDifficulty(savedDifficulty)
end
