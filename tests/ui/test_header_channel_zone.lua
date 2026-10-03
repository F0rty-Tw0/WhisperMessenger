local FakeUI = require("tests.helpers.fake_ui")
local GroupHeaderViewModel = require("WhisperMessenger.UI.ConversationPane.GroupHeaderViewModel")
local HeaderView = require("WhisperMessenger.UI.ConversationPane.HeaderView")

local function generalChat()
  return { conversationKey = "channel::me-realm::general", displayName = "General", channel = "CHANNEL" }
end

return function()
  -- test_zone_channel_header_names_its_zone
  do
    local vm = assert(GroupHeaderViewModel.Build(generalChat(), { channel = "CHANNEL", lastZoneLabel = "Durotar" }))
    assert(vm.statusText == "Durotar", "General shows its zone under the name, got " .. tostring(vm.statusText))
  end

  -- test_channel_without_a_zone_has_no_status
  do
    local vm = assert(GroupHeaderViewModel.Build(generalChat(), { channel = "CHANNEL" }))
    assert(vm.statusText == nil, "no zone, no status line")
  end

  -- test_header_status_line_shows_the_zone
  do
    local factory = FakeUI.NewFactory()
    local pane = factory.CreateFrame("Frame", nil, nil)
    pane:SetSize(600, 420)
    local contact = generalChat()
    local view = HeaderView.Create(factory, pane, contact)
    HeaderView.Refresh(view, contact, { channel = "CHANNEL", lastZoneLabel = "Durotar" }, nil)
    assert(
      view.headerStatus.shown ~= false and view.headerStatus.text == "Durotar",
      "status line reads Durotar, got " .. tostring(view.headerStatus.text)
    )
    assert(view.headerStatusDetail.shown == false, "no second status line")
    assert(view.headerStatusDot.shown == false, "no presence dot for a channel")
  end
end
