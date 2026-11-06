local MessengerWindow = require("WhisperMessenger.UI.MessengerWindow")
local ContactsList = require("WhisperMessenger.UI.ContactsList")
local Hud = require("WhisperMessenger.UI.Theme.Hud")
local Theme = require("WhisperMessenger.UI.Theme")
local FakeUI = require("tests.helpers.fake_ui")

local L = Theme.LAYOUT

-- The phone layout end to end: list and chat in one narrow window, the slide
-- between them, the back button, settings widening, and the tie to the button.

local function contacts()
  return ContactsList.BuildItems({
    ["me::WOW::jaina"] = { displayName = "Jaina", channel = "WOW", lastActivityAt = 2, unreadCount = 1 },
    ["guild::me"] = { displayName = "Guild", channel = "GUILD", lastActivityAt = 1, unreadCount = 0 },
  })
end

local function build(extra)
  Hud.Configure("off")
  local factory = FakeUI.NewFactory()
  local savedUIParent = _G.UIParent
  _G.UIParent = factory.CreateFrame("Frame", "UIParent", nil)
  _G.UIParent:SetSize(1920, 1080)
  local case = { saved = {}, selections = {} }
  local fab = factory.CreateFrame("Button", "Fab", _G.UIParent)
  rawset(fab, "GetCenter", function()
    return 800, 500
  end)
  case.fab = fab
  case.rides, case.homes, case.adopted = 0, 0, 0
  case.icon = {
    frame = fab,
    isRiding = function()
      return case.rides > case.homes
    end,
    rideTo = function(target, onStep)
      case.rides = case.rides + 1
      case.rodeTo = target
      case.step = onStep
    end,
    rideHome = function(onStep)
      case.homes = case.homes + 1
      case.step = onStep
    end,
    adoptRidePosition = function()
      case.adopted = case.adopted + 1
    end,
    setRideHandlers = function(handlers)
      case.rideHandlers = handlers
    end,
  }
  local options = {
    contacts = contacts(),
    state = {},
    phoneLayout = true,
    settingsConfig = { showGroupChats = true },
    getDockIcon = function()
      return case.icon
    end,
    onPositionChanged = function(state)
      case.saved.state = state
    end,
    onSelectConversation = function(key)
      case.selections[#case.selections + 1] = key == nil and "none" or key
      return nil
    end,
  }
  for key, value in pairs(extra or {}) do
    options[key] = value
  end
  case.window = MessengerWindow.Create(factory, options)
  rawset(case.window.frame, "GetEffectiveScale", function()
    return 1
  end)
  _G.UIParent = savedUIParent
  return case
end

local function select(case, key)
  local item = { conversationKey = key, displayName = key, channel = "WOW" }
  case.window.refreshSelection({ selectedContact = item })
end

local function finishSlide(case)
  local viewport = case.window.phoneViewport
  if viewport.scripts and viewport.scripts.OnUpdate then
    viewport.scripts.OnUpdate(viewport, L.PHONE_SLIDE_SECONDS + 0.01)
  end
end

return function()
  -- test_window_opens_phone_sized
  do
    local case = build()
    assert(case.window.frame.width == L.PHONE_WINDOW_WIDTH, "got " .. tostring(case.window.frame.width))
    assert(case.window.frame.height == L.PHONE_WINDOW_HEIGHT, "got " .. tostring(case.window.frame.height))
    assert(case.window.isPhoneLayout == true, "reports the layout")
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
    frame:Show()
    assert(frame:GetAlpha() == 1, "already open, so it stays visible")
  end

  -- test_window_grows_out_of_its_top_left_corner_spot
  do
    local case = build()
    case.window.frame:Show()
    local point, relativeTo = case.window.frame:GetPoint()
    assert(point == "TOPLEFT" and relativeTo ~= case.fab, "the window is screen-anchored; the button follows it")
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

  -- test_moving_the_window_moves_the_button_home
  do
    local case = build()
    local frame = case.window.frame
    frame:Show()
    frame.scripts.OnDragStop(frame)
    assert(case.adopted == 1, "the button stays with the window")
  end

  -- test_dragging_the_riding_button_moves_the_window
  do
    local case = build()
    local frame = case.window.frame
    local moved = 0
    rawset(frame, "StartMoving", function()
      moved = moved + 1
    end)
    frame:Show()
    case.rideHandlers.beginDrag()
    assert(moved == 1, "the window moves")
    case.rideHandlers.endDrag()
    assert(case.adopted == 1, "and the button's home with it")
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
    assert(case.window.frame.width == L.PHONE_WINDOW_WIDTH, "back to phone size, got " .. tostring(case.window.frame.width))
    assert(case.window.contactsPane:IsShown(), "list back")
    assert(not case.window.contentPane:IsShown(), "only the resting pane returns")
  end

  -- test_wide_size_is_never_saved_as_the_phone_size
  do
    local case = build()
    case.window.frame:Show()
    case.window.setOptionsVisible(true)
    case.saved.state = nil
    local frame = case.window.frame
    frame.scripts.OnDragStop(frame)
    assert(case.saved.state == nil, "settings width stays out of the saved phone size")
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
    assert(case.window.phoneViewport.clipsChildren == false, "clipping released")
  end

  -- test_classic_window_is_unchanged
  do
    local case = build({ phoneLayout = false })
    assert(case.window.frame.width == Theme.WINDOW_WIDTH, "classic size")
    assert(case.window.phoneViewport == nil, "no viewport")
    assert(case.window.contentPane:IsShown(), "side by side")
  end
end
