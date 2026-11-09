local FakeUI = require("tests.helpers.fake_ui")
local ScriptBindings = require("WhisperMessenger.UI.MessengerWindow.WindowScripts.Frame.ScriptBindings")

-- The window wires its ESC key override (EscapeKey) through ScriptBindings:
-- shown in front, it holds the game-menu key; hidden, it gives it back.

local SAVED_NAMES = {
  "CreateFrame",
  "GetBindingKey",
  "SetOverrideBindingClick",
  "ClearOverrideBindings",
  "InCombatLockdown",
  "UISpecialFrames",
}

local function noop() end

local function makeResizeStub()
  return {
    isResizing = function()
      return false
    end,
    stop = noop,
    reset = noop,
    start = noop,
    setHighlight = noop,
    updateFromCursor = noop,
  }
end

-- Runs fn(frame, bound) with a hidden, bound window and the game's binding
-- API stubbed; bound lists the keys overridden now.
local function withBoundWindow(fn, extraOptions)
  local saved = {}
  for _, name in ipairs(SAVED_NAMES) do
    saved[name] = rawget(_G, name)
  end
  local factory = FakeUI.NewFactory()
  local bound = {}
  rawset(_G, "CreateFrame", factory.CreateFrame)
  rawset(_G, "GetBindingKey", function()
    return "ESCAPE"
  end)
  rawset(_G, "SetOverrideBindingClick", function(_owner, _priority, key, _buttonName)
    table.insert(bound, key)
  end)
  rawset(_G, "ClearOverrideBindings", function(_owner)
    for index = #bound, 1, -1 do
      bound[index] = nil
    end
  end)
  rawset(_G, "InCombatLockdown", function()
    return false
  end)
  rawset(_G, "UISpecialFrames", {})

  local ok, err = pcall(function()
    local uiParent = factory.CreateFrame("Frame", "UIParent", nil)
    uiParent:Show()
    local frame = factory.CreateFrame("Frame", "WhisperMessengerWindow", uiParent)
    local resizeStub = makeResizeStub()
    local bindOptions = {
      frame = frame,
      frameTheme = { WINDOW_ALPHA_UPDATE_INTERVAL = 0.1 },
      windowResize = resizeStub,
      contactsResize = resizeStub,
      relayoutWindow = noop,
      isSuppressSizeChangedRelayout = function()
        return false
      end,
      refreshWindowAlpha = noop,
      getAutoFocusChatInput = function()
        return false
      end,
      buildState = function()
        return {}
      end,
    }
    for key, value in pairs(extraOptions or {}) do
      bindOptions[key] = value
    end
    local bindResult = ScriptBindings.Bind(bindOptions)
    fn(frame, bound, bindResult)
  end)
  for _, name in ipairs(SAVED_NAMES) do
    rawset(_G, name, saved[name])
  end
  assert(ok, err)
end

return function()
  -- test_shown_window_takes_the_escape_key
  withBoundWindow(function(frame, bound)
    frame:Show()
    assert(#bound == 1 and bound[1] == "ESCAPE", "the window shown in front must hold ESC")
  end)

  -- test_hidden_window_gives_the_escape_key_back
  withBoundWindow(function(frame, bound)
    frame:Show()
    frame:Hide()
    assert(#bound == 0, "a closed window must give ESC back to the game")
  end)

  -- test_escape_off_getter_keeps_window_unlisted_on_show
  withBoundWindow(function(frame, bound, bindResult)
    frame:Show()
    for _, name in ipairs(_G.UISpecialFrames) do
      assert(name ~= "WhisperMessengerWindow", "with Esc off the window must stay out of UISpecialFrames")
    end
    assert(#bound == 0, "with Esc off the window must not hold ESC")
    assert(type(bindResult) == "table" and type(bindResult.refreshEscape) == "function", "Bind must return refreshEscape")
  end, {
    getEscapeClosesWindow = function()
      return false
    end,
  })
end
