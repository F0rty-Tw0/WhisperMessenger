local FakeUI = require("tests.helpers.fake_ui")
local MinimapIcon = require("WhisperMessenger.UI.MinimapIcon.MinimapIcon")

local function makeParent(factory)
  local parent = factory.CreateFrame("Frame", "Minimap", nil)
  parent:SetSize(140, 140)
  return parent
end

return function()
  -- test_default_position_lands_on_the_minimap_ring
  do
    local factory = FakeUI.NewFactory()
    local parent = makeParent(factory)
    local icon = MinimapIcon.Create(factory, { parent = parent })

    local point, relativeTo, relativePoint, x, y = icon.frame:GetPoint()
    assert(point == "CENTER" and relativePoint == "CENTER", "icon anchors CENTER to CENTER")
    assert(relativeTo == parent, "icon anchors to the minimap parent")
    -- 45 degrees on a 140px round minimap with a 5px ring offset: cos(45) * 75
    local expected = math.cos(math.rad(45)) * 75
    assert(math.abs(x - expected) < 0.01, "x lands on the ring; got: " .. tostring(x))
    assert(math.abs(y - expected) < 0.01, "y lands on the ring; got: " .. tostring(y))
  end

  -- test_saved_degrees_override_default_position
  do
    local factory = FakeUI.NewFactory()
    local parent = makeParent(factory)
    local icon = MinimapIcon.Create(factory, { parent = parent, state = { degrees = 180 } })

    local _, _, _, x, y = icon.frame:GetPoint()
    assert(math.abs(x - -75) < 0.01, "180 degrees places the icon left of center; got: " .. tostring(x))
    assert(math.abs(y) < 0.01, "180 degrees keeps the icon vertically centered; got: " .. tostring(y))
  end

  -- test_desaturation_clears_when_unread_arrives
  do
    local factory = FakeUI.NewFactory()
    local icon = MinimapIcon.Create(factory, {
      parent = makeParent(factory),
      getIconDesaturated = function()
        return true
      end,
    })

    assert(icon.iconTex.desaturated == true, "icon starts desaturated while idle")
    icon.setUnreadCount(3)
    assert(icon.iconTex.desaturated == false, "unread messages re-saturate the icon")
    icon.setUnreadCount(0)
    assert(icon.iconTex.desaturated == true, "icon desaturates again when idle")
  end

  -- test_desaturation_setting_off_keeps_icon_saturated
  do
    local factory = FakeUI.NewFactory()
    local icon = MinimapIcon.Create(factory, {
      parent = makeParent(factory),
      getIconDesaturated = function()
        return false
      end,
    })

    assert(icon.iconTex.desaturated ~= true, "icon stays saturated when the setting is off")
  end

  -- test_badge_hidden_when_show_badge_disabled
  do
    local factory = FakeUI.NewFactory()
    local icon = MinimapIcon.Create(factory, {
      parent = makeParent(factory),
      getShowUnreadBadge = function()
        return false
      end,
    })

    icon.setUnreadCount(5)
    assert(icon.badge:IsShown() == false, "badge stays hidden when disabled")
  end

  -- test_set_shown_false_hides_frame_and_preview
  do
    local factory = FakeUI.NewFactory()
    local icon = MinimapIcon.Create(factory, { parent = makeParent(factory) })

    icon.setIncomingPreview("Jaina-Proudmoore", "Need assistance?", "MAGE")
    assert(icon.previewFrame:IsShown() == true, "preview shows on incoming message")

    icon.setShown(false)
    assert(icon.frame:IsShown() == false, "icon frame hides")
    assert(icon.previewFrame:IsShown() == false, "floating preview hides with the icon")

    icon.setShown(true)
    assert(icon.frame:IsShown() == true, "icon frame shows again")
  end

  -- test_drag_persists_degrees
  do
    local factory = FakeUI.NewFactory()
    local parent = makeParent(factory)
    parent.GetCenter = function()
      return 0, 0
    end
    parent.GetEffectiveScale = function()
      return 1
    end

    local savedState
    local originalGetCursorPosition = rawget(_G, "GetCursorPosition")
    rawset(_G, "GetCursorPosition", function()
      return 0, 100 -- straight up from the minimap center
    end)

    local icon = MinimapIcon.Create(factory, {
      parent = parent,
      onPositionChanged = function(nextState)
        savedState = nextState
      end,
    })

    icon.frame:GetScript("OnDragStart")(icon.frame)
    icon.frame:GetScript("OnUpdate")(icon.frame)
    icon.frame:GetScript("OnDragStop")(icon.frame)

    rawset(_G, "GetCursorPosition", originalGetCursorPosition)

    assert(savedState ~= nil, "drag stop persists the position")
    assert(math.abs(savedState.degrees - 90) < 0.01, "cursor straight up persists 90 degrees; got: " .. tostring(savedState.degrees))
  end
end
