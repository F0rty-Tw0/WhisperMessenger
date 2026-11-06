local PhoneRuntime = require("tests.helpers.phone_runtime")
local Hud = require("WhisperMessenger.UI.Theme.Hud")
local Theme = require("WhisperMessenger.UI.Theme")

-- The HUD styles with no round portrait, which is every Classic client: the
-- button docks on the corner spot the window makes for it.

local L = Theme.LAYOUT
local WINDOW_SCALE = 1.25

local function slotScale(icon, windowScale)
  return L.PHONE_ICON_SLOT_SIZE * windowScale / icon.frame:GetWidth()
end

return function()
  for _, hudStyle in ipairs({ "off", "classic" }) do
    -- test_the_button_docks_on_the_corner_spot_and_goes_home
    PhoneRuntime.Run({ hudStyle = hudStyle }, function(runtime)
      runtime.toggle()
      local icon = runtime.icon
      assert(icon.isRiding(), hudStyle .. ": rides the window")
      assert(icon.frame:GetScale() == slotScale(icon, 1), hudStyle .. ": fills the spot, got " .. tostring(icon.frame:GetScale()))
      runtime.window.frame:Hide()
      assert(not icon.isRiding(), hudStyle .. ": heads home")
      assert(icon.frame:GetScale() == 1, hudStyle .. ": normal size")
    end)

    -- test_the_real_button_follows_the_window_back_and_goes_home_high
    PhoneRuntime.Run({ hudStyle = hudStyle }, function(runtime)
      runtime.toggle()
      local frame, button = runtime.window.frame, runtime.icon.frame
      assert(button:GetFrameStrata() == "HIGH", hudStyle .. ": forward with the window")
      frame.scripts.OnEvent(frame, "GLOBAL_MOUSE_DOWN")
      assert(button:GetFrameStrata() == "MEDIUM", hudStyle .. ": back with the window")
      assert(button:GetFrameLevel() == L.PHONE_RIDE_FRAME_LEVEL, hudStyle .. ": still above it")
      frame:Hide()
      assert(not runtime.icon.isRiding(), hudStyle .. ": home")
      assert(button:GetFrameStrata() == "HIGH", hudStyle .. ": above action bars again at home")
    end)

    -- test_a_window_scale_change_keeps_the_button_on_the_spot
    PhoneRuntime.Run({ hudStyle = hudStyle }, function(runtime)
      runtime.toggle()
      runtime.window.setScale(WINDOW_SCALE)
      local icon = runtime.icon
      assert(icon.frame:GetScale() == slotScale(icon, WINDOW_SCALE), hudStyle .. ": got " .. tostring(icon.frame:GetScale()))
      runtime.window.setScale(1)
      assert(icon.frame:GetScale() == slotScale(icon, 1), hudStyle .. ": back, got " .. tostring(icon.frame:GetScale()))
    end)
  end
  Hud.Configure("off")
end
