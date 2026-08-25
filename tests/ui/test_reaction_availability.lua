local FakeUI = require("tests.helpers.fake_ui")
local Layout = require("WhisperMessenger.UI.ChatBubble.Layout")
local BubbleFrame = require("WhisperMessenger.UI.ChatBubble.BubbleFrame")
local ReactionPicker = require("WhisperMessenger.UI.ChatBubble.ReactionPicker")

local function findBubble(contentFrame)
  for _, frame in ipairs(contentFrame._activeFrames or {}) do
    if frame._textFS then
      return frame
    end
  end
  return nil
end

return function()
  local savedCreateFrame = _G.CreateFrame
  local savedUIParent = _G.UIParent
  local savedClipboard = _G.C_Clipboard

  local factory = FakeUI.NewFactory()
  local uiParent = factory.CreateFrame("Frame", "UIParent", nil)
  local parent = factory.CreateFrame("Frame", nil, uiParent)
  parent:SetSize(400, 600)
  _G.CreateFrame = factory.CreateFrame
  _G.UIParent = uiParent

  local copiedText = nil
  _G.C_Clipboard = {
    SetClipboard = function(text)
      copiedText = text
    end,
  }

  local enabled = true
  local reactions = 0
  local message = {
    kind = "user",
    direction = "in",
    channel = "PARTY",
    text = "Group message",
    sentAt = 100,
    reaction = { key = "heart" },
  }

  Layout.LayoutMessages(factory, parent, { message }, 400, {
    canReact = function(receivedMessage)
      return enabled and receivedMessage == message
    end,
    onReact = function()
      reactions = reactions + 1
    end,
  })

  local bubble = findBubble(parent)
  assert(bubble and bubble._reactionFrame and bubble._reactionFrame.shown == true, "existing reaction badges must remain visible")

  bubble.scripts.OnMouseDown(bubble, "RightButton")
  local picker = ReactionPicker.GetFrame()
  assert(picker and picker.shown == true, "enabled reactions should open the picker")

  for _, legacyChannel in ipairs({ "WOW", "BN", "PARTY", "RAID", "INSTANCE_CHAT", "GUILD", "OFFICER" }) do
    local channellessMessage = {
      kind = "user",
      direction = "in",
      text = legacyChannel .. " message",
      sentAt = 100,
    }
    local policyAllows = true
    local channellessReactions = 0
    local channellessBubble = BubbleFrame.CreateBubble(factory, parent, channellessMessage, {
      paneWidth = 400,
      canReact = function(receivedMessage)
        return policyAllows and receivedMessage == channellessMessage
      end,
      onReact = function()
        channellessReactions = channellessReactions + 1
      end,
    })

    channellessBubble.frame.scripts.OnDoubleClick(channellessBubble.frame, "LeftButton")
    assert(channellessReactions == 1, legacyChannel .. " must react when the channel-less policy allows it")

    channellessBubble.frame.scripts.OnMouseDown(channellessBubble.frame, "RightButton")
    picker = ReactionPicker.GetFrame()
    assert(
      picker and picker.shown == true and picker._message == channellessMessage,
      legacyChannel .. " must open the picker when the channel-less policy allows it"
    )

    policyAllows = false
    channellessBubble.frame.scripts.OnDoubleClick(channellessBubble.frame, "LeftButton")
    assert(channellessReactions == 1, legacyChannel .. " must not react when the dynamic policy blocks it")

    copiedText = nil
    channellessBubble.frame.scripts.OnMouseDown(channellessBubble.frame, "RightButton")
    assert(picker.shown == false, legacyChannel .. " must close the picker when the dynamic policy blocks it")
    assert(copiedText == channellessMessage.text, legacyChannel .. " must retain Copy Text when the dynamic policy blocks it")
  end

  enabled = false
  bubble.scripts.OnDoubleClick(bubble, "LeftButton")
  assert(reactions == 0, "disabled reactions must not fire double-click actions")
  picker._reactionButtons[1].scripts.OnClick(picker._reactionButtons[1])
  assert(reactions == 0, "disabled reactions must not fire picker actions")

  _G.UIParent = nil
  bubble.scripts.OnMouseDown(bubble, "RightButton")
  assert(picker.shown == false, "disabled reactions must close an open picker")
  assert(copiedText == "Group message", "Copy Text must remain available while reactions are disabled")

  _G.CreateFrame = savedCreateFrame
  _G.UIParent = savedUIParent
  _G.C_Clipboard = savedClipboard
end
