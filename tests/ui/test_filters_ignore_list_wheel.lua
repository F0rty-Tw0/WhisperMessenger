local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local Localization = require("WhisperMessenger.Locale.Localization")
local FiltersSettings = require("WhisperMessenger.UI.MessengerWindow.FiltersSettings")
local IgnoreListSection = require("WhisperMessenger.UI.MessengerWindow.FiltersSettings.IgnoreListSection")

local NOW = 1000000

local function create(count)
  local filters = { ignored = {}, rules = {} }
  for index = 1, count do
    local name = string.format("Player%03d", index)
    filters.ignored[string.lower(name)] = { name = name, addedAt = NOW, blocked = 0 }
  end
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  return FiltersSettings.Create(factory, parent, { filters = filters }, { onChange = function() end }), filters
end

local function ignoreList(result)
  local label = assert(
    FindUI.find(result.frame, function(node)
      return node.frameType == "FontString" and node.text == "Player001"
    end),
    "expected the first ignored player's row"
  )
  return label.parent:GetParent()
end

return function()
  Localization.Configure({ language = "enUS" })
  rawset(_G, "time", function()
    return NOW
  end)

  -- test_short_ignore_list_leaves_the_wheel_to_the_page
  do
    -- A list that can't scroll must not swallow the wheel when the page
    -- scrolls it under a still cursor.
    local list = ignoreList(create(2))
    assert(list.mouseWheelEnabled == false, "a list that fits takes no wheel")
  end

  -- test_long_ignore_list_scrolls_with_the_wheel
  do
    local list = ignoreList(create(IgnoreListSection.VISIBLE_ROWS + 1))
    assert(list.mouseWheelEnabled == true, "an overflowing list scrolls with the wheel")
  end
end
