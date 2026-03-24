local FakeUI = require("tests.helpers.fake_ui")
local Layout = require("WhisperMessenger.UI.ChatBubble.Layout")

return function()
  local factory = FakeUI.NewFactory()
  local contentFrame = factory.CreateFrame("Frame", nil, nil)
  contentFrame:SetSize(400, 600)

  local messages = {
    {
      direction = "in",
      kind = "user",
      text = "hello",
      classTag = "DRUID",
      sentAt = 1000,
      playerName = "Arthas",
    },
  }

  -- First render — creates bubble + icon + name label
  Layout.LayoutMessages(factory, contentFrame, messages, 400)
  local active = contentFrame._activeFrames
  local activeSize = #active

  -- Pool should contain nameFrame + bubbleFrame + iconFrame = 3
  assert(activeSize >= 3, "active pool should contain nameFrame + bubbleFrame + iconFrame, got: " .. activeSize)

  -- Second render with different messages — old frames should be released and reused
  local messages2 = {
    {
      direction = "out",
      kind = "user",
      text = "goodbye",
      sentAt = 2000,
      playerName = "Me",
    },
  }
  Layout.LayoutMessages(factory, contentFrame, messages2, 400)

  -- Frames from first render that are now in the free pool should be hidden
  local freePool = contentFrame._freeFrames
  for i, frame in ipairs(freePool) do
    assert(frame.shown == false, "free frame " .. i .. " should be hidden after re-render")
  end
end
