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

  assert(pane.transcript.text:GetText() == itemLink)
  assert(pane.transcript.text.fontObject ~= nil, "expected transcript text to configure a font object")
  assert(pane.transcript.text.hyperlinksEnabled == true, "expected transcript text to enable hyperlinks")
  assert(
    type(pane.transcript.text.scripts.OnHyperlinkClick) == "function",
    "expected transcript text to handle hyperlink clicks"
  )

  pane.transcript.text.scripts.OnHyperlinkClick(pane.transcript.text, "item:19019::::::::", itemLink, "LeftButton")

  assert(setItemRefCall ~= nil, "expected item link click to invoke SetItemRef")
  assert(setItemRefCall.link == "item:19019::::::::")
  assert(setItemRefCall.text == itemLink)
  assert(setItemRefCall.button == "LeftButton")

  _G.SetItemRef = savedSetItemRef
end
