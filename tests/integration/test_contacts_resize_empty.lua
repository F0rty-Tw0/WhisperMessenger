local ContactsList = require("WhisperMessenger.UI.ContactsList")
local LayoutBuilder = require("WhisperMessenger.UI.MessengerWindow.LayoutBuilder")
local ScrollView = require("WhisperMessenger.UI.ScrollView")
local FakeUI = require("tests.helpers.fake_ui")

-- An empty (or short) contact list fills the viewport it was drawn in.
-- Shrinking the window must shrink that filler too, or the list scrolls
-- over nothing.

return function()
  local factory = FakeUI.NewFactory()
  local savedUIParent = _G.UIParent
  _G.UIParent = factory.CreateFrame("Frame", "UIParent", nil)

  -- test_shrinking_the_window_leaves_an_empty_list_unscrollable
  do
    local host = factory.CreateFrame("Frame", nil, _G.UIParent)
    host:SetSize(920, 580)
    local layout = LayoutBuilder.Build(factory, host, { width = 920, height = 580 })
    local cv = layout.contactsView
    ContactsList.Refresh(factory, cv.content, {}, {}, {})
    local tallContent = cv.content:GetHeight()

    LayoutBuilder.Relayout(layout, 920, 360)

    assert(cv.scrollFrame:GetHeight() < tallContent, "precondition: the viewport shrank")
    assert(ScrollView.GetRange(cv) == 0, "empty list has nothing to scroll, got range " .. tostring(ScrollView.GetRange(cv)))
  end

  _G.UIParent = savedUIParent
end
