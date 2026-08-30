local WindowScale = require("WhisperMessenger.UI.MessengerWindow.WindowScale")
local FakeUI = require("tests.helpers.fake_ui")
local WindowBounds = require("WhisperMessenger.UI.MessengerWindow.WindowBounds")
local ChromeBuilder = require("WhisperMessenger.UI.MessengerWindow.ChromeBuilder")
local MessengerWindow = require("WhisperMessenger.UI.MessengerWindow")
local WindowGeometry = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.WindowGeometry")
local LifecycleWiring = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.LifecycleWiring")
local ContactsRuntime = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.ContactsRuntime")
local RelayoutController = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.RelayoutController")
local LayoutBuilder = require("WhisperMessenger.UI.MessengerWindow.LayoutBuilder")
local Theme = require("WhisperMessenger.UI.Theme")
local UIHelpers = require("WhisperMessenger.UI.Helpers")
local SettingsControls = require("WhisperMessenger.UI.Shared.SettingsControls")

local function newParent(factory, width, height)
  local parent = factory.CreateFrame("Frame", nil, nil)
  parent:SetSize(width, height)
  return parent
end

local function assertPoint(frame, point, relativePoint, x, y, label)
  local actualPoint, _, actualRelativePoint, actualX, actualY = frame:GetPoint()
  assert(actualPoint == point and actualRelativePoint == relativePoint, label .. " must preserve anchor")
  assert(actualX == x and actualY == y, label .. " must preserve offset")
end

local function createObservedWindow(factory, options, beforeLayout)
  local calls = { relayout = 0, data = 0, suppressed = 0 }
  local originalRelayoutCreate = RelayoutController.Create
  local originalContactsCreate = ContactsRuntime.Create
  local originalLifecycleSetup = LifecycleWiring.Setup
  local originalLayoutBuild = LayoutBuilder.Build

  RelayoutController.Create = function(createOptions)
    local controller = originalRelayoutCreate(createOptions)
    local relayoutWindow = controller.relayoutWindow
    controller.relayoutWindow = function(...)
      calls.relayout = calls.relayout + 1
      return relayoutWindow(...)
    end
    return controller
  end
  ContactsRuntime.Create = function(...)
    local runtime = originalContactsCreate(...)
    local refreshContacts = runtime.refreshContacts
    runtime.refreshContacts = function(...)
      calls.data = calls.data + 1
      return refreshContacts(...)
    end
    return runtime
  end
  LifecycleWiring.Setup = function(setupOptions)
    local relayoutWindow, scriptResult = originalLifecycleSetup(setupOptions)
    local suppress = scriptResult.withSizeChangedRelayoutSuppressed
    scriptResult.withSizeChangedRelayoutSuppressed = function(callback)
      calls.suppressed = calls.suppressed + 1
      return suppress(callback)
    end
    return relayoutWindow, scriptResult
  end
  LayoutBuilder.Build = function(buildFactory, frame, initialState, ...)
    if beforeLayout then
      beforeLayout(frame, initialState)
    end
    return originalLayoutBuild(buildFactory, frame, initialState, ...)
  end

  local ok, window = pcall(MessengerWindow.Create, factory, options)
  RelayoutController.Create = originalRelayoutCreate
  ContactsRuntime.Create = originalContactsCreate
  LifecycleWiring.Setup = originalLifecycleSetup
  LayoutBuilder.Build = originalLayoutBuild
  assert(ok, window)

  calls.relayout, calls.data, calls.suppressed = 0, 0, 0
  return window, calls
end

return function()
  assert(WindowScale.MIN == 0.75, "MIN must be 0.75")
  assert(WindowScale.MAX == 1.50, "MAX must be 1.50")
  assert(WindowScale.STEP == 0.05, "STEP must be 0.05")
  assert(WindowScale.DEFAULT == 1.00, "DEFAULT must be 1.00")

  local cases = {
    { name = "nil", value = nil, expected = 1.00 },
    { name = "string", value = "1.25", expected = 1.00 },
    { name = "NaN", value = 0 / 0, expected = 1.00 },
    { name = "positive infinity", value = math.huge, expected = 1.00 },
    { name = "negative infinity", value = -math.huge, expected = 1.00 },
    { name = "below minimum", value = 0.74, expected = 1.00 },
    { name = "above maximum", value = 1.51, expected = 1.00 },
    { name = "minimum", value = 0.75, expected = 0.75 },
    { name = "default", value = 1.00, expected = 1.00 },
    { name = "maximum", value = 1.50, expected = 1.50 },
    { name = "snaps down", value = 1.024, expected = 1.00 },
    { name = "exact midpoint snaps up", value = 1.025, expected = 1.05 },
    { name = "snaps up", value = 1.026, expected = 1.05 },
    { name = "snaps down near maximum", value = 1.474, expected = 1.45 },
    { name = "snaps up near maximum", value = 1.476, expected = 1.50 },
  }

  for _, case in ipairs(cases) do
    assert(WindowScale.Normalize(case.value) == case.expected, case.name .. " must normalize to " .. tostring(case.expected))
  end

  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "ScaleParent", nil)
  local child = factory.CreateFrame("Frame", "ScaleChild", parent)
  assert(type(parent.SetScale) == "function", "fake frames must implement SetScale")
  assert(type(parent.GetScale) == "function", "fake frames must implement GetScale")
  assert(type(child.GetEffectiveScale) == "function", "fake frames must implement GetEffectiveScale")
  parent:SetScale(0.8)
  child:SetScale(1.5)
  assert(math.abs(child:GetEffectiveScale() - 1.2) < 1e-9, "parent 0.8 and child 1.5 must yield effective scale 1.2")

  local resizeEvents = {}
  local resizedSlider = factory.CreateFrame("Slider", nil, parent)
  resizedSlider:SetValue(4)
  resizedSlider:SetScript("OnValueChanged", function(_, value, userInput)
    resizeEvents[#resizeEvents + 1] = { value = value, userInput = userInput }
  end)
  resizedSlider:SetSize(20, 10)
  resizedSlider:SetSize(20, 10)
  assert(
    #resizeEvents == 1 and resizeEvents[1].value == 4 and resizeEvents[1].userInput == false,
    "fake slider resize must emit one programmatic callback only when dimensions change"
  )

  local releaseChanges = {}
  local releaseSlider = SettingsControls.CreateSliderRow(factory, parent, {
    label = "Deferred",
    min = 1,
    max = 10,
    step = 1,
    initial = 5,
    commitOnRelease = true,
    onChange = function(value)
      releaseChanges[#releaseChanges + 1] = value
    end,
  })
  local releaseMouseDown = releaseSlider.slider:GetScript("OnMouseDown")
  local releaseMouseUp = releaseSlider.slider:GetScript("OnMouseUp")
  releaseMouseDown(releaseSlider.slider, "LeftButton")
  releaseSlider.slider:SetValue(4.4, true)
  releaseSlider.slider:SetValue(6.2, true)
  assert(releaseSlider.value.text == "6" and #releaseChanges == 0, "native left drag must update display without committing")
  releaseMouseUp(releaseSlider.slider, "LeftButton")
  assert(#releaseChanges == 1 and releaseChanges[1] == 6, "left drag release must commit final stepped value once")

  local originalMouseDownCalls = 0
  local originalMouseUpCalls = 0
  local preservingChanges = {}
  local preservingFactory = {
    CreateFrame = function(frameType, name, frameParent)
      local created = factory.CreateFrame(frameType, name, frameParent)
      if frameType == "Slider" then
        created:SetScript("OnMouseDown", function()
          originalMouseDownCalls = originalMouseDownCalls + 1
        end)
        created:SetScript("OnMouseUp", function()
          originalMouseUpCalls = originalMouseUpCalls + 1
          created:SetValue(1)
        end)
      end
      return created
    end,
  }
  local preservingSlider = SettingsControls.CreateSliderRow(preservingFactory, parent, {
    label = "Preserving",
    min = 1,
    max = 2,
    step = 1,
    initial = 1,
    commitOnRelease = true,
    onChange = function(value)
      preservingChanges[#preservingChanges + 1] = value
    end,
  })
  preservingSlider.slider:GetScript("OnMouseDown")(preservingSlider.slider, "LeftButton")
  preservingSlider.slider:SetValue(2, true)
  preservingSlider.slider:GetScript("OnMouseUp")(preservingSlider.slider, "LeftButton")
  assert(originalMouseDownCalls == 1 and originalMouseUpCalls == 1, "commit-on-release slider must preserve existing mouse scripts")
  assert(#preservingChanges == 1 and preservingChanges[1] == 1, "reentrant mouse-up value must win without replaying deferred input")

  releaseMouseDown(releaseSlider.slider, "LeftButton")
  releaseSlider.slider:SetValue(4.4, true)
  releaseSlider.slider:SetValue(7.7)
  assert(#releaseChanges == 2 and releaseChanges[2] == 8, "programmatic update during drag must commit immediately")
  releaseMouseUp(releaseSlider.slider, "LeftButton")
  assert(#releaseChanges == 2, "programmatic update during drag must clear stale deferred value")

  parent:SetSize(1500, 900)
  local expectedBounds = {
    { scale = 0.75, width = 2000, height = 1200 },
    { scale = 1.00, width = 1500, height = 900 },
    { scale = 1.50, width = 1000, height = 600 },
  }
  for _, expected in ipairs(expectedBounds) do
    local _, _, maxWidth, maxHeight = WindowBounds.GetResizeBounds(parent, nil, expected.scale)
    assert(maxWidth == expected.width and maxHeight == expected.height, tostring(expected.scale) .. " scale must use logical parent maxima")
  end
  local clampedState = WindowBounds.ClampState(parent, { width = 2500, height = 1500 }, nil, 0.75)
  assert(clampedState.width == 2000 and clampedState.height == 1200, "ClampState must use scaled logical maxima")

  local _, _, defaultMaxWidth, defaultMaxHeight = WindowBounds.GetResizeBounds(parent)
  assert(defaultMaxWidth == 1500 and defaultMaxHeight == 900, "omitted scale must retain 100% maxima")
  local _, _, invalidMaxWidth, invalidMaxHeight = WindowBounds.GetResizeBounds(parent, nil, "1.5")
  assert(invalidMaxWidth == 1500 and invalidMaxHeight == 900, "invalid scale must retain 100% maxima")

  local undersizedParent = factory.CreateFrame("Frame", "UndersizedScaleParent", nil)
  undersizedParent:SetSize(100, 100)
  local minWidth, minHeight, maxWidth, maxHeight = WindowBounds.GetResizeBounds(undersizedParent, nil, 1.5)
  assert(minWidth <= maxWidth and minHeight <= maxHeight, "scaled undersized parent must not produce invalid bounds")

  local chromeParent = factory.CreateFrame("Frame", "ChromeScaleParent", nil)
  chromeParent:SetSize(1500, 900)
  local chrome = ChromeBuilder.Build(factory, chromeParent, { width = 900, height = 580 }, {
    windowScale = 1.5,
  })
  local frame = chrome.frame
  assert(frame:GetScale() == 1.5, "initial chrome scale must set root local scale")
  local _, _, initialMaxWidth, initialMaxHeight = frame:GetResizeBounds()
  assert(initialMaxWidth == 1000 and initialMaxHeight == 600, "initial chrome bounds must use root scale")
  assert(type(chrome.refreshScale) == "function", "chrome must expose refreshScale")
  assert(chrome.refreshScale(0.75) == 0.75, "refreshScale must return normalized scale")
  assert(chrome.frame == frame and frame:GetScale() == 0.75, "refreshScale must update scale without recreating chrome")
  local _, _, refreshedMaxWidth, refreshedMaxHeight = frame:GetResizeBounds()
  assert(refreshedMaxWidth == 2000 and refreshedMaxHeight == 1200, "refreshScale must reapply logical bounds")
  assert(chrome.refreshScale("1.5") == 1.00 and frame:GetScale() == 1.00, "refreshScale must normalize invalid scale")

  local liveFactory = FakeUI.NewFactory()
  local liveSettings = { windowScale = 1.00 }
  local liveWindow, liveCalls = createObservedWindow(liveFactory, {
    parent = newParent(liveFactory, 1500, 900),
    settingsConfig = liveSettings,
    state = {
      width = 900,
      height = 580,
      contactsWidth = 300,
      anchorPoint = "TOPLEFT",
      relativePoint = "TOPLEFT",
      x = 31,
      y = -47,
    },
  })
  assert(type(liveWindow.setScale) == "function", "messenger window must expose live setScale")
  assert(liveWindow.setScale(0.75) == 0.75 and liveSettings.windowScale == 0.75, "live scale must normalize and persist")
  assert(liveWindow.frame:GetScale() == 0.75, "live scale must update only the root local scale")
  assert(liveWindow.frame:GetWidth() == 900 and liveWindow.frame:GetHeight() == 580, "0.75 scale must preserve valid logical size")
  assert(liveWindow.contactsPane:GetWidth() == 300, "0.75 scale must preserve logical contacts width")
  assertPoint(liveWindow.frame, "TOPLEFT", "TOPLEFT", 31, -47, "0.75 scale")
  local _, _, liveMaxWidth, liveMaxHeight = liveWindow.frame:GetResizeBounds()
  assert(liveMaxWidth == 2000 and liveMaxHeight == 1200, "0.75 scale must update live resize maxima")
  assert(liveCalls.relayout == 0 and liveCalls.data == 0, "valid live scale must not relayout or refresh data")

  assert(liveWindow.setScale(1.50) == 1.50 and liveSettings.windowScale == 1.50, "1.50 scale must persist")
  assert(liveWindow.frame:GetScale() == 1.50 and liveWindow.contactsPane:GetScale() == 1, "scale must remain root-local")
  assert(liveWindow.frame:GetWidth() == 900 and liveWindow.frame:GetHeight() == 580, "1.50 scale must preserve valid logical size")
  assert(liveWindow.contactsPane:GetWidth() == 300, "1.50 scale must preserve logical contacts width")
  assertPoint(liveWindow.frame, "TOPLEFT", "TOPLEFT", 31, -47, "1.50 scale")
  _, _, liveMaxWidth, liveMaxHeight = liveWindow.frame:GetResizeBounds()
  assert(liveMaxWidth == 1000 and liveMaxHeight == 600, "1.50 scale must update live resize maxima")
  assert(liveCalls.relayout == 0 and liveCalls.suppressed == 2, "valid scale changes must suppress size events without ordinary relayout")

  assert(liveWindow.setScale(1.50) == 1.50, "repeated live scale must return the normalized value")
  assert(liveCalls.relayout == 0 and liveCalls.data == 0, "repeated live scale must be idempotent")
  assert(liveWindow.setScale("1.50") == 1.00 and liveSettings.windowScale == 1.00, "invalid live scale must fall back and persist 1.00")
  _, _, liveMaxWidth, liveMaxHeight = liveWindow.frame:GetResizeBounds()
  assert(liveMaxWidth == 1500 and liveMaxHeight == 900, "fallback scale must restore 1.00 resize maxima")

  local deferredFactory = FakeUI.NewFactory()
  local deferredSettings = { windowScale = 1.00 }
  local deferredWindow
  local deferredCalls
  local function onDeferredSettingChanged(key, value)
    if key == "windowScale" then
      deferredWindow.setScale(value)
    end
  end
  deferredWindow, deferredCalls = createObservedWindow(deferredFactory, {
    parent = newParent(deferredFactory, 1200, 750),
    settingsConfig = deferredSettings,
    state = {
      width = 900,
      height = 580,
      contactsWidth = 300,
      anchorPoint = "TOPLEFT",
      relativePoint = "TOPLEFT",
      x = 31,
      y = -47,
    },
    onSettingChanged = onDeferredSettingChanged,
  })
  local deferredSlider = deferredWindow.appearanceSettings.windowScaleSlider
  local deferredMouseDown = deferredSlider:GetScript("OnMouseDown")
  local deferredMouseUp = deferredSlider:GetScript("OnMouseUp")
  assert(type(deferredMouseDown) == "function" and type(deferredMouseUp) == "function", "window scale slider must defer left drags")
  deferredMouseDown(deferredSlider, "LeftButton")
  deferredSlider:SetValue(1.50, true)
  assert(deferredSettings.windowScale == 1.00 and deferredWindow.frame:GetScale() == 1.00, "window scale drag must not commit root scale")
  assert(
    deferredWindow.frame:GetWidth() == 900 and deferredWindow.frame:GetHeight() == 580 and deferredCalls.relayout == 0,
    "window scale drag must not clamp geometry"
  )
  deferredMouseUp(deferredSlider, "LeftButton")
  assert(deferredSettings.windowScale == 1.50 and deferredWindow.frame:GetScale() == 1.50, "window scale release must commit final root scale")
  assert(
    deferredWindow.frame:GetWidth() == 800 and deferredWindow.frame:GetHeight() == 500 and deferredCalls.relayout == 1,
    "window scale release must clamp geometry once"
  )
  local constrainedReleaseFactory = FakeUI.NewFactory()
  local constrainedReleaseSettings = { windowScale = 1.00 }
  local constrainedReleaseWindow
  local constrainedReleaseSettingCalls = 0
  local constrainedReleaseSetScaleCalls = 0
  local function onConstrainedReleaseSettingChanged(key, value)
    if key == "windowScale" then
      constrainedReleaseSettingCalls = constrainedReleaseSettingCalls + 1
      constrainedReleaseSetScaleCalls = constrainedReleaseSetScaleCalls + 1
      constrainedReleaseWindow.setScale(value)
    end
  end
  local constrainedReleaseWindowCalls
  constrainedReleaseWindow, constrainedReleaseWindowCalls = createObservedWindow(constrainedReleaseFactory, {
    parent = newParent(constrainedReleaseFactory, 720, 630),
    settingsConfig = constrainedReleaseSettings,
    state = {
      width = 900,
      height = 580,
      contactsWidth = 300,
      anchorPoint = "TOPLEFT",
      relativePoint = "TOPLEFT",
      x = 31,
      y = -47,
    },
    onSettingChanged = onConstrainedReleaseSettingChanged,
  })
  local constrainedReleaseSlider = constrainedReleaseWindow.appearanceSettings.windowScaleSlider
  constrainedReleaseSlider:GetScript("OnMouseDown")(constrainedReleaseSlider, "LeftButton")
  constrainedReleaseSlider:SetValue(1.50, true)
  constrainedReleaseSlider:GetScript("OnMouseUp")(constrainedReleaseSlider, "LeftButton")
  assert(
    constrainedReleaseSettingCalls == 1 and constrainedReleaseSetScaleCalls == 1,
    "constrained scale release must hand off windowScale exactly once despite settings relayout"
  )
  assert(
    constrainedReleaseWindowCalls.relayout == 1
      and constrainedReleaseWindow.frame:GetWidth() == 480
      and constrainedReleaseWindow.frame:GetHeight() == 420,
    "constrained scale release must clamp and relayout exactly once"
  )

  local constrainedFactory = FakeUI.NewFactory()
  local constrainedSettings = { windowScale = 1.00 }
  local constrainedWindow, constrainedCalls = createObservedWindow(constrainedFactory, {
    parent = newParent(constrainedFactory, 1200, 750),
    settingsConfig = constrainedSettings,
    state = {
      width = 900,
      height = 580,
      contactsWidth = 300,
      anchorPoint = "TOPLEFT",
      relativePoint = "TOPLEFT",
      x = 31,
      y = -47,
    },
  })
  assert(constrainedWindow.setScale(1.50) == 1.50, "constrained live scale must return 1.50")
  assert(constrainedWindow.frame:GetWidth() == 800 and constrainedWindow.frame:GetHeight() == 500, "1.50 constrained scale must clamp to 800x500")
  assert(constrainedWindow.contactsPane:GetWidth() == 300, "constrained scale must preserve valid contacts width")
  assertPoint(constrainedWindow.frame, "TOPLEFT", "TOPLEFT", 31, -47, "constrained scale")
  assert(
    constrainedCalls.relayout == 1 and constrainedCalls.suppressed == 1,
    "constrained scale must suppress apply and relayout children exactly once"
  )
  assert(constrainedCalls.data == 0, "constrained scale must not refresh data")
  constrainedWindow.setScale(1.50)
  assert(constrainedCalls.relayout == 1 and constrainedCalls.data == 0, "repeated constrained scale must not relayout or refresh data")

  local staleFactory = FakeUI.NewFactory()
  local staleParent = newParent(staleFactory, 1500, 900)
  local staleWindow, staleCalls = createObservedWindow(staleFactory, {
    parent = staleParent,
    settingsConfig = { windowScale = 1.00 },
    state = { width = 900, height = 580, contactsWidth = 300 },
  })
  staleParent:SetSize(800, 500)
  assert(
    staleWindow.frame:GetWidth() == 900 and staleWindow.frame:GetHeight() == 580,
    "parent shrink must leave stale root geometry until transaction"
  )
  staleWindow.setScale(0.75)
  assert(staleWindow.frame:GetWidth() == 900 and staleWindow.frame:GetHeight() == 580, "new-scale valid geometry must survive stale old-scale bounds")
  assert(staleCalls.relayout == 0, "new-scale valid stale geometry must not relayout")
  assert(staleCalls.data == 0, "stale-root relayout must not refresh data")

  local initialFactory = FakeUI.NewFactory()
  local initialSettings = { windowScale = 1.50 }
  local sawInitialLayout = false
  local initialWindow = createObservedWindow(initialFactory, {
    parent = newParent(initialFactory, 1200, 750),
    settingsConfig = initialSettings,
    state = { width = 900, height = 580, contactsWidth = 300 },
  }, function(root, initialState)
    local _, _, maxWidthAtBuild, maxHeightAtBuild = root:GetResizeBounds()
    assert(root:GetScale() == 1.50, "initial root scale must apply before child layout")
    assert(initialState.width == 800 and initialState.height == 500, "initial geometry must clamp with scaled maxima")
    assert(maxWidthAtBuild == 800 and maxHeightAtBuild == 500, "initial resize bounds must be scaled before child layout")
    sawInitialLayout = true
  end)
  assert(sawInitialLayout and initialSettings.windowScale == 1.50, "initial normalized scale must persist in shared settings")
  assert(
    initialWindow.frame:GetScale() == 1.50 and initialWindow.frame:GetWidth() == 800 and initialWindow.frame:GetHeight() == 500,
    "initial scale and clamp must reach live root"
  )

  local geometryFactory = FakeUI.NewFactory()
  local geometryParent = newParent(geometryFactory, 1500, 900)
  local geometryFrame = geometryFactory.CreateFrame("Frame", nil, geometryParent)
  geometryFrame:SetSize(900, 580)
  geometryFrame:SetPoint("TOPLEFT", geometryParent, "TOPLEFT", 31, -47)
  local observedScales = {}
  local geometry = WindowGeometry.Create({
    parent = geometryParent,
    theme = Theme,
    clampState = function(parentFrame, state, theme, scale)
      observedScales[#observedScales + 1] = scale
      return WindowBounds.ClampState(parentFrame, state, theme, scale)
    end,
    clampContactsWidth = LayoutBuilder.ClampContactsWidth,
    captureFramePosition = UIHelpers.captureFramePosition,
    sizeValue = UIHelpers.sizeValue,
    initialState = { width = 900, height = 580, contactsWidth = 300 },
    initialScale = 1.476,
  })
  assert(geometry.getScale() == 1.50, "geometry must normalize and own initial scale")
  geometry.applyState(geometryFrame, geometry.buildState(geometryFrame))
  assert(observedScales[1] == 1.50 and observedScales[2] == 1.50, "build and apply must clamp with current scale")
  assert(geometry.setScale(0.75) == 0.75 and geometry.getScale() == 0.75, "geometry setter must normalize, store, and return")
  assert(geometryFrame:GetScale() == 1, "geometry setter must not call frame scaling APIs")
  geometry.buildState(geometryFrame)
  assert(observedScales[3] == 0.75, "later geometry clamps must use updated scale")
  assert(geometry.setScale("1.50") == 1.00, "geometry setter must normalize invalid scale")
  local anchorFrame = geometryFactory.CreateFrame("Frame", nil, geometryParent)
  anchorFrame:SetPoint("TOPLEFT", geometryParent, "TOPLEFT", 31, -47)
  geometry.applyState(anchorFrame, {
    width = 900,
    height = 580,
    contactsWidth = 300,
    anchorPoint = "BOTTOMRIGHT",
    relativePoint = "TOPRIGHT",
    x = -17,
    y = 23,
  })
  assert(#anchorFrame.points == 1, "applyState must replace rather than accumulate anchors")
  assertPoint(anchorFrame, "BOTTOMRIGHT", "TOPRIGHT", -17, 23, "applyState replacement")
end
