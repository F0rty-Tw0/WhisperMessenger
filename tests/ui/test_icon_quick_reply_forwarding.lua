local FakeUI = require("tests.helpers.fake_ui")
local MinimapIcon = require("WhisperMessenger.UI.MinimapIcon.MinimapIcon")
local ToggleIcon = require("WhisperMessenger.UI.ToggleIcon")

-- Both icons pass their quickReply option and the preview meta on to the card.
-- The lock check runs only once a reply row is applied, and that needs the meta.
return function()
  local function countingQuickReply()
    local counter = { lockChecks = 0 }
    local noop = function() end
    counter.quickReply = {
      isEnabled = function()
        return true
      end,
      getLockReasonText = function()
        counter.lockChecks = counter.lockChecks + 1
        return nil
      end,
      onSubmit = noop,
      onSaveDraft = noop,
      onDismissThrough = noop,
      onOpen = noop,
      onRefresh = noop,
    }
    return counter
  end

  local meta = { conversationKey = "wow::jaina", sentAt = 500, channel = "WOW" }

  local function test_widget_card_gets_the_quick_reply_table_and_meta()
    local counter = countingQuickReply()
    local icon = ToggleIcon.Create(FakeUI.NewFactory(), { quickReply = counter.quickReply })
    icon.setIncomingPreview("Jaina", "hi", nil, meta)
    assert(counter.lockChecks >= 1, "the widget card applies a reply row, got " .. counter.lockChecks)
  end

  local function test_minimap_card_gets_the_quick_reply_table_and_meta()
    local factory = FakeUI.NewFactory()
    local parent = factory.CreateFrame("Frame", "Minimap", nil)
    parent:SetSize(140, 140)
    local counter = countingQuickReply()
    local icon = MinimapIcon.Create(factory, { parent = parent, quickReply = counter.quickReply })
    icon.setIncomingPreview("Jaina", "hi", nil, meta)
    assert(counter.lockChecks >= 1, "the minimap card applies a reply row, got " .. counter.lockChecks)
  end

  local function test_card_without_meta_shows_no_reply_row()
    local counter = countingQuickReply()
    local icon = ToggleIcon.Create(FakeUI.NewFactory(), { quickReply = counter.quickReply })
    icon.setIncomingPreview("Jaina", "hi", nil, nil)
    assert(counter.lockChecks == 0, "no meta, no reply row, got " .. counter.lockChecks)
  end

  test_widget_card_gets_the_quick_reply_table_and_meta()
  test_minimap_card_gets_the_quick_reply_table_and_meta()
  test_card_without_meta_shows_no_reply_row()
end
