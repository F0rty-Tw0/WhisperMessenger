local GamepadCloseOrder = require("WhisperMessenger.UI.MessengerWindow.WindowScripts.Frame.GamepadCloseOrder")

-- Every dep records its call; state picks which step applies.
local function build(state)
  local calls = {}
  local function record(name, value)
    return function(...)
      table.insert(calls, { name = name, args = { ... } })
      return value
    end
  end
  local close = GamepadCloseOrder.Build({
    isWindowShown = function()
      return state.shown ~= false
    end,
    hideShownPopup = record("hideShownPopup", state.popup == true),
    closeOpenDropdown = state.dropdown ~= nil and record("closeOpenDropdown", state.dropdown) or nil,
    compactBack = record("compactBack", state.compactChat == true),
    isOptionsVisible = function()
      return state.options == true
    end,
    setOptionsVisible = record("setOptionsVisible"),
    getVisiblePanel = function()
      return state.panel
    end,
    setPanelVisible = record("setPanelVisible"),
    closeWindow = record("closeWindow"),
  })
  return close, calls
end

local function last(calls)
  return calls[#calls] and calls[#calls].name
end

return function()
  -- test_b_hides_our_shown_popup_first
  do
    local close, calls = build({ popup = true, compactChat = true, options = true })
    assert(close() == true and last(calls) == "hideShownPopup" and #calls == 1, "popup closes alone")
  end

  -- test_b_backs_out_of_the_compact_open_chat
  do
    local close, calls = build({ compactChat = true, options = true })
    assert(close() == true and last(calls) == "compactBack" and #calls == 2, "compact chat backs out, settings stay")
  end

  -- test_b_closes_the_settings_pane
  do
    local close, calls = build({ options = true, panel = "ca" })
    assert(close() == true and last(calls) == "setOptionsVisible" and calls[#calls].args[1] == false, "settings close")
  end

  -- test_b_closes_the_open_panel
  do
    local close, calls = build({ panel = "ca" })
    assert(close() == true and last(calls) == "setPanelVisible" and calls[#calls].args[1] == nil, "panel closes")
  end

  -- test_b_closes_the_window_last
  do
    local close, calls = build({})
    assert(close() == true and last(calls) == "closeWindow", "window closes when nothing else is open")
  end

  -- test_b_on_a_hidden_window_does_nothing
  do
    local close, calls = build({ shown = false, popup = true, options = true })
    assert(close() == true and #calls == 0, "hidden window: no action, still handled")
  end

  -- test_b_closes_an_open_settings_dropdown_before_settings
  do
    local close, calls = build({ dropdown = true, options = true })
    assert(close() == true and last(calls) == "closeOpenDropdown", "dropdown closes first")
    local close2, calls2 = build({ dropdown = false, options = true })
    assert(close2() == true and last(calls2) == "setOptionsVisible", "next B closes settings")
    local close3, calls3 = build({ popup = true, dropdown = true })
    assert(close3() == true and #calls3 == 1 and last(calls3) == "hideShownPopup", "our popup still comes first")
  end
end
