local PhoneWindow = require("tests.helpers.phone_window")
local PhoneRuntime = require("tests.helpers.phone_runtime")
local Theme = require("WhisperMessenger.UI.Theme")

-- Dock button on the window, in both layouts: on (the default), the floating
-- button rides the window's corner; off, it stays where it is, and the option
-- flips live while the window is open.

local L = Theme.LAYOUT

local LAYOUTS = {
  { name = "compact", phone = true },
  { name = "regular", phone = false },
}

local function sameAnchor(before, after, name, what)
  for i = 1, 5 do
    assert(after[i] == before[i], name .. ": " .. what .. " (anchor part " .. i .. ")")
  end
end

local function titleOffset(runtime)
  return select(4, runtime.window.newConversationButton:GetPoint())
end

local function offCase(phone)
  local case = PhoneWindow.Build({
    phoneLayout = phone,
    isIconDockOn = function()
      return false
    end,
    isOpenAtSavedSpot = function()
      return false
    end,
  })
  PhoneWindow.Lay(case)
  return case
end

return function()
  for _, layout in ipairs(LAYOUTS) do
    local name = layout.name

    local function run(settings, body)
      settings.phoneLayout, settings.hudStyle = layout.phone, "off"
      PhoneRuntime.Run(settings, body)
    end

    -- test_off_opens_the_window_and_the_button_stays_put
    run({ iconDock = false }, function(runtime)
      local icon = runtime.icon
      local before = { icon.frame:GetPoint() }
      runtime.toggle()
      assert(runtime.window.frame:IsShown(), name .. ": the window opens")
      assert(not icon.isRiding() and icon.frame:GetScale() == 1, name .. ": the button is not scaled or riding")
      sameAnchor(before, { icon.frame:GetPoint() }, name, "the button moved")
      assert(titleOffset(runtime) == L.TITLE_BAR_INSET_X, name .. ": title buttons at the left edge")
    end)

    -- test_a_missing_option_docks_like_on
    run({}, function(runtime)
      runtime.toggle()
      assert(runtime.icon.isRiding(), name .. ": nil iconDock is on")
    end)

    -- test_on_to_off_and_back_while_the_window_is_open
    run({ windowAnimation = false }, function(runtime)
      local icon, settings = runtime.icon, runtime.accountState.settings
      runtime.toggle()
      assert(icon.isRiding(), name .. ": docked on open")
      settings.iconDock = false
      runtime.window.dockPhoneIcon()
      assert(not icon.isRiding() and icon.frame:GetScale() == 1, name .. ": home at its floating size")
      assert(titleOffset(runtime) == L.TITLE_BAR_INSET_X, name .. ": corner free")
      settings.iconDock = true
      runtime.window.dockPhoneIcon()
      assert(icon.isRiding(), name .. ": docks again")
      assert(titleOffset(runtime) == L.TITLE_BAR_INSET_X + L.PHONE_ICON_SLOT_CLEARANCE, name .. ": corner taken")
      runtime.toggle()
      assert(not icon.isRiding(), name .. ": closing sends it home")
    end)

    -- test_close_then_off_then_reopen_leaves_the_button_home
    run({}, function(runtime)
      local icon, settings = runtime.icon, runtime.accountState.settings
      runtime.toggle()
      runtime.toggle()
      settings.iconDock = false
      runtime.toggle()
      assert(runtime.window.frame:IsShown(), name .. ": open")
      assert(not icon.isRiding() and icon.frame:GetScale() == 1, name .. ": ends home, not stuck scaled or docked")
      assert(titleOffset(runtime) == L.TITLE_BAR_INSET_X, name .. ": corner free")
    end)

    -- test_off_with_open_at_saved_spot_off_opens_at_the_saved_spot_not_on_the_button
    do
      local case = offCase(layout.phone)
      local before = { case.window.frame:GetPoint() }
      case.window.frame:Show()
      sameAnchor(before, { case.window.frame:GetPoint() }, name, "the window was placed on the button")
      assert(case.rides == 0, name .. ": nothing docked")
    end

    -- test_off_moving_the_window_leaves_the_button
    do
      local case = offCase(layout.phone)
      case.window.frame:Show()
      case.window.frame.scripts.OnDragStop(case.window.frame)
      assert(case.adopted == 0, name .. ": the button is not riding, so it is not adopted")
    end
  end
end
