-- The EllesmereUI widget copies EllesmereUI's action buttons: slot
-- background, border and the Bar Animations hover and pushed effects, read
-- from EllesmereUI Action Bars' profile; EllesmereUI's defaults without it.
local ButtonLook = require("WhisperMessenger.UI.Theme.EllesmereButtonLook")

local MEDIA = "Interface\\AddOns\\EllesmereUIActionBars\\Media\\"

local function withProfile(profile, fn)
  rawset(_G, "EllesmereUI", {
    Lite = {
      GetAddon = function(name)
        assert(name == "EllesmereUIActionBars", "asks for the action bars module")
        if profile == "error" then
          error("boom")
        end
        return profile and { db = { profile = profile } } or nil
      end,
    },
  })
  local ok, err = pcall(fn)
  rawset(_G, "EllesmereUI", nil)
  if not ok then
    error(err, 0)
  end
end

local function near(a, b)
  return math.abs(a - b) < 1e-6
end

local function sameColor(c, r, g, b, a)
  return near(c[1], r) and near(c[2], g) and near(c[3], b) and near(c[4] or 1, a or 1)
end

return function()
  -- test_defaults_without_the_action_bars_module
  withProfile(nil, function()
    local look = ButtonLook.Read()
    assert(sameColor(look.bg, 0.15, 0.15, 0.15, 0.5), "EllesmereUI's slot background")
    assert(sameColor(look.border, 0, 0, 0, 1) and look.borderPx == 1, "1px black border")
    assert(look.hover.kind == "fill" and look.push.kind == "fill", "plain fills: its textures may be missing")
  end)

  -- test_reads_the_profile
  withProfile({
    slotBgColor = { r = 0.2, g = 0.3, b = 0.4 },
    slotBgOpacity = 80,
    bars = { MainBar = { borderColor = { r = 1, g = 0, b = 0, a = 0.5 }, borderThickness = "heavy" } },
    highlightTextureType = 1,
    highlightCustomColor = { r = 0.1, g = 0.2, b = 0.3, a = 1 },
    pushedTextureType = 5,
    pushedBorderSize = 3,
    pushedCustomColor = { r = 0.4, g = 0.5, b = 0.6, a = 1 },
  }, function()
    local look = ButtonLook.Read()
    assert(sameColor(look.bg, 0.2, 0.3, 0.4, 0.8), "slot background and opacity")
    assert(sameColor(look.border, 1, 0, 0, 0.5) and look.borderPx == 3, "Action Bar 1 border")
    assert(look.hover.kind == "tex" and look.hover.path == MEDIA .. "highlight-2.png", "highlight texture 1")
    assert(look.hover.blend == "ADD" and sameColor(look.hover.color, 0.1, 0.2, 0.3, 1), "hover added on, in its color")
    assert(look.push.kind == "edge" and look.push.px == 3, "pushed border")
    assert(sameColor(look.push.color, 0.4, 0.5, 0.6, 1), "pushed color")
  end)

  -- test_border_thickness_in_pixels_wins
  withProfile({ bars = { MainBar = { borderThickness = "thin", borderThicknessPx = 2 } } }, function()
    assert(ButtonLook.Read().borderPx == 2, "exact pixel size")
  end)

  -- test_effect_types_fill_and_none
  withProfile({ highlightTextureType = 4, pushedTextureType = 6 }, function()
    local look = ButtonLook.Read()
    assert(look.hover.kind == "fill" and near(look.hover.color[4], 0.35), "fill at 35%")
    assert(look.push.kind == "none", "no pushed effect")
  end)

  -- test_class_color
  rawset(_G, "UnitClass", function()
    return "Mage", "MAGE"
  end)
  rawset(_G, "RAID_CLASS_COLORS", { MAGE = { r = 0.25, g = 0.78, b = 0.92 } })
  withProfile({ highlightUseClassColor = true }, function()
    assert(sameColor(ButtonLook.Read().hover.color, 0.25, 0.78, 0.92, 1), "class color hover")
  end)
  rawset(_G, "UnitClass", nil)
  rawset(_G, "RAID_CLASS_COLORS", nil)

  -- test_a_failing_ellesmere_gives_defaults
  withProfile("error", function()
    assert(ButtonLook.Read().borderPx == 1, "defaults after an error")
  end)
end
