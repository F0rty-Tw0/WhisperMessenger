local FakeUI = require("tests.helpers.fake_ui")
local LayoutBuilder = require("WhisperMessenger.UI.MessengerWindow.LayoutBuilder")
local RailSearchButton = require("WhisperMessenger.UI.MessengerWindow.LayoutBuilder.RailSearchButton")
local Theme = require("WhisperMessenger.UI.Theme")

-- In the collapsed rail the search field becomes a magnifier button at the
-- top of the pane, with a tooltip naming what it does.

return function()
  local factory = FakeUI.NewFactory()

  -- test_layout_builds_a_hidden_magnifier_at_the_top_of_the_pane
  do
    local host = factory.CreateFrame("Frame", nil, nil)
    local layout = LayoutBuilder.Build(factory, host, { width = 900, height = 560 })
    local button = layout.contactsRailSearchButton
    assert(button ~= nil, "layout exposes the rail search button")
    assert(button.shown == false, "hidden while the pane is expanded")
    local point, relativeTo = button:GetPoint()
    assert(point == "TOP" and relativeTo == layout.contactsPane, "sits at the top of the contacts pane")
  end

  -- test_hover_names_the_button
  do
    local saved = _G.GameTooltip
    local state = {}
    _G.GameTooltip = {
      SetOwner = function(_, owner)
        state.owner = owner
      end,
      SetText = function(_, text)
        state.text = text
      end,
      Show = function()
        state.shown = true
      end,
      Hide = function()
        state.shown = false
      end,
    }
    local pane = factory.CreateFrame("Frame", nil, nil)
    local button = RailSearchButton.Create(factory, pane, { theme = Theme, searchMargin = 6, searchHeight = 30 })
    button:GetScript("OnEnter")(button)
    assert(state.shown == true and state.owner == button and state.text == "Search chats", "tooltip says Search chats")
    button:GetScript("OnLeave")(button)
    assert(state.shown == false, "tooltip hides on leave")
    _G.GameTooltip = saved
  end

  -- test_magnifier_uses_the_search_icon
  do
    local pane = factory.CreateFrame("Frame", nil, nil)
    local button = RailSearchButton.Create(factory, pane, { theme = Theme, searchMargin = 6, searchHeight = 30 })
    assert(button.icon.texturePath == "Interface\\Common\\UI-Searchbox-Icon", "magnifier glyph")
  end
end
