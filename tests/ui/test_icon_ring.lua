-- The widget and the minimap button share one look, chosen by the Native
-- WoW HUD style: Off shows the full logo alone; Classic and Modern put the
-- rimless logo inside a hi-res copy of that HUD's minimap button ring,
-- tinted with the theme's ring color. The old low-res disc and hoop are gone.
local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local Hud = require("WhisperMessenger.UI.Theme.Hud")
local ToggleIcon = require("WhisperMessenger.UI.ToggleIcon")
local MinimapIcon = require("WhisperMessenger.UI.MinimapIcon.MinimapIcon")
local IconRing = require("WhisperMessenger.UI.Shared.IconRing")

local function near(a, b)
  return type(a) == "number" and math.abs(a - b) < 1e-6
end

-- Sizes are whole pixels.
local function px(a, b)
  return near(a, math.floor(b))
end

local function sameRgb(a, b)
  return type(a) == "table" and type(b) == "table" and near(a[1], b[1]) and near(a[2], b[2]) and near(a[3], b[3])
end

local function centred(region, frame)
  local p = region.point or {}
  return p[1] == "CENTER" and p[2] == frame and p[3] == "CENTER" and (p[4] or 0) == 0 and (p[5] or 0) == 0
end

local function hidden(region)
  return region.shown ~= true
end

local function widget(size)
  return ToggleIcon.Create(FakeUI.NewFactory(), { iconSize = size or 40 })
end

return function()
  local previousPreset = Theme.GetPreset()
  Theme.SetPreset("wow_default")

  -- test_kind_follows_the_hud
  assert(IconRing.Kind("off") == nil, "off: no ring")
  assert(IconRing.Kind("classic") == "classic", "classic HUD: classic ring")
  assert(IconRing.Kind("retail") == "modern", "modern (retail) HUD: modern ring")

  -- test_hud_off_widget_is_the_logo_alone
  Hud.Configure("off")
  do
    local icon = widget(40)
    assert(icon.label.texturePath == IconRing.LOGO, "full logo")
    assert(centred(icon.label, icon.frame) and px(icon.label.width, 36), "logo centred at its usual 90%")
    assert(hidden(icon.border), "no ring")
    assert(hidden(icon.background), "no low-res disc behind it")
  end

  -- test_modern_hud_widget_has_the_modern_ring
  Hud.Configure("retail")
  if Hud.Style() == "retail" then
    local icon = widget(40)
    assert(icon.border.texturePath == IconRing.RING.modern and icon.border.shown == true, "modern ring")
    assert(centred(icon.border, icon.frame) and px(icon.border.width, 40 * IconRing.LOOKS.modern.ringScale), "ring centred, scaled")
    assert(icon.label.texturePath == IconRing.RIMLESS_LOGO, "rimless logo inside")
    assert(centred(icon.label, icon.frame) and px(icon.label.width, 40 * IconRing.LOOKS.modern.logoScale), "logo centred under the ring")
    assert(hidden(icon.background), "nothing behind the logo")
  end

  -- test_classic_hud_widget_has_the_classic_ring_tinted_by_the_theme
  Hud.Configure("classic")
  do
    local icon = widget(40)
    assert(icon.border.texturePath == IconRing.RING.classic, "classic ring")
    assert(sameRgb(icon.border.vertexColor, Theme.COLORS.toggle_icon_ring), "tinted with the theme's ring color")
    assert(near(icon.border.vertexColor[4], 1), "fully opaque ring")
    Theme.SetPreset("wow_native")
    icon.refreshTheme()
    assert(sameRgb(icon.border.vertexColor, Theme.COLORS.toggle_icon_ring), "follows a preset switch")
    Theme.SetPreset("wow_default")
  end

  -- test_resize_keeps_ring_and_logo_in_proportion
  do
    local icon = widget(40)
    icon.applyIconSize(64)
    assert(
      px(icon.border.width, 64 * IconRing.LOOKS.classic.ringScale) and px(icon.label.width, 64 * IconRing.LOOKS.classic.logoScale),
      "both rescaled"
    )
    assert(centred(icon.border, icon.frame) and centred(icon.label, icon.frame), "both still centred")
  end

  -- test_idle_gray_includes_the_ring
  do
    local icon = ToggleIcon.Create(FakeUI.NewFactory(), {
      getIconDesaturated = function()
        return true
      end,
    })
    icon.setUnreadCount(0)
    assert(not sameRgb(icon.border.vertexColor, Theme.COLORS.toggle_icon_ring), "ring gray when idle")
    icon.setUnreadCount(1)
    assert(sameRgb(icon.border.vertexColor, Theme.COLORS.toggle_icon_ring), "ring tinted with unread")
  end

  -- test_minimap_matches_the_widget
  do
    local minimap = MinimapIcon.Create(FakeUI.NewFactory(), {})
    local frame = minimap.frame
    assert(minimap.border.texturePath == IconRing.RING.classic and centred(minimap.border, frame), "same ring, centred")
    assert(sameRgb(minimap.border.vertexColor, Theme.COLORS.toggle_icon_ring), "same tint")
    assert(minimap.iconTex.texturePath == IconRing.RIMLESS_LOGO and centred(minimap.iconTex, frame), "same logo, centred")
    assert(px(minimap.iconTex.width, frame.width * IconRing.LOOKS.classic.logoScale), "same proportions")
    assert(hidden(minimap.background), "no disc behind it")
  end
  Hud.Configure("off")
  do
    local minimap = MinimapIcon.Create(FakeUI.NewFactory(), {})
    assert(minimap.iconTex.texturePath == IconRing.LOGO and hidden(minimap.border), "HUD off: the logo alone")
  end

  -- test_logo_reaches_under_each_ring
  for kind, look in pairs(IconRing.LOOKS) do
    assert(look.logoScale >= look.goldInner, kind .. ": the logo's disc must reach under the gold")
  end

  -- test_modern_uses_the_retail_target_frame_ring_when_the_game_has_it
  do
    local factory = FakeUI.NewFactory()
    local frame = factory.CreateFrame("Frame", nil, nil)
    local ring = frame:CreateTexture(nil, "OVERLAY")
    local icon = frame:CreateTexture(nil, "ARTWORK")
    local masks = {}
    function frame:CreateMaskTexture()
      local m = self:CreateTexture(nil, "ARTWORK")
      masks[#masks + 1] = m
      return m
    end
    function ring:AddMaskTexture(m)
      self.mask = m
    end
    rawset(_G, "C_Texture", {
      GetAtlasInfo = function(name)
        if name == "ui-hud-unitframe-target-portraiton-2x" then
          -- the 2x art: 384x134 at (1,451) in a 2048x1024 sheet
          return { file = 4642466, leftTexCoord = 1 / 2048, rightTexCoord = 385 / 2048, topTexCoord = 451 / 1024, bottomTexCoord = 585 / 1024 }
        end
        return nil
      end,
    })
    IconRing.Apply({ frame = frame, icon = icon, ring = ring }, "modern", 60)
    rawset(_G, "C_Texture", nil)

    assert(ring.texturePath == 4642466, "Blizzard's target frame sheet, got " .. tostring(ring.texturePath))
    local c = ring.texCoords
    -- the ring: centre (314,513) in the sheet, cut out 62px around it
    assert(near(c[1], 252 / 2048) and near(c[2], 376 / 2048), "cut out across, got " .. tostring(c[1]) .. ".." .. tostring(c[2]))
    assert(near(c[3], 451 / 1024) and near(c[4], 575 / 1024), "cut out down, got " .. tostring(c[3]) .. ".." .. tostring(c[4]))
    assert(ring.desaturated == true and ring.wmAlwaysDesaturated == true, "grayed so the theme can tint it")
    assert(#masks == 1 and ring.mask == masks[1] and centred(masks[1], frame), "clipped to a circle, which drops the bar ends")
    assert(px(ring.width, 60 * IconRing.LOOKS.modernArt.ringScale), "gold's outer edge at the button's edge")
    assert(px(icon.width, 60 * IconRing.LOOKS.modernArt.logoScale), "logo under the gold")
  end

  -- test_idle_gray_never_ungrays_the_games_ring
  do
    local Desaturation = require("WhisperMessenger.UI.ToggleIcon.Desaturation")
    local factory = FakeUI.NewFactory()
    local frame = factory.CreateFrame("Frame", nil, nil)
    local ring, icon, bg = frame:CreateTexture(), frame:CreateTexture(), frame:CreateTexture()
    ring.wmAlwaysDesaturated = true
    ring:SetDesaturated(true)
    local idle = true
    local d = Desaturation.Create({
      textures = { chatIcon = icon, background = bg, border = ring },
      resolveColors = {
        chatIcon = function()
          return { 1, 1, 1, 1 }
        end,
        background = function()
          return { 1, 1, 1, 1 }
        end,
        border = function()
          return { 0.2, 0.4, 0.9, 1 }
        end,
      },
      getIconDesaturated = function()
        return idle
      end,
      applyVertexColor = function(t, c)
        t:SetVertexColor(c[1], c[2], c[3], c[4])
      end,
    })
    d.update(3)
    assert(ring.desaturated == true, "still grayed with unread whispers, so the tint colors it")
    assert(icon.desaturated == false, "the logo gets its colors back")
  end

  -- test_modern_falls_back_to_the_redrawn_ring
  do
    local factory = FakeUI.NewFactory()
    local frame = factory.CreateFrame("Frame", nil, nil)
    local ring = frame:CreateTexture(nil, "OVERLAY")
    local icon = frame:CreateTexture(nil, "ARTWORK")
    IconRing.Apply({ frame = frame, icon = icon, ring = ring }, "modern", 60)
    assert(ring.texturePath == IconRing.RING.modern, "redrawn modern ring without the retail art")
    assert(ring.desaturated ~= true and ring.wmAlwaysDesaturated ~= true, "already grayscale")
  end

  Hud.Configure("off")
  if previousPreset then
    Theme.SetPreset(previousPreset)
  end
end
