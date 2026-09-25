local ConversationPane = require("WhisperMessenger.UI.ConversationPane")
local ScrollView = require("WhisperMessenger.UI.ScrollView")
local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local Localization = require("WhisperMessenger.Locale.Localization")

-- Reply from a bubble reaches the window as a "reply" action for whispers
-- only; clicking a quote jumps to the original when it is still in history.
local function stubMenuUtil()
  local menu = { buttons = {} }
  rawset(_G, "MenuUtil", {
    CreateContextMenu = function(owner, generator)
      generator(owner, {
        CreateButton = function(_, text, callback)
          menu.buttons[text] = callback
        end,
      })
    end,
  })
  return menu
end

local function bubbleWithText(root, text)
  local label = FindUI.find(root, function(node)
    return node.frameType == "FontString" and node.text == text and node.parent.frameType == "Button" and node.parent._wmMessage ~= nil
  end)
  return label and label.parent
end

return function()
  Localization.Configure({ language = "enUS" })
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "Parent", nil)
  parent:SetSize(600, 420)
  local calls = {}
  local pane = ConversationPane.Create(factory, parent, nil, nil, {
    onMessageAction = function(contact, message, action)
      calls[#calls + 1] = { contact = contact, message = message, action = action }
    end,
  })

  -- test_reply_menu_for_whispers_only
  do
    local menu = stubMenuUtil()
    local contact = { conversationKey = "wow::thrall", displayName = "Thrall", channel = "WOW" }
    local message = { id = "1", direction = "out", kind = "user", text = "yo", sentAt = 1 }
    ConversationPane.Refresh(pane, contact, { messages = { message } })
    local bubble = assert(bubbleWithText(pane.frame, "yo"), "bubble rendered")
    bubble.scripts.OnMouseDown(bubble, "RightButton")
    assert(menu.buttons.Reply ~= nil, "Reply offered in a whisper")
    menu.buttons.Reply()
    assert(calls[1].action == "reply" and calls[1].message == message and calls[1].contact == contact, "reply action forwarded")

    menu.buttons = {}
    ConversationPane.Refresh(pane, { conversationKey = "party", displayName = "Party", channel = "PARTY" }, { messages = { message } })
    bubble = assert(bubbleWithText(pane.frame, "yo"), "bubble rendered")
    bubble.scripts.OnMouseDown(bubble, "RightButton")
    assert(menu.buttons.Reply == nil, "no Reply in group chats")
    rawset(_G, "MenuUtil", nil)
  end

  -- test_quote_click_scrolls_to_the_original
  do
    local contact = { conversationKey = "wow::jaina", displayName = "Jaina", channel = "WOW" }
    local messages = {}
    for index = 1, 40 do
      messages[index] = {
        id = tostring(index),
        direction = index % 2 == 0 and "out" or "in",
        kind = "user",
        text = "line " .. index,
        sentAt = index * 200,
        playerName = "Jaina",
      }
    end
    messages[40].replyTo = { id = "1", direction = "in", author = "Jaina", snippet = "line 1" }
    ConversationPane.Refresh(pane, contact, { messages = messages })
    local transcript = pane.transcript
    assert(ScrollView.GetOffset(transcript) > 0, "opens at the end")
    local quote = FindUI.find(pane.frame, function(node)
      return node.frameType == "FontString"
        and type(node.text) == "string"
        and string.find(node.text, "line 1", 1, true)
        and node.parent._wmReplyTo ~= nil
    end)
    assert(quote ~= nil, "quote rendered")
    FindUI.click(quote.parent)
    assert(ScrollView.GetOffset(transcript) == 0, "jumped to the original, offset " .. tostring(ScrollView.GetOffset(transcript)))
  end
end
