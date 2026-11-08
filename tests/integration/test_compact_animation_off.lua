local CompactWindow = require("tests.helpers.compact_window")

-- The slide strip ticks while its viewport has an OnUpdate script.
local function sliding(case)
  local viewport = case.window.compactViewport
  return viewport.scripts ~= nil and viewport.scripts.OnUpdate ~= nil
end

local function build(settings)
  settings.showGroupChats = true
  local case = CompactWindow.Build({ settingsConfig = settings })
  case.window.frame:Show()
  return case
end

return function()
  -- test_selecting_a_chat_snaps_when_window_animation_is_off
  do
    local case = build({ windowAnimation = false })
    CompactWindow.Select(case, "a")
    assert(not sliding(case), "no slide is running")
    assert(case.window.contentPane:IsShown(), "chat is on screen at once")
    assert(not case.window.contactsPane:IsShown(), "list is off screen at once")
  end

  -- test_back_snaps_and_still_clears_the_selection_when_window_animation_is_off
  do
    local case = build({ windowAnimation = false })
    CompactWindow.Select(case, "a")
    case.window.backButton.scripts.OnClick(case.window.backButton)
    assert(not sliding(case), "no slide is running")
    assert(case.window.contactsPane:IsShown(), "list is back at once")
    assert(case.selections[#case.selections] == "none", "selection cleared without waiting for a slide")
  end

  -- test_selecting_a_chat_still_slides_when_window_animation_is_unset
  do
    local case = build({})
    CompactWindow.Select(case, "a")
    assert(sliding(case), "unset counts as on")
    CompactWindow.FinishSlide(case)
  end

  -- test_window_animation_is_read_at_each_navigation
  do
    local settings = { windowAnimation = true }
    local case = build(settings)
    CompactWindow.Select(case, "a")
    assert(sliding(case), "on: slides")
    CompactWindow.FinishSlide(case)
    settings.windowAnimation = false
    case.window.backButton.scripts.OnClick(case.window.backButton)
    assert(not sliding(case), "flipped off after the window was built: snaps")
  end
end
