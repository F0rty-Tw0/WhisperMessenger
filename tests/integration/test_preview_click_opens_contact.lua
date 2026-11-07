local PhoneRuntime = require("tests.helpers.phone_runtime")

-- A left-click on the widget's whisper preview opens the window on that
-- whisper's chat, in the phone layout and in the classic one.

local KEY = PhoneRuntime.KEY

-- Live whisper with the window never built yet.
local function receiveWhisper(runtime)
  local finishSlide = PhoneRuntime.FinishSlide
  rawset(PhoneRuntime, "FinishSlide", function() end)
  local ok, err = pcall(PhoneRuntime.ReceiveWhisper, runtime)
  rawset(PhoneRuntime, "FinishSlide", finishSlide)
  assert(ok, err)
end

local function clickPreview(runtime)
  local frame = runtime.icon.previewFrame
  assert(frame:IsShown(), "the preview shows the whisper")
  frame:GetScript("OnMouseUp")(frame, "LeftButton")
  if runtime.window and runtime.window.phoneViewport then
    PhoneRuntime.FinishSlide(runtime)
  end
end

return function()
  -- test_phone_preview_click_opens_the_whispers_chat
  PhoneRuntime.Run(nil, function(runtime)
    receiveWhisper(runtime)
    clickPreview(runtime)
    assert(runtime.window.frame:IsShown(), "the window opens")
    assert(runtime.activeConversationKey == KEY, "selected: " .. tostring(runtime.activeConversationKey))
    assert(runtime.window.contentPane:IsShown(), "the chat is on screen")
    assert(not runtime.window.contactsPane:IsShown(), "not the list")
  end)

  -- test_classic_preview_click_opens_the_whispers_chat
  PhoneRuntime.Run({ phoneLayout = false }, function(runtime)
    receiveWhisper(runtime)
    clickPreview(runtime)
    assert(runtime.window.frame:IsShown(), "the window opens")
    assert(runtime.activeConversationKey == KEY, "selected: " .. tostring(runtime.activeConversationKey))
  end)
end
