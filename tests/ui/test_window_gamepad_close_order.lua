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
    hideComposerPopover = record("hideComposerPopover", state.popover == true),
    closeOpenDropdown = state.dropdown ~= nil and record("closeOpenDropdown", state.dropdown) or nil,
    clearComposerFocus = state.cursor ~= nil and record("clearComposerFocus", state.cursor) or nil,
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

local function called(calls, name)
  for _, c in ipairs(calls) do
    if c.name == name then
      return true
    end
  end
  return false
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
    assert(close() == true and last(calls) == "compactBack" and #calls == 3, "compact chat backs out, settings stay")
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

  -- test_b_closes_the_composer_popover_before_the_compact_chat
  do
    local close, calls = build({ popover = true, compactChat = true, options = true })
    assert(close() == true and last(calls) == "hideComposerPopover", "picker closes, chat and settings stay")
    assert(not called(calls, "compactBack"), "no second layer closed")
  end

  -- test_b_hides_our_popup_before_the_composer_popover
  do
    local close, calls = build({ popup = true, popover = true })
    assert(close() == true and last(calls) == "hideShownPopup" and not called(calls, "hideComposerPopover"), "popup first")
  end

  -- test_b_on_a_hidden_window_leaves_the_popover
  do
    local close, calls = build({ shown = false, popover = true })
    assert(close() == true and not called(calls, "hideComposerPopover"), "hidden window: nothing closed")
  end

  -- test_b_takes_the_cursor_out_and_closes_nothing
  do
    local close, calls = build({ cursor = true, compactChat = true, options = true })
    assert(close() == true, "handled")
    assert(#calls == 3 and calls[1].name == "hideShownPopup" and calls[2].name == "hideComposerPopover", "upper layers asked first")
    assert(calls[3].name == "clearComposerFocus", "cursor leaves the box, nothing else closes")
  end

  -- test_open_picker_closes_before_the_cursor_leaves
  do
    local close, calls = build({ popover = true, cursor = true })
    assert(close() == true and not called(calls, "clearComposerFocus"), "picker first, cursor stays")
  end

  -- test_open_popup_closes_before_the_cursor_leaves
  do
    local close, calls = build({ popup = true, cursor = true })
    assert(close() == true and not called(calls, "clearComposerFocus"), "popup first, cursor stays")
  end

  -- test_open_dropdown_closes_before_the_cursor_leaves
  do
    local close, calls = build({ dropdown = true, cursor = true })
    assert(close() == true and not called(calls, "clearComposerFocus"), "dropdown first, cursor stays")
  end

  -- test_cursor_leaves_before_compact_back
  do
    local close, calls = build({ cursor = true, compactChat = true })
    assert(close() == true and not called(calls, "compactBack"), "compact chat stays open while the cursor leaves")
  end

  -- test_cursor_not_in_the_box_goes_on_with_the_old_order
  do
    local close, calls = build({ cursor = false })
    assert(close() == true and called(calls, "clearComposerFocus"), "asked about the cursor")
    assert(calls[#calls - 1].name == "compactBack" and last(calls) == "closeWindow", "then the old order")
  end

  -- test_only_true_counts_as_the_cursor_leaving
  do
    local close, calls = build({ cursor = 1 })
    assert(close() == true and last(calls) == "closeWindow", "a truthy non-true answer goes on with the old order")
  end

  -- test_hidden_window_never_asks_about_the_cursor
  do
    local close, calls = build({ shown = false, cursor = true })
    assert(close() == true and #calls == 0, "hidden window: no call at all")
  end

  -- test_without_the_dep_the_order_is_unchanged
  do
    local close, calls = build({})
    assert(close() == true and #calls == 4, "four steps")
    local names = { "hideShownPopup", "hideComposerPopover", "compactBack", "closeWindow" }
    for i, name in ipairs(names) do
      assert(calls[i].name == name, "step " .. i .. " is " .. name)
    end
  end
end
