local FakeUI = require("tests.helpers.fake_ui")
local Hud = require("WhisperMessenger.UI.Theme.Hud")
local IncomingPreview = require("WhisperMessenger.UI.ToggleIcon.IncomingPreview")
local ToggleIcon = require("WhisperMessenger.UI.ToggleIcon")
local Theme = require("WhisperMessenger.UI.Theme")

local TOOLTIP_TEMPLATE = "TooltipBackdropTemplate"

local function build(factory)
  factory = factory or FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  parent:SetSize(48, 48)
  return IncomingPreview.Create(factory, parent, {})
end

-- The rounded background is a set of BACKGROUND textures on the preview frame itself.
local function roundedBackgroundTextures(frame)
  local count = 0
  for _, child in ipairs(frame.children) do
    if child.frameType == "Texture" and child.drawLayer == "BACKGROUND" then
      count = count + 1
    end
  end
  return count
end

local function factoryWithoutTooltipTemplate()
  local factory = FakeUI.NewFactory()
  local createFrame = factory.CreateFrame
  factory.CreateFrame = function(frameType, name, parent, template)
    if template == TOOLTIP_TEMPLATE then
      error("Couldn't find inherited node " .. template)
    end
    return createFrame(frameType, name, parent, template)
  end
  return factory
end

-- A client that lacks the template: CreateFrame logs and hands back a plain
-- frame (no NineSlice, no backdrop methods) instead of throwing.
local function factoryIgnoringTemplate(created)
  local factory = FakeUI.NewFactory()
  local createFrame = factory.CreateFrame
  factory.CreateFrame = function(frameType, name, parent, _template)
    local frame = createFrame(frameType, name, parent, nil)
    frame.SetBackdropColor = nil
    created[#created + 1] = frame
    return frame
  end
  return factory
end

local function expectedFill()
  local c = Theme.COLORS.bg_secondary or Theme.COLORS.bg_primary
  return { c[1], c[2], c[3], c[4] or 1 }
end

local function sameColor(a, b)
  if type(a) ~= "table" then
    return false
  end
  for i = 1, 4 do
    if math.abs((a[i] or 1) - (b[i] or 1)) > 0.0001 then
      return false
    end
  end
  return true
end

local function withHud(style, run)
  Hud.Configure(style)
  local ok, err = pcall(run)
  Hud.Configure("off")
  if not ok then
    error(err, 0)
  end
end

return function()
  local function test_hud_preview_uses_tooltip_backdrop_template()
    for _, style in ipairs({ "classic", "retail" }) do
      withHud(style, function()
        local preview = build()
        assert(preview.frame.template == TOOLTIP_TEMPLATE, style .. ": preview uses the tooltip border, got " .. tostring(preview.frame.template))
        assert(roundedBackgroundTextures(preview.frame) == 0, style .. ": no rounded background under the tooltip border")
      end)
    end
  end

  local function test_modern_preview_keeps_rounded_background()
    withHud("off", function()
      local preview = build()
      assert(preview.frame.template == nil, "modern preview has no template, got " .. tostring(preview.frame.template))
      assert(roundedBackgroundTextures(preview.frame) > 0, "modern preview keeps the rounded background")
    end)
  end

  local function test_missing_template_falls_back_to_rounded_background()
    withHud("classic", function()
      local preview = build(factoryWithoutTooltipTemplate())
      assert(preview.frame ~= nil and preview.frame.template == nil, "fallback preview is a plain frame")
      assert(roundedBackgroundTextures(preview.frame) > 0, "fallback preview has the rounded background")
      preview.setIncomingPreview("Arthas", "hello", "PALADIN")
      assert(preview.frame.shown == true, "fallback preview still shows messages")
    end)
  end

  local function test_hud_preview_fill_takes_the_preset_colour()
    local previous = Theme.GetPreset()
    withHud("classic", function()
      Theme.SetPreset("wow_default")
      local icon = ToggleIcon.Create(FakeUI.NewFactory(), {})
      assert(sameColor(icon.previewFrame.backdropColor, expectedFill()), "classic: fill has the preset's preview colour at create")
      local before = icon.previewFrame.backdropColor
      Theme.SetPreset("wow_native")
      icon.refreshTheme()
      assert(sameColor(icon.previewFrame.backdropColor, expectedFill()), "classic: fill repaints after a preset change")
      assert(not sameColor(icon.previewFrame.backdropColor, before), "classic: the two presets differ, so the fill really changed")
    end)
    if previous then
      Theme.SetPreset(previous)
    end
  end

  local function test_hud_preview_fill_falls_back_to_nine_slice_centre()
    withHud("classic", function()
      local factory = FakeUI.NewFactory()
      local createFrame = factory.CreateFrame
      local centre
      factory.CreateFrame = function(frameType, name, parent, template)
        local frame = createFrame(frameType, name, parent, template)
        if template == TOOLTIP_TEMPLATE then
          frame.SetBackdropColor = nil
          frame.NineSlice = {
            SetCenterColor = function(_self, ...)
              centre = { ... }
            end,
          }
        end
        return frame
      end
      local preview = build(factory)
      preview.applyTheme(Theme)
      assert(sameColor(centre, expectedFill()), "nine-slice centre gets the preview colour when there is no SetBackdropColor")
    end)
  end

  local function test_template_ignored_by_client_gets_rounded_background_on_same_frame()
    withHud("classic", function()
      local created = {}
      local factory = factoryIgnoringTemplate(created)
      local parent = factory.CreateFrame("Frame", "UIParent", nil)
      local siblings = 0
      local preview = IncomingPreview.Create(factory, parent, {})
      for _, frame in ipairs(created) do
        if frame.parent == parent then
          siblings = siblings + 1
        end
      end
      assert(siblings == 1, "only one preview frame is created, got " .. siblings)
      assert(roundedBackgroundTextures(preview.frame) > 0, "template-less frame gets the rounded background")
    end)
  end

  test_hud_preview_uses_tooltip_backdrop_template()
  test_hud_preview_fill_takes_the_preset_colour()
  test_hud_preview_fill_falls_back_to_nine_slice_centre()
  test_template_ignored_by_client_gets_rounded_background_on_same_frame()
  test_modern_preview_keeps_rounded_background()
  test_missing_template_falls_back_to_rounded_background()
end
