local TabToggle = require("WhisperMessenger.UI.ContactsList.TabToggle")
local CompactWindow = require("tests.helpers.compact_window")

local KEY = "me::WOW::jaina"

-- The compact layout hands one handler to the tab strip's current-mode tap. It
-- is captured at the seam: no tab tap reaches it while a cover is up.
local function buildCapturing()
  local create, captured = TabToggle.Create, {}
  TabToggle.Create = function(...)
    local toggle = create(...)
    local set = toggle.setCurrentModeClickHandler
    toggle.setCurrentModeClickHandler = function(fn)
      captured.handler = fn
      return set(fn)
    end
    return toggle
  end
  local ok, case = pcall(CompactWindow.Build)
  TabToggle.Create = create
  assert(ok, case)
  assert(captured.handler, "the compact layout set a current-mode handler")
  case.window.frame:Show()
  CompactWindow.Select(case, KEY)
  CompactWindow.FinishSlide(case)
  return case, captured.handler
end

local function cleared(case)
  return case.selections[#case.selections] == "none"
end

return function()
  -- test_current_mode_tap_on_a_chat_goes_back
  do
    local case, handler = buildCapturing()
    assert(handler() == true, "a chat was open")
    CompactWindow.FinishSlide(case)
    assert(cleared(case), "uncovered: the chat is left")
  end

  -- test_current_mode_tap_under_the_options_pane_keeps_the_chat
  do
    local case, handler = buildCapturing()
    case.window.optionsButton.scripts.OnClick(case.window.optionsButton)
    assert(case.window.isConversationPaneShown() == false, "options cover the chat")
    assert(handler() == false, "nothing to go back from")
    CompactWindow.FinishSlide(case)
    assert(not cleared(case), "the chat stays selected")
  end

  -- test_current_mode_tap_under_a_wide_panel_keeps_the_chat
  do
    local case, handler = buildCapturing()
    assert(case.window.registerPanel("ca", { title = "ca", onShow = function() end, onHide = function() end }))
    case.window.showPanel("ca")
    assert(case.window.isConversationPaneShown() == false, "the panel covers the chat")
    assert(handler() == false, "nothing to go back from")
    CompactWindow.FinishSlide(case)
    assert(not cleared(case), "the chat stays selected")
  end
end
