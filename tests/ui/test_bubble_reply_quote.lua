local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local BubbleFrame = require("WhisperMessenger.UI.ChatBubble.BubbleFrame")
local Layout = require("WhisperMessenger.UI.ChatBubble.Layout")
local Localization = require("WhisperMessenger.Locale.Localization")
local Theme = require("WhisperMessenger.UI.Theme")

-- A reply renders a compact quote (accent bar + author + dim snippet) above
-- the bubble text; clicking it asks the transcript to jump to the original.

local function findQuoteText(root)
  return FindUI.find(root, function(node)
    return node.frameType == "FontString" and type(node.text) == "string" and string.find(node.text, "you coming?", 1, true) ~= nil
  end)
end

return function()
  Localization.Configure({ language = "enUS" })
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", nil, nil)
  parent:SetSize(400, 600)
  local replyTo = { wireId = "w1", direction = "in", author = "Thrall", snippet = "you coming?" }
  local plainMessage = { direction = "out", kind = "user", text = "on my way" }
  local replyMessage = { direction = "out", kind = "user", text = "on my way", replyTo = replyTo }

  -- test_reply_bubble_shows_the_quote_above_the_text
  local clicked = {}
  local plain = BubbleFrame.CreateBubble(factory, parent, plainMessage, { persistentFactory = factory })
  local plainHeight = plain.height
  local reply = BubbleFrame.CreateBubble(factory, parent, replyMessage, {
    persistentFactory = factory,
    onQuoteClick = function(target)
      clicked[#clicked + 1] = target
    end,
  })
  local quoteText = findQuoteText(reply.frame)
  assert(quoteText ~= nil and quoteText.shown ~= false, "quote snippet shown")
  assert(string.find(quoteText.text, "Thrall", 1, true), "author named: " .. quoteText.text)
  assert(reply.height > plainHeight, "quote adds height")
  assert(reply.text.point[5] < -Theme.LAYOUT.BUBBLE_PADDING_V, "text sits below the quote")

  -- test_quote_click_reports_the_original
  local quoteButton = quoteText.parent
  FindUI.click(quoteButton)
  assert(clicked[1] == replyTo, "click reports the quoted message")

  -- test_own_message_quote_reads_you
  replyTo.author = nil
  replyTo.direction = "out"
  local own = BubbleFrame.CreateBubble(factory, parent, replyMessage, { persistentFactory = factory })
  assert(string.find(findQuoteText(own.frame).text, "You", 1, true), "own message: You")

  -- test_recycled_bubble_hides_the_quote
  local pooledFactory = {
    CreateFrame = function(frameType, name, frameParent)
      if frameType == "Button" and frameParent == parent then
        return own.frame
      end
      return factory.CreateFrame(frameType, name, frameParent)
    end,
  }
  BubbleFrame.CreateBubble(pooledFactory, parent, plainMessage, { persistentFactory = factory })
  assert(findQuoteText(own.frame).parent.shown == false, "reused frame drops the quote")

  -- test_row_estimate_accounts_for_the_quote
  local withQuote = Layout.EstimateRowHeight(nil, replyMessage, 400, true)
  local without = Layout.EstimateRowHeight(nil, plainMessage, 400, true)
  assert(withQuote > without, "estimate grows with a quote")
end
