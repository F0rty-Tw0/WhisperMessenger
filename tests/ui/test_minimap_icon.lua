local FakeUI = require("tests.helpers.fake_ui")
local MinimapIcon = require("WhisperMessenger.UI.MinimapIcon.MinimapIcon")
local Theme = require("WhisperMessenger.UI.Theme")
local Desaturation = require("WhisperMessenger.UI.ToggleIcon.Desaturation")

local function sameColor(a, b)
  return type(a) == "table" and type(b) == "table" and a[1] == b[1] and a[2] == b[2] and a[3] == b[3] and (a[4] or 1) == (b[4] or 1)
end

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

  -- test_apply_radial_position_with_degrees_moves_the_button
  do
    local factory = FakeUI.NewFactory()
    local parent = makeParent(factory)
    local icon = MinimapIcon.Create(factory, { parent = parent })

    icon.applyRadialPosition({ degrees = 90 })

    local _, relativeTo, _, x, y = icon.frame:GetPoint()
    assert(relativeTo == parent, "the button stays on the minimap parent")
    assert(math.abs(x) < 0.01, "90 degrees is straight up, x ~ 0; got: " .. tostring(x))
    assert(math.abs(y - 75) < 0.01, "ring radius 70 + 5 above center; got: " .. tostring(y))
  end

  -- test_apply_radial_position_with_empty_state_uses_the_default_angle
  do
    local factory = FakeUI.NewFactory()
    local fresh = MinimapIcon.Create(factory, { parent = makeParent(factory) })
    local _, _, _, freshX, freshY = fresh.frame:GetPoint()
    local moved = MinimapIcon.Create(factory, { parent = makeParent(factory), state = { degrees = 180 } })

    moved.applyRadialPosition({})

    local _, _, _, x, y = moved.frame:GetPoint()
    assert(math.abs(x - freshX) < 0.01 and math.abs(y - freshY) < 0.01, "an empty state lands on the default angle; got: " .. tostring(x))
  end

  -- test_apply_radial_position_without_a_state_keeps_the_current_angle
  do
    local factory = FakeUI.NewFactory()
    local icon = MinimapIcon.Create(factory, { parent = makeParent(factory), state = { degrees = 180 } })

    icon.applyRadialPosition()

    local _, _, _, x = icon.frame:GetPoint()
    assert(math.abs(x - -75) < 0.01, "no argument keeps the saved angle; got: " .. tostring(x))
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

    assert(icon.iconTex.desaturated ~= true, "front bubble is never desaturated")
    assert(icon.background.desaturated ~= true, "circle is never desaturated")
    assert(sameColor(icon.accentGlyph.vertexColor, Desaturation.DESAT_BACK), "back bubble gray while idle")
    icon.setUnreadCount(3)
    assert(sameColor(icon.accentGlyph.vertexColor, Theme.COLORS.accent), "unread messages return the back bubble to the accent")
    icon.setUnreadCount(0)
    assert(sameColor(icon.accentGlyph.vertexColor, Desaturation.DESAT_BACK), "back bubble gray again when idle")
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

    assert(icon.iconTex.desaturated ~= true, "front bubble stays saturated when the setting is off")
    assert(sameColor(icon.accentGlyph.vertexColor, Theme.COLORS.accent), "back bubble stays accent when the setting is off")
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

  -- test_tooltip_leads_with_spaced_addon_name
  do
    local factory = FakeUI.NewFactory()
    local icon = MinimapIcon.Create(factory, { parent = makeParent(factory) })
    local tooltipText = nil
    local originalTooltip = _G.GameTooltip
    _G.GameTooltip = {
      SetOwner = function() end,
      SetText = function(_self, text)
        tooltipText = text
      end,
      AddLine = function() end,
      AddDoubleLine = function() end,
      Show = function() end,
      Hide = function() end,
    }

    icon.frame:GetScript("OnEnter")(icon.frame)
    _G.GameTooltip = originalTooltip

    assert(tooltipText == "Whisper Messenger", "tooltip title is the addon name; got: " .. tostring(tooltipText))
  end
end
