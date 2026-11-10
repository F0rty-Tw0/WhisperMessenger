local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local DisabledState = ns.UIHelpersDisabledState or require("WhisperMessenger.UI.Helpers.DisabledState")
local NativeArt = ns.UIHelpersNativeArt or require("WhisperMessenger.UI.Helpers.NativeArt")

-- The back and forward arrows TabScroller pins to the tab strip's left (back)
-- and right (forward) ends.
-- Modern: the bundled back chevron (mirrored for forward) tinted like an
-- inactive tab label. Native WoW HUD: Blizzard's spellbook page buttons.
local TabArrows = {}

TabArrows.MODERN_WIDTH = 16
local MODERN_HEIGHT = 24
-- Glyph box inside the 16px button; the chevron fills about 60% of it.
local MODERN_ICON_SIZE = 14

TabArrows.NATIVE_SIZE = 24
local NATIVE_ART = {
  prev = "Interface\\Buttons\\UI-SpellbookIcon-PrevPage-",
  next = "Interface\\Buttons\\UI-SpellbookIcon-NextPage-",
}

-- Inactive-tab label colours: text_secondary at rest, text_primary while an
-- enabled arrow is hovered. A disabled arrow is dimmed and never lights up.
function TabArrows.PaintModern(btn, enabled)
  local state = btn._wmArrow
  state.enabled = enabled
  local color = (enabled and state.hovered) and Theme.COLORS.text_primary or Theme.COLORS.text_secondary
  UIHelpers.applyVertexColor(state.icon, color)
  if not enabled then
    -- The vertex alpha and region alpha are one channel; scale the colour's own.
    state.icon:SetAlpha((color[4] or 1) * DisabledState.ALPHA)
  end
end

-- mirrored: flip the art left-to-right (the forward arrow).
local function createModernArrow(factory, parent, mirrored)
  local btn = factory.CreateFrame("Button", nil, parent)
  btn:SetSize(TabArrows.MODERN_WIDTH, MODERN_HEIGHT)
  local icon = btn:CreateTexture(nil, "ARTWORK")
  icon:SetTexture(Theme.TEXTURES.title_back_icon)
  icon:SetSize(MODERN_ICON_SIZE, MODERN_ICON_SIZE)
  icon:SetPoint("CENTER", btn, "CENTER", 0, 0)
  if mirrored then
    icon:SetTexCoord(1, 0, 0, 1)
  end
  local state = { icon = icon, enabled = true, hovered = false }
  btn._wmArrow = state
  btn:SetScript("OnEnter", function()
    state.hovered = true
    TabArrows.PaintModern(btn, state.enabled)
  end)
  btn:SetScript("OnLeave", function()
    state.hovered = false
    TabArrows.PaintModern(btn, state.enabled)
  end)
  TabArrows.PaintModern(btn, true)
  return btn
end

function TabArrows.CreateModern(factory, parent)
  local prev = createModernArrow(factory, parent, false)
  local nextBtn = createModernArrow(factory, parent, true)
  return { prev = prev, next = nextBtn }
end

local function createNativeArrow(factory, parent, artPrefix)
  local btn = factory.CreateFrame("Button", nil, parent)
  btn:SetSize(TabArrows.NATIVE_SIZE, TabArrows.NATIVE_SIZE)
  btn:SetNormalTexture(artPrefix .. "Up")
  btn:SetPushedTexture(artPrefix .. "Down")
  btn:SetDisabledTexture(artPrefix .. "Disabled")
  -- A disabled button draws no highlight, so the end arrows stay dark.
  NativeArt.AddHighlight(btn, NativeArt.ICON_GLOW)
  return btn
end

function TabArrows.CreateNative(factory, parent)
  local prev = createNativeArrow(factory, parent, NATIVE_ART.prev)
  local nextBtn = createNativeArrow(factory, parent, NATIVE_ART.next)
  return { prev = prev, next = nextBtn }
end

ns.ContactsListTabArrows = TabArrows
return TabArrows
