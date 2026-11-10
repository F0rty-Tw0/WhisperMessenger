local ChannelContextMerger = require("WhisperMessenger.UI.ConversationPane.ChannelContextMerger")
local ConversationPane = require("WhisperMessenger.UI.ConversationPane")
local FakeUI = require("tests.helpers.fake_ui")

-- The pane asks its view, live on every refresh, whether the channel line is
-- shown. A view without the hook keeps showing it.
return function()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", nil, nil)
  parent:SetSize(600, 420)
  local pane = ConversationPane.Create(factory, parent, nil, nil)
  local contact = { conversationKey = "wow::WOW::arthas", channel = "WOW", displayName = "Arthas" }

  local realForPane = ChannelContextMerger.ForPane
  local seenEnabled
  ChannelContextMerger.ForPane = function(messages, selectedContact, conversation, enabled)
    seenEnabled = enabled
    return realForPane(messages, selectedContact, conversation, enabled)
  end

  local function refreshSeen()
    seenEnabled = "unset"
    ConversationPane.Refresh(pane, contact, { messages = {} })
    return seenEnabled
  end

  -- test_view_without_hook_keeps_channel_context_shown
  pane.isChannelContextShown = nil
  assert(refreshSeen() == true, "a view without isChannelContextShown shows the channel line")

  -- test_view_hook_off_hides_channel_context
  local shown = false
  pane.isChannelContextShown = function()
    return shown
  end
  assert(refreshSeen() == false, "isChannelContextShown() == false turns the channel line off")

  -- test_view_hook_is_read_on_every_refresh
  shown = true
  assert(refreshSeen() == true, "flipping the setting back on shows the line on the next refresh")

  ChannelContextMerger.ForPane = realForPane
end
