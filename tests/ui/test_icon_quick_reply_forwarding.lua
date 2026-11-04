local FakeUI = require("tests.helpers.fake_ui")
local MinimapIcon = require("WhisperMessenger.UI.MinimapIcon.MinimapIcon")
local ToggleIcon = require("WhisperMessenger.UI.ToggleIcon")

-- Both icons pass their quickReply option and the preview meta on to the card.
return function()
  local function countingQuickReply()
    local counter = { isEnabled = 0 }
    local noop = function() end
    counter.quickReply = {
      isEnabled = function()
        counter.isEnabled = counter.isEnabled + 1
        return false
      end,
      getLockReasonText = noop,
      onSubmit = noop,
      onSaveDraft = noop,
      onDismissThrough = noop,
      onOpen = noop,
      onRefresh = noop,
    }
    return counter
  end

  local meta = { conversationKey = "wow::jaina", sentAt = 500, channel = "WOW" }

  local function test_widget_card_asks_the_quick_reply_table()
    local counter = countingQuickReply()
    local icon = ToggleIcon.Create(FakeUI.NewFactory(), { quickReply = counter.quickReply })
    icon.setIncomingPreview("Jaina", "hi", nil, meta)
    assert(counter.isEnabled >= 1, "the widget card asks isEnabled, got " .. counter.isEnabled)
  end

  local function test_minimap_card_asks_the_quick_reply_table()
    local factory = FakeUI.NewFactory()
    local parent = factory.CreateFrame("Frame", "Minimap", nil)
    parent:SetSize(140, 140)
    local counter = countingQuickReply()
    local icon = MinimapIcon.Create(factory, { parent = parent, quickReply = counter.quickReply })
    icon.setIncomingPreview("Jaina", "hi", nil, meta)
    assert(counter.isEnabled >= 1, "the minimap card asks isEnabled, got " .. counter.isEnabled)
  end

  test_widget_card_asks_the_quick_reply_table()
  test_minimap_card_asks_the_quick_reply_table()
end
