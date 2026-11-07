local FindUI = require("tests.helpers.find_ui")
local PhoneWindow = require("tests.helpers.phone_window")

local function tabs(case)
  return FindUI.ofType(case.window.tabToggle.frame, "Button")
end

local function click(b)
  b.scripts.OnClick(b)
end

-- A phone window with chat "a" open; clearsLikeRuntime refreshes the window
-- on every selection change, as the real runtime does.
local function inChat(clearsLikeRuntime)
  local case
  local extra = nil
  if clearsLikeRuntime then
    extra = {
      onSelectConversation = function(key)
        case.selections[#case.selections + 1] = key == nil and "none" or key
        case.window.refreshSelection({})
        return nil
      end,
    }
  end
  case = PhoneWindow.Build(extra)
  case.window.frame:Show()
  PhoneWindow.Select(case, "a")
  PhoneWindow.FinishSlide(case)
  return case
end

local function registerCa(case)
  case.window.registerPanel("ca", { title = "ca", onShow = function() end, onHide = function() end })
end

return function()
  -- test_strip_shows_on_the_list_and_in_the_chat
  do
    local case = PhoneWindow.Build()
    case.window.frame:Show()
    assert(case.window.tabToggle.frame:IsShown(), "list")
    PhoneWindow.Select(case, "a")
    assert(case.window.tabToggle.frame:IsShown(), "chat, mid-slide")
    PhoneWindow.FinishSlide(case)
    assert(case.window.tabToggle.frame:IsShown(), "chat")
  end

  -- test_current_tab_tap_in_a_chat_goes_back
  do
    local case = inChat()
    click(tabs(case)[1])
    PhoneWindow.FinishSlide(case)
    assert(case.selections[#case.selections] == "none", "selection cleared after the slide")
    assert(case.window.contactsPane:IsShown() and not case.window.contentPane:IsShown(), "list on screen")
    assert(case.window.getTabMode() == "whispers" and case.window.tabToggle.frame:IsShown())
  end

  -- test_other_tab_tap_in_a_chat_shows_that_tabs_list
  do
    local case = inChat(true)
    click(tabs(case)[2])
    PhoneWindow.FinishSlide(case)
    assert(case.window.getTabMode() == "groups")
    assert(case.window.contactsPane:IsShown() and not case.window.backButton:IsShown(), "list shown and stays")
  end

  -- test_panel_tab_tap_in_a_chat_opens_the_panel
  do
    local case = inChat()
    registerCa(case)
    click(tabs(case)[5])
    assert(case.window.getVisiblePanel() == "ca" and case.window.tabToggle.frame:IsShown())
  end

  -- test_settings_hide_the_strip_in_a_chat
  do
    local case = inChat()
    click(case.window.optionsButton)
    assert(not case.window.tabToggle.frame:IsShown())
  end

  -- test_current_tab_tap_on_the_list_does_nothing
  do
    local case = PhoneWindow.Build()
    case.window.frame:Show()
    local viewport = case.window.phoneViewport
    local before, onUpdate = #case.selections, viewport.scripts.OnUpdate
    click(tabs(case)[1])
    assert(#case.selections == before, "no selection change")
    assert(viewport.scripts.OnUpdate == onUpdate, "no slide started")
    assert(case.window.contactsPane:IsShown() and case.window.getTabMode() == "whispers")
  end

  -- test_current_tab_tap_with_a_panel_open_leaves_only_the_panel
  do
    local case = inChat()
    registerCa(case)
    click(tabs(case)[5])
    local before = #case.selections
    click(tabs(case)[1])
    PhoneWindow.FinishSlide(case)
    assert(case.window.getVisiblePanel() == nil, "panel closed")
    assert(#case.selections == before, "the phone back did not run")
    assert(case.window.contentPane:IsShown(), "the chat is back on screen")
  end
end
