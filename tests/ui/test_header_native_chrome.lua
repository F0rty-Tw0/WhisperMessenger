local FakeUI = require("tests.helpers.fake_ui")
local HeaderView = require("WhisperMessenger.UI.ConversationPane.HeaderView")
local ConversationPane = require("WhisperMessenger.UI.ConversationPane.ConversationPane")

local CONTACT = { displayName = "Arthas", classTag = "PALADIN" }

return function()
  local factory = FakeUI.NewFactory()

  -- test_native_chrome_hides_header_strip_without_conversation
  do
    local pane = factory.CreateFrame("Frame", nil, nil)
    pane:SetSize(600, 420)
    local view = HeaderView.Create(factory, pane, nil)
    view.hideEmptyHeader = true
    view.headerFrame:Show()
    HeaderView.Refresh(view, nil)
    assert(view.headerFrame:IsShown() == false, "HUD: header strip should hide when no conversation is selected")
  end

  -- test_native_chrome_shows_header_strip_with_conversation
  do
    local pane = factory.CreateFrame("Frame", nil, nil)
    pane:SetSize(600, 420)
    local view = HeaderView.Create(factory, pane, nil)
    view.hideEmptyHeader = true
    HeaderView.Refresh(view, CONTACT)
    assert(view.headerFrame:IsShown() == true, "HUD: header strip should show for a selected conversation")
  end

  -- test_modern_chrome_keeps_header_strip_without_conversation
  do
    local pane = factory.CreateFrame("Frame", nil, nil)
    pane:SetSize(600, 420)
    local view = HeaderView.Create(factory, pane, nil)
    view.headerFrame:Show()
    HeaderView.Refresh(view, nil)
    assert(view.headerFrame:IsShown() == true, "modern: header strip should stay as today")
  end

  -- test_conversation_pane_passes_hide_empty_header_option
  do
    local parent = factory.CreateFrame("Frame", nil, nil)
    parent:SetSize(600, 420)
    local view = ConversationPane.Create(factory, parent, nil, nil, { hideEmptyHeader = true })
    assert(view.hideEmptyHeader == true, "ConversationPane should carry hideEmptyHeader onto the view")
    assert(view.headerFrame:IsShown() == false, "HUD: header strip hidden on first render with no conversation")
  end
end
