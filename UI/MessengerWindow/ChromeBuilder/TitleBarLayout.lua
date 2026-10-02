local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- Sizes and anchors every title-bar button (and the title under the custom
-- chrome). Custom chrome: one hit size, one gap, everything centred on the
-- title bar vertically, the title centred horizontally (like the native HUD),
-- outer glyph ink mirrored on both edges. Native WoW HUD (the
-- Blizzard template) keeps its own compact offsets.
local TitleBarLayout = {}

local HUD_GAP = 2

local function place(region, point, relativeTo, relativePoint, x, y)
  region:ClearAllPoints()
  region:SetPoint(point, relativeTo, relativePoint, x, y)
end

local function applyModern(parts, L)
  local size, gap = L.TITLE_BUTTON_SIZE, L.TITLE_BUTTON_GAP
  -- Buttons are siblings of the title bar; at an equal frame level its
  -- near-opaque background can paint over the glyphs, so lift them above it.
  local buttonLevel = parts.titleBar:GetFrameLevel() + 1
  for _, button in ipairs(parts.buttons) do
    button:SetSize(size, size)
    button:SetFrameLevel(buttonLevel)
  end
  place(parts.title, "CENTER", parts.titleBar, "CENTER", 0, 0)
  place(parts.closeButton, "RIGHT", parts.titleBar, "RIGHT", -L.TITLE_BAR_INSET_X, 0)
  place(parts.newConversationButton, "LEFT", parts.titleBar, "LEFT", L.TITLE_BAR_INSET_X, 0)
  place(parts.patchNotesButton, "LEFT", parts.newConversationButton, "RIGHT", gap, 0)
  place(parts.markAllReadButton, "LEFT", parts.patchNotesButton, "RIGHT", gap, 0)
  place(parts.optionsButton, "RIGHT", parts.closeButton, "LEFT", -gap, 0)
  place(parts.backButton, "RIGHT", parts.optionsButton, "LEFT", -gap, 0)
end

-- The template owns the close button and title; the gear sits left of the X.
local function placeHudGear(parts, L)
  local size = L.CHROME_BUTTON_SIZE
  for _, button in ipairs(parts.buttons) do
    button:SetSize(size, size)
  end
  if parts.closeButton then
    place(parts.optionsButton, "RIGHT", parts.closeButton, "LEFT", -HUD_GAP, 0)
  else
    place(parts.optionsButton, "TOPRIGHT", parts.frame, "TOPRIGHT", -28, -4)
  end
end

local function applyHud(parts, L)
  placeHudGear(parts, L)
  place(parts.newConversationButton, "TOPLEFT", parts.frame, "TOPLEFT", 6, -3)
  place(parts.patchNotesButton, "LEFT", parts.newConversationButton, "RIGHT", HUD_GAP, 0)
  place(parts.markAllReadButton, "LEFT", parts.patchNotesButton, "RIGHT", HUD_GAP, 0)
  place(parts.backButton, "RIGHT", parts.optionsButton, "LEFT", -HUD_GAP, 0)
end

-- Retail: same arrangement as the other looks, but the left cluster starts
-- where the title bar clears the round portrait: the template's
-- TitleContainer begins there.
local RETAIL_LEFT_FALLBACK_X = 62

local function applyRetailHud(parts, L)
  placeHudGear(parts, L)
  -- The template's title-bar art sits on a high frame level and covers our
  -- buttons; match its close button, which it raises above that art.
  local closeLevel = parts.closeButton and parts.closeButton.GetFrameLevel and parts.closeButton:GetFrameLevel()
  if closeLevel then
    for _, button in ipairs(parts.buttons) do
      if button.SetFrameLevel and button:GetFrameLevel() < closeLevel then
        button:SetFrameLevel(closeLevel)
      end
    end
  end
  local titleContainer = parts.frame and parts.frame.TitleContainer
  if titleContainer then
    place(parts.newConversationButton, "LEFT", titleContainer, "LEFT", HUD_GAP, 0)
  else
    place(parts.newConversationButton, "TOPLEFT", parts.frame, "TOPLEFT", RETAIL_LEFT_FALLBACK_X, -3)
  end
  place(parts.patchNotesButton, "LEFT", parts.newConversationButton, "RIGHT", HUD_GAP, 0)
  place(parts.markAllReadButton, "LEFT", parts.patchNotesButton, "RIGHT", HUD_GAP, 0)
  place(parts.backButton, "RIGHT", parts.optionsButton, "LEFT", -HUD_GAP, 0)
end

-- parts: frame, titleBar (custom chrome only), title, closeButton,
-- newConversationButton, patchNotesButton, markAllReadButton, optionsButton, backButton,
-- blizzardChrome (bool), retailChrome (bool).
function TitleBarLayout.Apply(parts, theme)
  parts.buttons = parts.buttons
    or {
      parts.newConversationButton,
      parts.patchNotesButton,
      parts.markAllReadButton,
      parts.optionsButton,
      parts.backButton,
      not parts.blizzardChrome and parts.closeButton or nil,
    }
  if parts.retailChrome then
    applyRetailHud(parts, theme.LAYOUT)
    return
  end
  if parts.blizzardChrome then
    applyHud(parts, theme.LAYOUT)
    return
  end
  applyModern(parts, theme.LAYOUT)
end

ns.MessengerWindowChromeBuilderTitleBarLayout = TitleBarLayout
return TitleBarLayout
