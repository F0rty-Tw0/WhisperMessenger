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

-- Addon panel buttons sit right of mark-all-read, each after the previous.
local function placePanelButtons(parts, gap)
  local previous = parts.markAllReadButton
  for _, button in ipairs(parts.panelButtons or {}) do
    place(button, "LEFT", previous, "RIGHT", gap, 0)
    previous = button
  end
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
  placePanelButtons(parts, gap)
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
  placePanelButtons(parts, HUD_GAP)
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
  placePanelButtons(parts, HUD_GAP)
end

-- parts: frame, titleBar (custom chrome only), title, closeButton,
-- newConversationButton, patchNotesButton, markAllReadButton, optionsButton, backButton,
-- blizzardChrome (bool), retailChrome (bool), panelButtons (optional list).
function TitleBarLayout.Apply(parts, theme)
  if not parts.buttons then
    parts.buttons = {
      parts.newConversationButton,
      parts.patchNotesButton,
      parts.markAllReadButton,
      parts.optionsButton,
      parts.backButton,
    }
    if not parts.blizzardChrome then
      table.insert(parts.buttons, parts.closeButton)
    end
    for _, button in ipairs(parts.panelButtons or {}) do
      table.insert(parts.buttons, button)
    end
  end
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

-- Adds an addon panel button; the next Apply sizes and places it.
function TitleBarLayout.AddPanelButton(parts, button)
  parts.panelButtons = parts.panelButtons or {}
  table.insert(parts.panelButtons, button)
  if parts.buttons then
    table.insert(parts.buttons, button)
  end
end

ns.MessengerWindowChromeBuilderTitleBarLayout = TitleBarLayout
return TitleBarLayout
