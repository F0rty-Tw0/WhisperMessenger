local FakeUI = require("tests.helpers.fake_ui")
local HeaderView = require("WhisperMessenger.UI.ConversationPane.HeaderView")

return function()
  local factory = FakeUI.NewFactory()
  local pane = factory.CreateFrame("Frame", nil, nil)
  pane:SetSize(600, 420)

  local contact = {
    displayName = "Arthas",
    classTag = "HUNTER",
    factionName = "Horde",
  }

  local header = HeaderView.Create(factory, pane, contact)

  -- Status dot should be anchored relative to the class icon frame, not the status text
  local dot = header.headerStatusDot
  assert(dot ~= nil, "header should have a status dot")

  -- The dot should be anchored to the class icon frame (overlay style)
  -- fake_ui stores SetPoint args in .point = { point, relativeTo, relPoint, x, y }
  assert(dot.point ~= nil, "status dot should have anchor point")

  local relativeTo = dot.point[2]
  assert(relativeTo == header.headerClassIconFrame, "status dot should be anchored to the class icon frame, not the status text")
end
