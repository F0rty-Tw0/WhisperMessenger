local PhoneWindow = require("tests.helpers.phone_window")
local PhoneRuntime = require("tests.helpers.phone_runtime")
local RetailHud = require("tests.helpers.retail_hud")
local Theme = require("WhisperMessenger.UI.Theme")
local DockWiring = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.DockWiring")
local SettingsHandler = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.SettingsHandler")
local withPopups = require("tests.helpers.reload_popups").With

local L = Theme.LAYOUT
local LAYOUTS = { { name = "compact", phone = true }, { name = "regular", phone = false } }

local function eachLayout(run)
  for _, layout in ipairs(LAYOUTS) do
    run(layout.name, layout.phone)
  end
end

local function titleOffset(case)
  return select(4, case.window.newConversationButton:GetPoint())
end

local function at(region, left, top)
  rawset(region, "GetLeft", function()
    return left
  end)
  rawset(region, "GetTop", function()
    return top
  end)
end

return function()
  -- test_opening_docks_the_button_on_the_spot_and_clears_the_title_buttons
  eachLayout(function(name, phone)
    local case = PhoneWindow.Build({ phoneLayout = phone })
    case.window.frame:Show()
    assert(case.rides == 1 and case.rodeTo.region ~= nil, name .. ": the button rides the spot, got " .. case.rides)
    assert(case.rideHandlers ~= nil and case.rideStrata == "HIGH", name .. ": drag handlers and the window's strata")
    assert(
      titleOffset(case) == L.TITLE_BAR_INSET_X + L.PHONE_ICON_SLOT_CLEARANCE,
      name .. ": title buttons shifted, got " .. tostring(titleOffset(case))
    )
  end)

  -- test_closing_sends_the_button_home
  eachLayout(function(name, phone)
    local case = PhoneWindow.Build({ phoneLayout = phone })
    case.window.frame:Show()
    case.window.closeButton.scripts.OnClick(case.window.closeButton)
    assert(case.homes == 1, name .. ": home on close, got " .. case.homes)
  end)

  -- test_dragging_by_the_button_moves_and_saves_the_window
  eachLayout(function(name, phone)
    local case = PhoneWindow.Build({ phoneLayout = phone })
    local frame, moved = case.window.frame, 0
    rawset(frame, "StartMoving", function()
      moved = moved + 1
    end)
    frame:Show()
    case.rideHandlers.beginDrag()
    case.rideHandlers.endDrag()
    assert(moved == 1, name .. ": the window moves")
    assert(case.saved.state ~= nil and case.saved.state.width == frame:GetWidth(), name .. ": the window is saved at its width")
  end)

  -- test_strata_follows_the_window
  eachLayout(function(name, phone)
    local case = PhoneWindow.Build({ phoneLayout = phone })
    local frame = case.window.frame
    frame:Show()
    frame.scripts.OnEvent(frame, "GLOBAL_MOUSE_DOWN")
    assert(case.rideStrata == "MEDIUM", name .. ": a click elsewhere sends the button back with the window")
    frame.scripts.OnMouseDown(frame)
    assert(case.rideStrata == "HIGH", name .. ": a click on the window brings both forward")
  end)

  -- test_dock_phone_icon_re_docks_in_both_layouts  (scale, icon mode, icon size route here)
  eachLayout(function(name, phone)
    local case = PhoneWindow.Build({ phoneLayout = phone })
    assert(type(case.window.dockPhoneIcon) == "function", name .. ": exposed")
    case.window.frame:Show()
    case.window.dockPhoneIcon()
    assert(case.rides == 2, name .. ": takes its spot again, got " .. case.rides)
  end)

  -- test_the_corner_follows_the_icon_mode_with_the_window_open
  eachLayout(function(name, phone)
    local dockable, case = true, nil
    case = PhoneWindow.Build({
      phoneLayout = phone,
      getDockIcon = function()
        return dockable and case.icon or nil
      end,
    })
    case.window.frame:Show()
    dockable = false
    case.window.dockPhoneIcon()
    assert(titleOffset(case) == L.TITLE_BAR_INSET_X, name .. ": room comes back when the button leaves")
    dockable = true
    case.window.dockPhoneIcon()
    assert(titleOffset(case) == L.TITLE_BAR_INSET_X + L.PHONE_ICON_SLOT_CLEARANCE, name .. ": and goes again")
  end)

  -- test_opening_clamps_the_window_over_its_spot
  eachLayout(function(name, phone)
    local case = PhoneWindow.Build({ phoneLayout = phone })
    local frame = case.window.frame
    frame:Show()
    at(frame, 100, 900)
    at(case.rodeTo.region, 93, 917)
    frame:Hide()
    frame:Show()
    local left, _, top = frame:GetClampRectInsets()
    assert(left == -7 and top == 17, name .. ": got " .. tostring(left) .. "," .. tostring(top))
  end)

  -- test_alt_z_hide_and_show_neither_closes_nor_replays  (Review Focus 3: grow and dock part)
  eachLayout(function(name, phone)
    local case = PhoneWindow.Build({ phoneLayout = phone })
    local frame = case.window.frame
    frame:Show()
    case.step(1, 1)
    frame.shown = true
    PhoneWindow.Fire(frame, "OnHide")
    assert(case.homes == 0, name .. ": Alt+Z hid the parent, not the window")
    PhoneWindow.Fire(frame, "OnShow")
    assert(frame:GetAlpha() == 1 and case.homes == 0, name .. ": coming back replays nothing")
  end)

  -- test_a_runtime_style_switch_attaches_nothing_twice  (Review Focus 4)
  eachLayout(function(name, phone)
    local case = PhoneWindow.Build({ phoneLayout = phone })
    local frame = case.window.frame
    local shows, hides = #frame._hookScripts.OnShow, #frame._hookScripts.OnHide
    withPopups(function(popups)
      local onChange = SettingsHandler.Create({
        runtime = { store = { config = {} }, phoneLayoutActive = phone, window = case.window },
        accountSettings = {},
      })
      onChange("phoneLayout", not phone)
      _G.StaticPopupDialogs[popups.shown[1]].OnCancel()
    end)
    assert(#frame._hookScripts.OnShow == shows and #frame._hookScripts.OnHide == hides, name .. ": hook counts unchanged")
    frame:Show()
    assert(case.rides == 1, name .. ": one dock, not two, got " .. case.rides)
  end)

  -- test_the_regular_window_docks_the_real_button_and_it_stays_clickable  (acceptance: Classic and Retail chrome)
  local function clickable(label, settings)
    PhoneRuntime.Run(settings, function(runtime)
      runtime.toggle()
      local icon = runtime.icon
      assert(icon.isRiding(), label .. ": rides the regular window")
      icon.frame.scripts.OnClick(icon.frame, "LeftButton")
      assert(not runtime.window.frame:IsShown(), label .. ": a click on the docked button closes the window")
      assert(not icon.isRiding(), label .. ": and it heads home")
    end)
  end
  clickable("regular custom", { phoneLayout = false, hudStyle = "off" })
  clickable("regular classic", { phoneLayout = false, hudStyle = "classic" })
  RetailHud.With(function()
    clickable("regular retail", { phoneLayout = false, hudStyle = "retail" })
  end)

  -- test_classic_grow_is_gone
  assert(not pcall(require, "WhisperMessenger.UI.MessengerWindow.MessengerWindow.ClassicGrow"), "module removed")
  for line in io.lines("WhisperMessenger.toc") do
    assert(not string.find(line, "ClassicGrow", 1, true), "TOC still lists " .. line)
  end

  -- test_glide_off_jumps_the_button_but_the_window_still_grows
  eachLayout(function(name, phone)
    local case = PhoneWindow.Build({
      phoneLayout = phone,
      isIconGlideOn = function()
        return false
      end,
    })
    local frame = case.window.frame
    frame:Show()
    assert(case.instant == true and case.step == nil, name .. ": the button jumps onto the spot")
    assert(frame:GetAlpha() == 0, name .. ": the window grows from the button")
    frame:Hide()
    assert(case.homeInstant == true, name .. ": and jumps home")
  end)

  -- test_wrapped_position_adopts_the_buttons_spot_before_saving
  do
    local calls = {}
    local hooks = DockWiring.Hooks()
    local wrapped = DockWiring.WrapPosition(hooks, function(state)
      calls[#calls + 1] = "saved " .. state.tag
    end)
    hooks.onWindowMoved()
    wrapped({ tag = "idle" })
    assert(table.concat(calls, ",") == "saved idle", "idle hooks do nothing before the save")
    hooks.onWindowMoved = function()
      calls[#calls + 1] = "adopted"
    end
    wrapped({ tag = "moved" })
    assert(table.concat(calls, ",") == "saved idle,adopted,saved moved", "adopt first, then save, got " .. table.concat(calls, ","))
  end
end
