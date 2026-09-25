local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local ContextMenu = require("WhisperMessenger.UI.ChatBubble.ContextMenu")
local ReactionPicker = require("WhisperMessenger.UI.ChatBubble.ReactionPicker")
local BubbleFrame = require("WhisperMessenger.UI.ChatBubble.BubbleFrame")
local Localization = require("WhisperMessenger.Locale.Localization")

-- Right-clicking a bubble offers "Reply": in the reaction picker for
-- incoming whispers, in a small context menu otherwise.

local function stubMenuUtil()
  local menu = { buttons = {} }
  rawset(_G, "MenuUtil", {
    CreateContextMenu = function(owner, generator)
      menu.owner = owner
      generator(owner, {
        CreateButton = function(_, text, callback)
          menu.buttons[#menu.buttons + 1] = { text = text, callback = callback }
        end,
      })
    end,
  })
  return menu
end

local function menuButton(menu, text)
  for _, button in ipairs(menu.buttons) do
    if button.text == text then
      return button
    end
  end
  return nil
end

return function()
  Localization.Configure({ language = "enUS" })
  local factory = FakeUI.NewFactory()
  local savedUIParent = _G.UIParent
  _G.UIParent = factory.CreateFrame("Frame", "UIParent", nil)
  rawset(_G, "CreateFrame", factory.CreateFrame)
  local anchor = factory.CreateFrame("Frame", nil, _G.UIParent)
  local incoming = { direction = "in", kind = "user", text = "hi", channel = "WOW" }
  local outgoing = { direction = "out", kind = "user", text = "yo", channel = "WOW" }

  -- test_reaction_picker_offers_reply
  do
    local replied = {}
    ReactionPicker.Open(factory, anchor, incoming, function() end, function() end, nil, function(message)
      replied[#replied + 1] = message
    end)
    local picker = ReactionPicker.GetFrame()
    local reply = FindUI.byLabel(picker, "Reply")
    assert(reply.shown ~= false, "Reply shown in the picker")
    FindUI.click(reply)
    assert(replied[1] == incoming, "Reply reports the message")
    assert(picker.shown == false, "picker closes")

    ReactionPicker.Open(factory, anchor, incoming, function() end, function() end)
    assert(FindUI.byLabel(picker, "Reply").shown == false, "no Reply without a reply handler")
    ReactionPicker.Close()
  end

  -- test_outgoing_bubble_menu_offers_reply_and_copy
  do
    local menu = stubMenuUtil()
    local replied = 0
    assert(ContextMenu.Open("yo", anchor, {
      message = outgoing,
      onReply = function()
        replied = replied + 1
      end,
    }) == true, "menu opened")
    assert(menuButton(menu, "Reply") ~= nil and menuButton(menu, "Copy text") ~= nil, "Reply + Copy text")
    menuButton(menu, "Reply").callback()
    assert(replied == 1, "Reply invoked")
    rawset(_G, "MenuUtil", nil)
  end

  -- test_bubble_right_click_wires_reply_for_eligible_messages
  do
    local menu = stubMenuUtil()
    local replied = {}
    local bubble = BubbleFrame.CreateBubble(factory, anchor, outgoing, {
      persistentFactory = factory,
      canReply = function()
        return true
      end,
      onReply = function(message)
        replied[#replied + 1] = message
      end,
    })
    bubble.frame.scripts.OnMouseDown(bubble.frame, "RightButton")
    menuButton(menu, "Reply").callback()
    assert(replied[1] == outgoing, "bubble reply forwards its message")

    menu.buttons = {}
    local groupBubble = BubbleFrame.CreateBubble(factory, anchor, outgoing, {
      persistentFactory = factory,
      canReply = function()
        return false
      end,
      onReply = function() end,
    })
    groupBubble.frame.scripts.OnMouseDown(groupBubble.frame, "RightButton")
    assert(menuButton(menu, "Reply") == nil, "no Reply where replies are not allowed")
    rawset(_G, "MenuUtil", nil)
  end

  _G.UIParent = savedUIParent
end
