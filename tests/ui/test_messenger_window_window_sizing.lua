-- Scale changes keep the window size and relayout only when clamping moved it.
local WindowSizing = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.WindowSizing")
local Theme = require("WhisperMessenger.UI.Theme")

local function makeSizing(appliedSize)
  local calls = { relayouts = {}, chromeScale = nil, suppressed = false }
  local frame = { width = 600, height = 400 }
  function frame:GetWidth()
    return self.width
  end
  function frame:GetHeight()
    return self.height
  end
  local settingsConfig = {}
  local sizing = WindowSizing.Create({
    frame = frame,
    initialState = { width = 1, height = 1 },
    settingsConfig = settingsConfig,
    chrome = {
      refreshScale = function(scale)
        calls.chromeScale = scale
        calls.chromeInsideSuppression = calls.suppressed
      end,
    },
    windowGeometry = {
      buildState = function()
        return { width = 0, height = 0 }
      end,
      setScale = function(scale)
        return scale * 2
      end,
      applyState = function(_frame, state)
        return appliedSize or { width = state.width, height = state.height }
      end,
      getContactsWidth = function()
        return 180
      end,
    },
    scriptResult = {
      withSizeChangedRelayoutSuppressed = function(fn)
        calls.suppressed = true
        local result = fn()
        calls.suppressed = false
        return result
      end,
    },
    relayoutWindow = function(width, height, contactsWidth, refresh)
      table.insert(calls.relayouts, { width, height, contactsWidth, refresh })
    end,
  })
  return sizing, calls, settingsConfig
end

return function()
  -- test_set_scale_stores_the_normalized_scale
  do
    local sizing, calls, settingsConfig = makeSizing()
    assert(sizing.setScale(0.5) == 1, "returns the normalized scale")
    assert(settingsConfig.windowScale == 1, "saves the normalized scale")
    assert(calls.chromeScale == 1 and calls.chromeInsideSuppression, "chrome rescales with relayout suppressed")
  end

  -- test_set_scale_skips_relayout_when_size_is_kept
  do
    local sizing, calls = makeSizing()
    sizing.setScale(1)
    assert(#calls.relayouts == 0, "no relayout when the size did not change")
  end

  -- test_set_scale_relayouts_when_clamping_resized_the_window
  do
    local sizing, calls = makeSizing({ width = 500, height = 300 })
    sizing.setScale(1)
    local call = calls.relayouts[1]
    assert(call and call[1] == 500 and call[2] == 300 and call[3] == 180 and call[4] == nil, "relayout at the clamped size")
  end

  -- test_initial_state_fills_defaults_for_a_fresh_install
  do
    local parent = {
      GetWidth = function()
        return 4000
      end,
      GetHeight = function()
        return 3000
      end,
    }
    local state = WindowSizing.InitialState(parent, {}, 1)
    assert(state.anchorPoint == "CENTER" and state.relativePoint == "CENTER", "centered by default")
    assert(state.x == 0 and state.y == 0 and state.minimized == false, "no offset, not minimized")
    assert(state.width == Theme.WINDOW_WIDTH and state.height == Theme.WINDOW_HEIGHT, "default size")
    assert(state.contactsCollapsed == false, "contacts expanded")
  end

  -- test_relayout_current_size_uses_the_frame_size
  do
    local sizing, calls = makeSizing()
    sizing.relayoutCurrentSize()
    local call = calls.relayouts[1]
    assert(call and call[1] == 600 and call[2] == 400 and call[3] == 180 and call[4] == false, "relayout at the frame size")
  end
end
