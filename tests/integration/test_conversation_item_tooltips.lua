local ConversationPane = require("WhisperMessenger.UI.ConversationPane")
local FakeUI = require("tests.helpers.fake_ui")

return function()
  local savedSetItemRef = _G.SetItemRef
  local setItemRefCall = nil

  _G.SetItemRef = function(link, text, button, chatFrame)
    setItemRefCall = {
      link = link,
      text = text,
      button = button,
      chatFrame = chatFrame,
    }
  end

  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "TooltipParent", nil)
  parent:SetSize(600, 420)

  local itemLink = "|cff0070dd|Hitem:19019::::::::|h[Thunderfury, Blessed Blade of the Windseeker]|h|r"
  local pane = ConversationPane.Create(factory, parent, {
    displayName = "Arthas-Area52",
  }, {
    messages = {
      {
        direction = "in",
        kind = "user",
        text = itemLink,
      },
    },
  })

  local bubble
  for _, frame in ipairs(pane.transcript.content._activeFrames or {}) do
    if frame._textFS and frame._wmMessage and frame._wmMessage.text == itemLink then
      bubble = frame
    end
  end
  assert(bubble ~= nil, "expected a bubble for the item link message")
  assert(bubble._textFS:GetText() == itemLink, "expected the bubble to show the item link")
  assert(type(bubble.scripts.OnHyperlinkClick) == "function", "expected the bubble to handle hyperlink clicks")

  bubble.scripts.OnHyperlinkClick(bubble, "item:19019::::::::", itemLink, "LeftButton")

  assert(setItemRefCall ~= nil, "expected item link click to invoke SetItemRef")
  assert(setItemRefCall.link == "item:19019::::::::")
  assert(setItemRefCall.text == itemLink)
  assert(setItemRefCall.button == "LeftButton")

  _G.SetItemRef = savedSetItemRef
end
