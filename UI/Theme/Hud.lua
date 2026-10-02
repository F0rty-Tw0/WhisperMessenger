local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local FlavorCompat = ns.FlavorCompat or require("WhisperMessenger.Core.FlavorCompat")
local Presets = ns.ThemePresets or require("WhisperMessenger.UI.Theme.Presets")

-- Active Native WoW HUD style for this session: "off", "classic" or "retail".
-- Configured once at boot from the saved setting; a change applies after
-- /reload because frame templates can't be swapped at runtime.
local Hud = {}

local STYLES = { off = true, classic = true, retail = true }
local RETAIL_TEMPLATES = { "PortraitFrameTemplate", "MinimalSliderWithSteppersTemplate" }

local activeStyle = "off"

local function hasTemplate(getTemplateInfo, name)
  local ok, info = pcall(getTemplateInfo, name)
  return ok and info ~= nil
end

-- True only when this client ships every template the Retail look needs.
function Hud.RetailAvailable()
  local xmlUtil = _G.C_XMLUtil
  if type(xmlUtil) ~= "table" or type(xmlUtil.GetTemplateInfo) ~= "function" then
    return false
  end
  for _, name in ipairs(RETAIL_TEMPLATES) do
    if not hasTemplate(xmlUtil.GetTemplateInfo, name) then
      return false
    end
  end
  return true
end

-- The style a saved choice would actually run as on this client.
function Hud.Resolve(style)
  local nextStyle = STYLES[style] and style or "off"
  if nextStyle == "retail" and not Hud.RetailAvailable() then
    nextStyle = "classic"
  end
  return nextStyle
end

-- The style new installs and Reset to Defaults use: Modern where the game
-- ships its templates (Retail and Forever), Off on the Classic flavors.
function Hud.DefaultStyle()
  return (FlavorCompat.isRetail or FlavorCompat.isForever) and "retail" or "off"
end

-- The theme that goes with DefaultStyle: Azeroth with Modern, as when a
-- player turns the HUD on from Off.
function Hud.DefaultPreset()
  return Hud.DefaultStyle() == "off" and Presets.WOW_DEFAULT or Presets.WOW_NATIVE
end

function Hud.Configure(style)
  activeStyle = Hud.Resolve(style)
  return activeStyle
end

function Hud.Style()
  return activeStyle
end

function Hud.IsOn()
  return activeStyle ~= "off"
end

function Hud.IsRetail()
  return activeStyle == "retail"
end

-- Edges of the window's content area, measured in from the frame's outer
-- edges. Retail's ButtonFrameTemplate and Classic's BasicFrameTemplateWithInset
-- have different borders and title bars.
function Hud.ContentInsets(layout)
  if activeStyle == "retail" then
    return {
      left = layout.RETAIL_HUD_INSET_LEFT,
      right = layout.RETAIL_HUD_INSET_RIGHT,
      top = layout.RETAIL_HUD_INSET_TOP,
      bottom = layout.RETAIL_HUD_INSET_BOTTOM,
    }
  end
  local pad = layout.HUD_CONTENT_INSET
  return {
    left = layout.HUD_INSET_LEFT + pad,
    right = layout.HUD_INSET_RIGHT + pad,
    top = layout.TOP_BAR_HEIGHT + layout.HUD_CONTENT_TOP_INSET,
    bottom = layout.HUD_INSET_BOTTOM + pad,
  }
end

ns.Hud = Hud
return Hud
