local CompactWindow = require("tests.helpers.compact_window")
local Theme = require("WhisperMessenger.UI.Theme")

local L = Theme.LAYOUT
local build, select, finishSlide = CompactWindow.Build, CompactWindow.Select, CompactWindow.FinishSlide

-- Open at saved spot on: the window opens where it was moved and the button stays home.
local function savedSpotOn()
  return true
end

-- The compact layout end to end: list and chat in one narrow window, the slide
-- between them, the back button, settings widening, and the tie to the button.

return function()
  -- test_window_opens_narrow
  do
    local case = build()
    assert(case.window.frame.width == L.COMPACT_WINDOW_WIDTH, "got " .. tostring(case.window.frame.width))
    assert(case.window.frame.height == L.COMPACT_WINDOW_HEIGHT, "got " .. tostring(case.window.frame.height))
    assert(case.window.isCompactLayout == true, "reports the layout")
  end

  -- test_list_fills_the_window_and_chat_waits_off_screen
  do
    local case = build()
    assert(case.window.contactsPane:IsShown(), "list shows")
    assert(not case.window.contentPane:IsShown(), "chat waits")
    assert(not case.window.contactsDivider:IsShown(), "no split divider")
    assert(not case.window.contactsResizeHandle:IsShown(), "no split handle")
  end

  -- test_clicking_a_chat_slides_to_it_and_shows_back
  do
    local case = build()
    case.window.frame:Show()
    select(case, "a")
    assert(case.window.backButton:IsShown(), "back appears at once")
    assert(not case.window.newConversationButton:IsShown(), "the list's buttons step aside")
    finishSlide(case)
    assert(case.window.contentPane:IsShown(), "chat on screen")
    assert(not case.window.contactsPane:IsShown(), "list off screen")
  end

  -- test_back_button_returns_to_the_list_and_clears_the_selection
  do
    local case = build()
    case.window.frame:Show()
    select(case, "a")
    finishSlide(case)
    case.window.backButton.scripts.OnClick(case.window.backButton)
    finishSlide(case)
    assert(case.selections[#case.selections] == "none", "selection cleared after the slide")
    assert(case.window.contactsPane:IsShown(), "list back")
    assert(not case.window.backButton:IsShown(), "back gone")
    assert(case.window.newConversationButton:IsShown(), "list buttons back")
  end

  -- test_opening_sends_the_button_to_the_window_and_closing_sends_it_home
  do
    local case = build()
    case.window.frame:Show()
    assert(case.rodeTo ~= nil, "the button rides the window")
    assert(case.rides == 1 and case.homes == 0, "one ride")
    case.window.closeButton.scripts.OnClick(case.window.closeButton)
    assert(case.homes == 1, "closing sends it home")
  end

  -- test_real_window_waits_unseen_then_returns_at_full_opacity
  do
    local case = build()
    case.window.frame:Show()
    assert(case.window.frame:GetAlpha() == 0, "the panel does the growing")
    assert(case.step ~= nil, "the window follows the button's clock")
    case.step(1, 1)
    assert(case.window.frame:GetAlpha() == 1, "fully back, got " .. tostring(case.window.frame:GetAlpha()))
  end

  -- test_with_no_button_the_window_is_never_held_unseen
  do
    local case = build({
      getDockIcon = function()
        return nil
      end,
    })
    case.window.frame:Show()
    assert(case.window.frame:GetAlpha() == 1, "nothing would ever reveal it")
  end

  -- test_ui_returning_after_alt_z_does_not_replay_the_opening
  do
    local case = build()
    local frame = case.window.frame
    frame:Show()
    case.step(1, 1)
    CompactWindow.ParentShows(frame)
    assert(frame:GetAlpha() == 1, "already open, so it stays visible")
  end

  -- test_opening_keeps_the_windows_own_anchor
  do
    local case = build({ isOpenAtSavedSpot = savedSpotOn })
    local frame = case.window.frame
    local before = { frame:GetPoint() }
    frame:Show()
    local after = { frame:GetPoint() }
    for i = 1, 5 do
      assert(after[i] == before[i], "anchor part " .. i .. " changed on open")
    end
    assert(after[2] ~= case.fab, "the window never anchors to the button")
  end

  -- test_a_window_with_no_saved_spot_opens_centred
  do
    local case = build()
    case.window.frame:Show()
    local point, _, relativePoint, x, y = case.window.frame:GetPoint()
    assert(point == "CENTER" and relativePoint == "CENTER" and x == 0 and y == 0, "got " .. tostring(point) .. "," .. tostring(x))
  end

  -- test_the_window_opens_at_its_saved_spot
  do
    local case = build({
      isOpenAtSavedSpot = savedSpotOn,
      state = { anchorPoint = "TOPLEFT", relativePoint = "BOTTOMLEFT", x = 300, y = 700 },
    })
    local frame = case.window.frame
    frame:Show()
    local point, _, relativePoint, x, y = frame:GetPoint()
    assert(point == "TOPLEFT" and relativePoint == "BOTTOMLEFT" and x == 300 and y == 700, "got " .. tostring(x) .. "," .. tostring(y))
  end

  -- test_opening_and_closing_never_save_a_position
  do
    local case = build()
    case.window.frame:Show()
    case.window.frame:Hide()
    assert(case.saved.state == nil, "only a drag or a reset saves the spot")
  end

  -- test_hiding_the_whole_ui_leaves_the_button_riding
  do
    local case = build()
    local frame = case.window.frame
    frame:Show()
    frame.shown = true
    for _, hook in ipairs(frame._hookScripts.OnHide) do
      hook(frame)
    end
    assert(case.homes == 0, "Alt+Z hid the parent, not the window")
  end

  -- test_moving_the_window_keeps_the_button_home
  do
    local case = build({ isOpenAtSavedSpot = savedSpotOn })
    local frame = case.window.frame
    frame:Show()
    frame.scripts.OnDragStop(frame)
    assert(case.homeMoves == 0 and case.adopted == 0, "the window drag leaves the button's home alone")
  end

  -- test_dragging_the_riding_button_moves_the_window
  do
    local case = build({ isOpenAtSavedSpot = savedSpotOn })
    local frame = case.window.frame
    local moved = 0
    rawset(frame, "StartMoving", function()
      moved = moved + 1
    end)
    frame:Show()
    case.rideHandlers.beginDrag()
    assert(moved == 1, "the window moves")
    case.rideHandlers.endDrag()
    assert(case.homeMoves == 0 and case.adopted == 0, "the window is saved, the button's home is not")
  end

  -- test_closing_sends_home_the_button_it_docked_after_the_icon_mode_changed
  do
    local dockable = true
    local case
    case = build({
      getDockIcon = function()
        return dockable and case.icon or nil
      end,
    })
    case.window.frame:Show()
    assert(case.rides == 1, "docked")
    dockable = false
    case.window.frame:Hide()
    assert(case.homes == 1, "still goes home with the icon on the minimap")
  end

  -- test_a_resized_button_docks_again
  do
    local case = build()
    case.window.frame:Show()
    case.window.dockCompactIcon()
    assert(case.rides == 2, "takes its spot again")
  end

  -- test_with_no_button_the_window_just_opens
  do
    local case = build({
      getDockIcon = function()
        return nil
      end,
    })
    case.window.frame:Show()
    assert(case.window.frame:IsShown(), "minimap-only players still get the window")
  end

  -- test_settings_widen_the_window_and_closing_restores_it
  do
    local case = build()
    case.window.frame:Show()
    case.window.setOptionsVisible(true)
    assert(case.window.frame.width == Theme.WINDOW_WIDTH, "settings need room, got " .. tostring(case.window.frame.width))
    assert(not case.window.contactsPane:IsShown(), "panes covered")
    case.window.setOptionsVisible(false)
    assert(case.window.frame.width == L.COMPACT_WINDOW_WIDTH, "back to compact size, got " .. tostring(case.window.frame.width))
    assert(case.window.contactsPane:IsShown(), "list back")
    assert(not case.window.contentPane:IsShown(), "only the resting pane returns")
  end

  -- test_wide_size_is_never_saved_as_the_compact_size
  do
    local case = build()
    case.window.frame:Show()
    case.window.setOptionsVisible(true)
    case.saved.state = nil
    local frame = case.window.frame
    frame.scripts.OnDragStop(frame)
    assert(case.saved.state == nil, "settings width stays out of the saved compact size")
  end

  -- test_list_view_never_focuses_the_composer
  do
    local case = build({ settingsConfig = { showGroupChats = true, autoFocusComposer = true } })
    local focused = 0
    rawset(case.window.composer.input, "SetFocus", function()
      focused = focused + 1
    end)
    case.window.frame:Show()
    assert(focused == 0, "typing has nowhere to go on the list")
    select(case, "a")
    finishSlide(case)
    assert(focused == 1, "the chat takes focus when the setting is on")
  end

  -- test_hiding_mid_slide_finishes_it
  do
    local case = build()
    case.window.frame:Show()
    select(case, "a")
    finishSlide(case)
    case.window.backButton.scripts.OnClick(case.window.backButton)
    case.window.frame:Hide()
    assert(case.selections[#case.selections] == "none", "the slide cannot hang while hidden")
    assert(case.window.compactViewport.clipsChildren == false, "clipping released")
  end

  -- test_classic_window_is_unchanged
  do
    local case = build({ compactLayout = false })
    assert(case.window.frame.width == Theme.WINDOW_WIDTH, "classic size")
    assert(case.window.compactViewport == nil, "no viewport")
    assert(case.window.contentPane:IsShown(), "side by side")
  end
end
