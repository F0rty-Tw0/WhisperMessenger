local RelayoutController = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.RelayoutController")

-- When the footer tabs wrap at a narrow pane width, the contacts list must
-- shrink by the extra footer row: relayout re-reads the bottom inset for the
-- new pane width and lays out again when it changed.

local TOP = 100

-- Minimal layout builder: list height = window height - top - bottom inset.
local function fakeLayoutBuilder(calls)
  return {
    Relayout = function(layout, _w, h, contactsWidth)
      calls[#calls + 1] = layout.contactsBottomInset
      return { contactsWidth = contactsWidth, contactsListHeight = h - TOP - (layout.contactsBottomInset or 0) }
    end,
  }
end

local function makeController(layout, calls, filled)
  return RelayoutController.Create({
    layoutBuilder = fakeLayoutBuilder(calls),
    layout = layout,
    setContactsWidth = function(_width) end,
    contactsController = {
      fillViewport = function(height)
        filled[#filled + 1] = height
      end,
    },
    getContactsBottomInset = function(width)
      return width < 250 and 48 or 24
    end,
  })
end

return function()
  -- test_narrow_pane_reserves_the_wrapped_footer
  do
    local layout = { contactsBottomInset = 24 }
    local calls, filled = {}, {}
    makeController(layout, calls, filled).relayoutWindow(800, 600, 210, false)
    assert(layout.contactsBottomInset == 48, "narrow pane stores the doubled inset, got " .. tostring(layout.contactsBottomInset))
    assert(#calls == 2, "layout re-runs once with the new inset, got " .. #calls)
    assert(filled[1] == 600 - TOP - 48, "list shrinks by the extra row, got " .. tostring(filled[1]))
  end

  -- test_unchanged_inset_lays_out_once
  do
    local layout = { contactsBottomInset = 24 }
    local calls, filled = {}, {}
    makeController(layout, calls, filled).relayoutWindow(800, 600, 300, false)
    assert(#calls == 1, "no second layout pass when the inset is unchanged, got " .. #calls)
    assert(filled[1] == 600 - TOP - 24, "list keeps the one-row inset")
  end
end
