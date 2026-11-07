local CompactRuntime = require("tests.helpers.compact_runtime")
local Hud = require("WhisperMessenger.UI.Theme.Hud")
local RetailHud = require("tests.helpers.retail_hud")
local Theme = require("WhisperMessenger.UI.Theme")

-- The button docks on the corner spot, on every HUD and for every widget shape.
-- The HUD styles with no round portrait, which is every Classic client, get a
-- corner spot the window makes for it.

local L = Theme.LAYOUT
local WINDOW_SCALE = 1.25

local function slotScale(icon, windowScale)
  return L.COMPACT_ICON_SLOT_SIZE * windowScale / icon.frame:GetWidth()
end

-- The spot the docked button sits on: the corner spot on the custom and
-- Classic windows, the portrait on Retail.
local function assertOnCorner(label, runtime, hudStyle)
  local icon = runtime.icon
  assert(icon.isRiding(), label .. ": rides the window")
  local _, spot = icon.frame:GetPoint()
  if hudStyle == "retail" then
    assert(spot == runtime.window.frame.PortraitContainer.portrait, label .. ": on the portrait")
    return
  end
  local point, _, relativePoint, x, y = spot:GetPoint()
  assert(spot:GetWidth() == L.COMPACT_ICON_SLOT_SIZE, label .. ": the corner spot's size, got " .. tostring(spot:GetWidth()))
  assert(
    point == "CENTER" and relativePoint == "TOPLEFT" and x == L.COMPACT_ICON_SLOT_X and y == L.COMPACT_ICON_SLOT_Y,
    label .. ": at the corner, got " .. tostring(point) .. "," .. tostring(x) .. "," .. tostring(y)
  )
end

return function()
  -- test_a_square_button_docks_on_the_corner_spot_like_the_circle
  for _, compactMode in ipairs({ true, false }) do
    for _, hudStyle in ipairs({ "off", "classic", "retail" }) do
      for _, shape in ipairs({ "circle", "square" }) do
        local label = (compactMode and "compact " or "regular ") .. hudStyle .. " " .. shape
        local settings = { compactLayout = compactMode, hudStyle = hudStyle, widgetShape = shape, windowAnimation = false }
        local function run()
          CompactRuntime.Run(settings, function(runtime)
            runtime.toggle()
            assertOnCorner(label, runtime, hudStyle)
            runtime.window.dockCompactIcon() -- what an icon size or mode change does
            assertOnCorner(label .. " after a re-dock", runtime, hudStyle)
          end)
        end
        if hudStyle == "retail" then
          RetailHud.With(run)
        else
          run()
        end
      end
    end
  end

  for _, hudStyle in ipairs({ "off", "classic" }) do
    -- test_the_button_docks_on_the_corner_spot_and_goes_home
    CompactRuntime.Run({ hudStyle = hudStyle }, function(runtime)
      runtime.toggle()
      local icon = runtime.icon
      assert(icon.isRiding(), hudStyle .. ": rides the window")
      assert(icon.frame:GetScale() == slotScale(icon, 1), hudStyle .. ": fills the spot, got " .. tostring(icon.frame:GetScale()))
      runtime.window.frame:Hide()
      assert(not icon.isRiding(), hudStyle .. ": heads home")
      assert(icon.frame:GetScale() == 1, hudStyle .. ": normal size")
    end)

    -- test_the_real_button_follows_the_window_back_and_goes_home_high
    CompactRuntime.Run({ hudStyle = hudStyle }, function(runtime)
      runtime.toggle()
      local frame, button = runtime.window.frame, runtime.icon.frame
      assert(button:GetFrameStrata() == "HIGH", hudStyle .. ": forward with the window")
      frame.scripts.OnEvent(frame, "GLOBAL_MOUSE_DOWN")
      assert(button:GetFrameStrata() == "MEDIUM", hudStyle .. ": back with the window")
      assert(button:GetFrameLevel() == L.COMPACT_RIDE_FRAME_LEVEL, hudStyle .. ": still above it")
      frame:Hide()
      assert(not runtime.icon.isRiding(), hudStyle .. ": home")
      assert(button:GetFrameStrata() == "HIGH", hudStyle .. ": above action bars again at home")
    end)

    -- test_a_window_scale_change_keeps_the_button_on_the_spot
    CompactRuntime.Run({ hudStyle = hudStyle }, function(runtime)
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
