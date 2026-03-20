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
  local pool = contentFrame._bubblePool
  local poolSize = #pool

  -- Pool should contain nameFrame + bubbleFrame + iconFrame = 3
  assert(poolSize >= 3, "pool should contain nameFrame + bubbleFrame + iconFrame, got: " .. poolSize)

  -- Capture all frames from first render
  local firstRenderFrames = {}
  for i = 1, poolSize do
    firstRenderFrames[i] = pool[i]
  end

  -- Second render with different messages — should hide all old frames
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

  -- All frames from the first render should now be hidden
  for i, frame in ipairs(firstRenderFrames) do
    assert(frame.shown == false, "frame " .. i .. " from first render should be hidden after re-render")
  end
end
