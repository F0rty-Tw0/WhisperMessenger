local AlphaController = require("WhisperMessenger.UI.MessengerWindow.AlphaController")
local Theme = require("WhisperMessenger.UI.Theme")
local FakeUI = require("tests.helpers.fake_ui")

return function()
  local factory = FakeUI.NewFactory()

  -- applyWindowAlpha: uses Theme defaults when no alphaConfig given
  local frame = factory.CreateFrame("Frame", nil, nil)
  local ws = { isDimmed = false }
  AlphaController.applyWindowAlpha(frame, true, ws)
  assert(frame.alpha == Theme.WINDOW_EXTERNAL_ACTIVITY_ALPHA, "expected Theme inactive alpha when no config")
  AlphaController.applyWindowAlpha(frame, false, ws)
  assert(frame.alpha == Theme.WINDOW_IDLE_ALPHA, "expected Theme active alpha when no config")

  -- applyWindowAlpha: uses custom alphaConfig when provided
  local customConfig = { active = 0.9, inactive = 0.4 }
  AlphaController.applyWindowAlpha(frame, true, ws, customConfig)
  assert(frame.alpha == 0.4, "expected custom inactive alpha 0.4, got " .. tostring(frame.alpha))

  AlphaController.applyWindowAlpha(frame, false, ws, customConfig)
  assert(frame.alpha == 0.9, "expected custom active alpha 0.9, got " .. tostring(frame.alpha))

  -- refreshWindowAlpha: dimWhenMoving=false prevents dimming
  local savedGetUnitSpeed = _G.GetUnitSpeed
  local savedIsMouselooking = _G.IsMouselooking
  local savedIsMouseButtonDown = _G.IsMouseButtonDown
  rawset(_G, "GetUnitSpeed", function()
    return 7
  end)
  rawset(_G, "IsMouselooking", function()
    return false
  end)
  rawset(_G, "IsMouseButtonDown", function()
    return false
  end)

  local frame2 = factory.CreateFrame("Frame", nil, nil)
  local ws2 = { isDimmed = false }
  local composerInput = factory.CreateFrame("EditBox", nil, nil)

  -- With dimWhenMoving=false, player movement should NOT dim
  local noDimSettings = { dimWhenMoving = false, windowOpacityActive = 1.0, windowOpacityInactive = 0.5 }
  AlphaController.refreshWindowAlpha(frame2, composerInput, ws2, false, noDimSettings)
  assert(frame2.alpha == 1.0, "expected no dimming when dimWhenMoving=false, got " .. tostring(frame2.alpha))

  -- With dimWhenMoving=true (or nil), player movement SHOULD dim
  local dimSettings = { dimWhenMoving = true, windowOpacityActive = 1.0, windowOpacityInactive = 0.5 }
  AlphaController.refreshWindowAlpha(frame2, composerInput, ws2, false, dimSettings)
  assert(frame2.alpha == 0.5, "expected dimming when dimWhenMoving=true with movement, got " .. tostring(frame2.alpha))

  -- forceOpaque with custom settings uses active alpha
  ws2.isDimmed = false
  frame2.alpha = 0.5
  local opaqueSettings = { windowOpacityActive = 0.85, windowOpacityInactive = 0.3 }
  AlphaController.refreshWindowAlpha(frame2, composerInput, ws2, true, opaqueSettings)
  assert(frame2.alpha == 0.85, "expected forceOpaque to use custom active alpha 0.85, got " .. tostring(frame2.alpha))

  rawset(_G, "GetUnitSpeed", savedGetUnitSpeed)
  rawset(_G, "IsMouselooking", savedIsMouselooking)
  rawset(_G, "IsMouseButtonDown", savedIsMouseButtonDown)
end
