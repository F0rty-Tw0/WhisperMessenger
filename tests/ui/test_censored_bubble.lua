local FakeUI = require("tests.helpers.fake_ui")
local BubbleFrame = require("WhisperMessenger.UI.ChatBubble.BubbleFrame")

return function()
  -- test_censored_bubble_shows_reveal_label
  do
    local factory = FakeUI.NewFactory()
    local contentFrame = factory.CreateFrame("Frame", nil, nil)
    contentFrame:SetSize(400, 600)

    local message = {
      direction = "in",
      kind = "user",
      text = "this is #### censored",
      sentAt = 1000,
      playerName = "Arthas",
      lineID = 201,
      isCensored = true,
    }

    local bubble = BubbleFrame.CreateBubble(factory, contentFrame, message, {
      paneWidth = 400,
      showIcon = false,
    })

    -- Should have a reveal label child
    assert(bubble.frame._censoredLabel ~= nil, "test_censored_indicator: expected _censoredLabel on censored bubble")
    local labelText = bubble.frame._censoredLabel:GetText()
    assert(
      labelText ~= nil and string.find(labelText, "click", 1, true),
      "test_censored_indicator: label should contain 'click' instruction, got: " .. tostring(labelText)
    )
  end

  -- test_uncensored_bubble_has_no_reveal_label
  do
    local factory = FakeUI.NewFactory()
    local contentFrame = factory.CreateFrame("Frame", nil, nil)
    contentFrame:SetSize(400, 600)

    local message = {
      direction = "in",
      kind = "user",
      text = "hello friend",
      sentAt = 1001,
      playerName = "Jaina",
      lineID = 202,
    }

    local bubble = BubbleFrame.CreateBubble(factory, contentFrame, message, {
      paneWidth = 400,
      showIcon = false,
    })

    assert(bubble.frame._censoredLabel == nil, "test_no_indicator: uncensored bubble should not have _censoredLabel")
  end

  -- test_click_censored_bubble_reveals_text
  do
    _G.C_ChatInfo = {
      UncensorChatLine = function(_lineID) end,
      GetChatLineText = function(lineID)
        if lineID == 301 then
          return "this is fully uncensored"
        end
        return nil
      end,
    }

    local factory = FakeUI.NewFactory()
    local contentFrame = factory.CreateFrame("Frame", nil, nil)
    contentFrame:SetSize(400, 600)

    local refreshCalled = false

    local message = {
      direction = "in",
      kind = "user",
      text = "this is #### censored",
      sentAt = 1002,
      playerName = "Thrall",
      lineID = 301,
      isCensored = true,
    }

    local bubble = BubbleFrame.CreateBubble(factory, contentFrame, message, {
      paneWidth = 400,
      showIcon = false,
      onRevealCensored = function()
        refreshCalled = true
      end,
    })

    -- Simulate left-click on the bubble
    assert(
      bubble.frame.scripts ~= nil and bubble.frame.scripts.OnMouseDown ~= nil,
      "test_reveal_click: expected OnMouseDown script"
    )
    bubble.frame.scripts.OnMouseDown(bubble.frame, "LeftButton")

    assert(message.isCensored ~= true, "test_reveal_click: expected isCensored to be cleared after click")
    assert(
      message.text == "this is fully uncensored",
      "test_reveal_click: expected message.text to be updated to uncensored text, got: " .. tostring(message.text)
    )
    assert(refreshCalled == true, "test_reveal_click: expected onRevealCensored callback to fire")

    _G.C_ChatInfo = nil
  end

  -- test_click_censored_bubble_fallback_when_api_returns_nil
  do
    _G.C_ChatInfo = {
      UncensorChatLine = function(_lineID) end,
      GetChatLineText = function(_lineID)
        return nil
      end,
    }

    local factory = FakeUI.NewFactory()
    local contentFrame = factory.CreateFrame("Frame", nil, nil)
    contentFrame:SetSize(400, 600)

    local message = {
      direction = "in",
      kind = "user",
      text = "this is #### still censored",
      sentAt = 1003,
      playerName = "Sylvanas",
      lineID = 401,
      isCensored = true,
    }

    local bubble = BubbleFrame.CreateBubble(factory, contentFrame, message, {
      paneWidth = 400,
      showIcon = false,
    })

    bubble.frame.scripts.OnMouseDown(bubble.frame, "LeftButton")

    -- Text should remain unchanged when API returns nil
    assert(
      message.text == "this is #### still censored",
      "test_fallback: text should be unchanged when GetChatLineText returns nil"
    )
    -- isCensored should still be cleared (we attempted reveal)
    assert(message.isCensored ~= true, "test_fallback: isCensored should be cleared even if text unchanged")

    _G.C_ChatInfo = nil
  end
end
