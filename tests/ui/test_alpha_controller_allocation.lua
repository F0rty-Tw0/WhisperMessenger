local AlphaController = require("WhisperMessenger.UI.MessengerWindow.AlphaController")
local WindowAlpha = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.WindowAlpha")
local Theme = require("WhisperMessenger.UI.Theme")
local FakeUI = require("tests.helpers.fake_ui")

local ALLOC_BUDGET_KB = 1

return function()
  local factory = FakeUI.NewFactory()

  local savedGetUnitSpeed = _G.GetUnitSpeed
  local savedIsMouselooking = _G.IsMouselooking
  local savedIsMouseButtonDown = _G.IsMouseButtonDown
  rawset(_G, "GetUnitSpeed", function()
    return 0
  end)
  rawset(_G, "IsMouselooking", function()
    return false
  end)
  rawset(_G, "IsMouseButtonDown", function()
    return false
  end)

  -- refreshWindowAlpha: near-zero allocation across repeated calls
  local frame = factory.CreateFrame("Frame", nil, nil)
  local composerInput = factory.CreateFrame("EditBox", nil, nil)
  local windowState = { isDimmed = false }
  local settings = { dimWhenMoving = true, windowOpacityActive = 1.0, windowOpacityInactive = 0.5 }

  AlphaController.refreshWindowAlpha(frame, composerInput, windowState, false, settings)

  collectgarbage("collect")
  collectgarbage("stop")
  local before = collectgarbage("count")
  for _ = 1, 200 do
    AlphaController.refreshWindowAlpha(frame, composerInput, windowState, false, settings)
  end
  local after = collectgarbage("count")
  collectgarbage("restart")
  assert(after - before < ALLOC_BUDGET_KB, "expected near-zero allocation, got " .. tostring(after - before) .. " KB over 200 calls")

  -- behaviour unchanged: dimWhenMoving=false keeps active alpha
  local frame2 = factory.CreateFrame("Frame", nil, nil)
  local ws2 = { isDimmed = false }
  local noDimSettings = { dimWhenMoving = false, windowOpacityActive = 1.0, windowOpacityInactive = 0.5 }
  AlphaController.refreshWindowAlpha(frame2, composerInput, ws2, false, noDimSettings)
  assert(frame2.alpha == 1.0, "expected active alpha with dimWhenMoving=false, got " .. tostring(frame2.alpha))

  -- behaviour unchanged: no settings + no external activity falls back to Theme idle alpha
  local frame3 = factory.CreateFrame("Frame", nil, nil)
  local ws3 = { isDimmed = false }
  AlphaController.refreshWindowAlpha(frame3, composerInput, ws3, false, nil)
  assert(frame3.alpha == Theme.WINDOW_IDLE_ALPHA, "expected Theme idle alpha with no settings, got " .. tostring(frame3.alpha))

  rawset(_G, "GetUnitSpeed", savedGetUnitSpeed)
  rawset(_G, "IsMouselooking", savedIsMouselooking)
  rawset(_G, "IsMouseButtonDown", savedIsMouseButtonDown)

  -- WindowAlpha.Create(...).refreshWindowAlpha: near-zero allocation across repeated calls
  local frame4 = factory.CreateFrame("Frame", nil, nil)
  local composerInput4 = factory.CreateFrame("EditBox", nil, nil)
  local windowAlpha = WindowAlpha.Create({
    alphaController = AlphaController,
    frame = frame4,
    composerInput = composerInput4,
    settingsConfig = { dimWhenMoving = true, windowOpacityActive = 1, windowOpacityInactive = 0.5 },
  })

  windowAlpha.refreshWindowAlpha(false)

  collectgarbage("collect")
  collectgarbage("stop")
  local before2 = collectgarbage("count")
  for _ = 1, 200 do
    windowAlpha.refreshWindowAlpha(false)
  end
  local after2 = collectgarbage("count")
  collectgarbage("restart")
  assert(
    after2 - before2 < ALLOC_BUDGET_KB,
    "expected near-zero allocation via WindowAlpha, got " .. tostring(after2 - before2) .. " KB over 200 calls"
  )
end
