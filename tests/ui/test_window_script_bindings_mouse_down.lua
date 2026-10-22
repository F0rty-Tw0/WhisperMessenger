local FakeUI = require("tests.helpers.fake_ui")
local ScriptBindings = require("WhisperMessenger.UI.MessengerWindow.WindowScripts.Frame.ScriptBindings")

local function noop() end

local function makeResizeStub()
  return {
    isResizing = function()
      return false
    end,
    stop = noop,
    reset = noop,
    start = noop,
    setHighlight = noop,
    updateFromCursor = noop,
  }
end

local function bindFrame(shownAtBind, factory)
  factory = factory or FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  local frame = factory.CreateFrame("Frame", nil, parent)
  frame.shown = shownAtBind == true
  local resizeStub = makeResizeStub()

  ScriptBindings.Bind({
    frame = frame,
    frameTheme = { WINDOW_ALPHA_UPDATE_INTERVAL = 0.1 },
    windowResize = resizeStub,
    contactsResize = resizeStub,
    relayoutWindow = noop,
    isSuppressSizeChangedRelayout = function()
      return false
    end,
    refreshWindowAlpha = noop,
    getAutoFocusChatInput = function()
      return false
    end,
    buildState = function()
      return {}
    end,
  })

  return frame
end

return function()
  -- test_hidden_frame_does_not_listen_for_global_mouse_down
  do
    local frame = bindFrame(false)
    assert(not frame:IsEventRegistered("GLOBAL_MOUSE_DOWN"), "hidden window must not run a handler on every click in the game")
  end

  -- test_show_registers_global_mouse_down
  do
    local frame = bindFrame(false)
    frame:Show()
    assert(frame:IsEventRegistered("GLOBAL_MOUSE_DOWN"), "shown window must listen for outside clicks")
  end

  -- test_hide_unregisters_global_mouse_down
  do
    local frame = bindFrame(false)
    frame:Show()
    frame:Hide()
    assert(not frame:IsEventRegistered("GLOBAL_MOUSE_DOWN"), "hiding the window must stop listening for clicks")
  end

  -- test_frame_shown_at_bind_registers_immediately
  do
    local frame = bindFrame(true)
    assert(frame:IsEventRegistered("GLOBAL_MOUSE_DOWN"), "window already shown at bind time must listen for outside clicks")
  end

  -- test_outside_click_still_demotes_strata_while_shown
  do
    local frame = bindFrame(false)
    frame:Show()
    assert(frame.frameStrata == "HIGH", "precondition: show promotes strata")
    frame.mouseOver = false
    frame.scripts.OnEvent(frame, "GLOBAL_MOUSE_DOWN", "LeftButton")
    assert(frame.frameStrata == "MEDIUM", "outside click must demote strata; got " .. tostring(frame.frameStrata))
  end

  -- The contacts tabs hang below the window's edge, so a click on one is
  -- outside the window's rectangle. It still belongs to the window and must
  -- bring it forward, not send it back.
  local FOCUS_API_NAMES = { "GetMouseFoci", "GetMouseFocus" }

  -- focusApiFor(tab) returns the focus globals to install, by name; a name
  -- left out is removed for the click.
  local function clickTabBelowWindow(focusApiFor)
    local factory = FakeUI.NewFactory()
    local frame = bindFrame(false, factory)
    local tab = factory.CreateFrame("Button", nil, factory.CreateFrame("Frame", nil, frame))
    frame:Show()
    frame.mouseOver = false
    frame.scripts.OnEvent(frame, "GLOBAL_MOUSE_DOWN", "LeftButton")
    assert(frame.frameStrata == "MEDIUM", "precondition: an outside click sent the window back")

    local api = focusApiFor(tab)
    local saved = {}
    for _, name in ipairs(FOCUS_API_NAMES) do
      saved[name] = _G[name]
      _G[name] = api[name]
    end
    local ok, err = pcall(frame.scripts.OnEvent, frame, "GLOBAL_MOUSE_DOWN", "LeftButton")
    for _, name in ipairs(FOCUS_API_NAMES) do
      _G[name] = saved[name]
    end
    assert(ok, err)
    return frame
  end

  -- test_click_on_tab_below_window_brings_it_forward
  do
    local frame = clickTabBelowWindow(function(tab)
      return {
        GetMouseFoci = function()
          return { tab }
        end,
      }
    end)
    assert(frame.frameStrata == "HIGH", "clicking a tab must bring the window forward; got " .. tostring(frame.frameStrata))
  end

  -- test_click_on_tab_brings_window_forward_on_classic_focus_api
  do
    local frame = clickTabBelowWindow(function(tab)
      return {
        GetMouseFocus = function()
          return tab
        end,
      }
    end)
    assert(frame.frameStrata == "HIGH", "Classic GetMouseFocus path must also bring the window forward; got " .. tostring(frame.frameStrata))
  end

  -- test_click_on_forbidden_frame_counts_as_outside
  -- Nameplates in instances are forbidden: any method but IsForbidden throws.
  do
    local frame = clickTabBelowWindow(function()
      local forbidden = {
        IsForbidden = function()
          return true
        end,
        GetParent = function()
          error("Attempt to access forbidden object from code tainted by an AddOn")
        end,
      }
      return {
        GetMouseFoci = function()
          return { forbidden }
        end,
      }
    end)
    assert(frame.frameStrata == "MEDIUM", "a click on a forbidden frame is outside the window; got " .. tostring(frame.frameStrata))
  end

  -- test_click_on_window_covering_messenger_sends_it_back
  -- The Auction House sits on top of the messenger: the cursor is inside the
  -- messenger's rectangle, but the frame under it is the Auction House.
  do
    local factory = FakeUI.NewFactory()
    local frame = bindFrame(false, factory)
    local auctionHouse = factory.CreateFrame("Frame", "AuctionHouseFrame", nil)
    frame:Show()
    frame.mouseOver = true
    local savedFoci = _G.GetMouseFoci
    rawset(_G, "GetMouseFoci", function()
      return { auctionHouse }
    end)
    local ok, err = pcall(frame.scripts.OnEvent, frame, "GLOBAL_MOUSE_DOWN", "LeftButton")
    _G.GetMouseFoci = savedFoci
    assert(ok, err)
    assert(frame.frameStrata == "MEDIUM", "a click on a window covering the messenger must not bring it forward; got " .. tostring(frame.frameStrata))
  end

  -- test_click_on_own_popup_keeps_the_window_in_front
  -- The reaction picker and dialogs are parented to UIParent, outside the
  -- window, but they belong to it: a click there is a click on the window.
  do
    local PickerPopup = require("WhisperMessenger.UI.Shared.PickerPopup")
    local saved = { _G.UISpecialFrames, _G.GetMouseFoci, _G.WhisperMessengerTestOwnPopup }
    local factory = FakeUI.NewFactory()
    local frame = bindFrame(false, factory)
    frame.name = "WhisperMessengerWindow"
    local popup = factory.CreateFrame("Frame", "WhisperMessengerTestOwnPopup", nil)
    popup:Show()
    _G.UISpecialFrames = {}
    rawset(_G, "WhisperMessengerTestOwnPopup", popup)
    rawset(_G, "GetMouseFoci", function()
      return { factory.CreateFrame("Button", nil, popup) }
    end)
    local ok, err = pcall(function()
      PickerPopup.RegisterEscape("WhisperMessengerTestOwnPopup")
      frame:Show()
      frame.scripts.OnEvent(frame, "GLOBAL_MOUSE_DOWN", "LeftButton")
      assert(frame.frameStrata == "HIGH", "a click on the window's own popup must keep it in front; got " .. tostring(frame.frameStrata))
      local listed = false
      for _, name in ipairs(_G.UISpecialFrames) do
        listed = listed or name == "WhisperMessengerWindow"
      end
      assert(listed, "a click on the window's own popup must keep ESC on the window")
    end)
    _G.UISpecialFrames = saved[1]
    rawset(_G, "GetMouseFoci", saved[2])
    rawset(_G, "WhisperMessengerTestOwnPopup", saved[3])
    assert(ok, err)
  end

  -- test_escape_follows_the_clicked_window
  do
    local saved = { _G.UISpecialFrames, _G.GetUIPanel, _G.GetMouseFoci }
    local factory = FakeUI.NewFactory()
    local frame = bindFrame(false, factory)
    frame.name = "WhisperMessengerWindow"
    local auctionHouse = factory.CreateFrame("Frame", "AuctionHouseFrame", nil)
    auctionHouse:Show()
    _G.UISpecialFrames = {}
    rawset(_G, "GetUIPanel", function(slot)
      return slot == "doublewide" and auctionHouse or nil
    end)
    rawset(_G, "GetMouseFoci", function()
      return { auctionHouse }
    end)
    local ok, err = pcall(function()
      frame:Show()
      assert(_G.UISpecialFrames[1] == "WhisperMessengerWindow", "showing the window must give it ESC")
      frame.scripts.OnEvent(frame, "GLOBAL_MOUSE_DOWN", "LeftButton")
      assert(#_G.UISpecialFrames == 0, "clicking the Auction House must give ESC to it")
    end)
    _G.UISpecialFrames = saved[1]
    rawset(_G, "GetUIPanel", saved[2])
    rawset(_G, "GetMouseFoci", saved[3])
    assert(ok, err)
  end
end
