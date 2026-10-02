local LayoutBuilder = require("WhisperMessenger.UI.MessengerWindow.LayoutBuilder")
local RelayoutController = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.RelayoutController")
local Theme = require("WhisperMessenger.UI.Theme")
local FakeUI = require("tests.helpers.fake_ui")

local RAIL = Theme.LAYOUT.CONTACTS_RAIL_WIDTH

return function()
  local factory = FakeUI.NewFactory()

  -- test_build_starts_collapsed_from_saved_state
  do
    local host = factory.CreateFrame("Frame", nil, nil)
    local layout = LayoutBuilder.Build(factory, host, { width = 900, height = 560, contactsCollapsed = true }, { contactsWidth = 280 })
    assert(layout.contactsCollapsed == true, "layout remembers the collapsed state")
    assert(layout.contactsPane.width == RAIL, "pane builds at the rail width, got " .. tostring(layout.contactsPane.width))
    assert(layout.expandedContactsWidth == 280, "expanded width survives, got " .. tostring(layout.expandedContactsWidth))
    assert(layout.optionsMenu.width == 280, "settings nav builds at the expanded width, got " .. tostring(layout.optionsMenu.width))
  end

  -- test_relayout_collapsed_keeps_settings_nav_expanded
  do
    local host = factory.CreateFrame("Frame", nil, nil)
    local layout = LayoutBuilder.Build(factory, host, { width = 900, height = 560 }, { contactsWidth = 300 })
    layout.contactsCollapsed = true
    local result = LayoutBuilder.Relayout(layout, 900, 560, 300)
    assert(layout.contactsPane.width == RAIL, "collapsed relayout shrinks the pane to the rail")
    assert(layout.optionsMenu.width == 300, "settings nav keeps the expanded width")
    assert(result.expandedContactsWidth == 300, "relayout reports the expanded width")
    assert(layout.contactsView.totalWidth == RAIL, "contacts list follows the rail width")
  end

  -- test_relayout_controller_stores_the_expanded_width
  do
    local stored
    local controller = RelayoutController.Create({
      layoutBuilder = {
        Relayout = function()
          return { contactsWidth = RAIL, expandedContactsWidth = 300 }
        end,
      },
      layout = {},
      setContactsWidth = function(width)
        stored = width
      end,
    })
    controller.relayoutWindow(900, 560, 300, false)
    assert(stored == 300, "the remembered width is the expanded one, got " .. tostring(stored))
  end
end
