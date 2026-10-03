local FakeUI = require("tests.helpers.fake_ui")
local ContactsRail = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.ContactsRail")

local function makeLayout(factory, collapsed)
  local search = factory.CreateFrame("Frame", nil, nil)
  local magnifier = factory.CreateFrame("Button", nil, nil)
  return { contactsSearchFrame = search, contactsRailSearchButton = magnifier, contactsCollapsed = collapsed }
end

local function makeRail(factory, layout)
  local frame = factory.CreateFrame("Frame", nil, nil)
  frame:SetSize(600, 400)
  return ContactsRail.Create({
    frame = frame,
    layout = layout,
    windowGeometry = {
      setCollapsed = function() end,
      getContactsWidth = function()
        return 200
      end,
      setContactsWidth = function() end,
    },
    chrome = { setContactsCollapsed = function() end },
    relayoutWindow = function() end,
  })
end

return function()
  -- test_search_box_hides_while_unavailable
  do
    local layout = makeLayout(FakeUI.NewFactory(), false)
    ContactsRail.SetSearchAvailable(layout, false)
    assert(layout.contactsSearchFrame:IsShown() == false, "no search box on an empty tab")
    ContactsRail.SetSearchAvailable(layout, true)
    assert(layout.contactsSearchFrame:IsShown() == true, "search box back once the tab has chats")
  end

  -- test_collapsed_rail_keeps_the_search_box_hidden
  do
    local layout = makeLayout(FakeUI.NewFactory(), true)
    layout.contactsSearchFrame:Hide()
    ContactsRail.SetSearchAvailable(layout, true)
    assert(layout.contactsSearchFrame:IsShown() == false, "the rail shows a magnifier, never the box")
  end

  -- test_expanding_the_rail_respects_an_empty_tab
  do
    local factory = FakeUI.NewFactory()
    local layout = makeLayout(factory, true)
    local rail = makeRail(factory, layout)
    ContactsRail.SetSearchAvailable(layout, false)
    rail.setCollapsed(false)
    assert(layout.contactsSearchFrame:IsShown() == false, "expanding on an empty tab keeps the box hidden")
  end

  -- test_rail_magnifier_hides_on_an_empty_tab
  do
    local layout = makeLayout(FakeUI.NewFactory(), true)
    ContactsRail.SetSearchAvailable(layout, false)
    assert(layout.contactsRailSearchButton:IsShown() == false, "no magnifier on an empty tab")
    ContactsRail.SetSearchAvailable(layout, true)
    assert(layout.contactsRailSearchButton:IsShown() == true, "magnifier back once the tab has chats")
  end

  -- test_expanded_pane_never_shows_the_magnifier
  do
    local layout = makeLayout(FakeUI.NewFactory(), false)
    ContactsRail.SetSearchAvailable(layout, true)
    assert(layout.contactsRailSearchButton:IsShown() == false, "the expanded pane has the box, not the magnifier")
  end

  -- test_collapsing_on_an_empty_tab_shows_no_magnifier
  do
    local factory = FakeUI.NewFactory()
    local layout = makeLayout(factory, false)
    local rail = makeRail(factory, layout)
    ContactsRail.SetSearchAvailable(layout, false)
    rail.setCollapsed(true)
    assert(layout.contactsRailSearchButton:IsShown() == false, "collapsing on an empty tab keeps the magnifier hidden")
  end
end
