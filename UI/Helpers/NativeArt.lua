local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- Blizzard art the Native WoW HUD draws with, tinted from the preset. List
-- highlights (contact rows, settings nav) use the quest log's selected entry
-- and the dropdown menu's hover.
local NativeArt = {}

NativeArt.LIST_SELECTED = "Interface\\QuestFrame\\UI-QuestLogTitleHighlight"
NativeArt.LIST_HOVER = "Interface\\QuestFrame\\UI-QuestTitleHighlight"
-- Additive art at full strength glares on a tall row; these keep the
-- selection clear and the hover subtle.
NativeArt.LIST_SELECTED_ALPHA = 0.45
NativeArt.LIST_HOVER_ALPHA = 0.18
-- The game's round mouse-over glow for icon buttons.
NativeArt.ICON_GLOW = "Interface\\Buttons\\UI-Common-MouseHilight"
-- The chat frame's resize corner: Normal, Pushed and Highlight.
NativeArt.SIZE_GRABBER_UP = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up"
NativeArt.SIZE_GRABBER_DOWN = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down"
NativeArt.SIZE_GRABBER_HIGHLIGHT = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight"
-- Retail's minimal scrollbar (the professions recipe list). The track's
-- middle is a tiling atlas, hence the leading "!".
NativeArt.SCROLL_TRACK_TOP = "minimal-scrollbar-track-top"
NativeArt.SCROLL_TRACK_MIDDLE = "!minimal-scrollbar-track-middle"
NativeArt.SCROLL_TRACK_BOTTOM = "minimal-scrollbar-track-bottom"
NativeArt.SCROLL_THUMB = {
  top = "minimal-scrollbar-thumb-top",
  middle = "minimal-scrollbar-thumb-middle",
  bottom = "minimal-scrollbar-thumb-bottom",
}
NativeArt.SCROLL_THUMB_OVER = {
  top = "minimal-scrollbar-thumb-top-over",
  middle = "minimal-scrollbar-thumb-middle-over",
  bottom = "minimal-scrollbar-thumb-bottom-over",
}

local hoverTint = { 1, 1, 1, NativeArt.LIST_HOVER_ALPHA }

-- Paints `texture` with Blizzard art, additive like the game's own
-- highlights. Theme refreshes leave it alone.
function NativeArt.Set(texture, path)
  texture:SetTexture(path)
  if type(texture.SetBlendMode) == "function" then
    texture:SetBlendMode("ADD")
  end
  texture._wmNativeArt = true
end

-- Same as Set for opaque art (a scroll knob), drawn with normal blending.
function NativeArt.SetOpaque(texture, path)
  texture:SetTexture(path)
  if type(texture.SetBlendMode) == "function" then
    texture:SetBlendMode("BLEND")
  end
  texture._wmNativeArt = true
end

-- Paints `texture` with a Blizzard atlas, normal blending, untinted.
-- Returns false on clients without SetAtlas.
function NativeArt.SetAtlas(texture, atlas, useAtlasSize)
  if type(texture.SetAtlas) ~= "function" then
    return false
  end
  texture:SetAtlas(atlas, useAtlasSize)
  if type(texture.SetBlendMode) == "function" then
    texture:SetBlendMode("BLEND")
  end
  texture._wmNativeArt = true
  return true
end

function NativeArt.AttachList(selection, hover)
  NativeArt.Set(selection, NativeArt.LIST_SELECTED)
  NativeArt.Set(hover, NativeArt.LIST_HOVER)
end

-- ICON_GLOW over the whole button, hidden until the caller shows it on
-- hover. Not the button's highlight texture: launchers and Send are never
-- Disable()d, and a disabled one must stay dark. The HIGHLIGHT layer still
-- keeps it from drawing once the mouse has left.
function NativeArt.CreateIconGlow(button)
  local glow = button:CreateTexture(nil, "HIGHLIGHT")
  glow:SetAllPoints(button)
  NativeArt.Set(glow, NativeArt.ICON_GLOW)
  glow:Hide()
  return glow
end

-- hoverFade: the HoverFade controller attached to the hover texture.
function NativeArt.TintList(selection, hoverFade, colors)
  local selected = colors.bg_contact_selected
  selection:SetVertexColor(selected[1], selected[2], selected[3], NativeArt.LIST_SELECTED_ALPHA)
  local hover = colors.bg_contact_hover
  hoverTint[1], hoverTint[2], hoverTint[3] = hover[1], hover[2], hover[3]
  hoverFade.paintVertex(hoverTint)
end

ns.UIHelpersNativeArt = NativeArt
return NativeArt
