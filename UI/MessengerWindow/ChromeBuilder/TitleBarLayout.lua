local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- Sizes and anchors every title-bar button (and the title under the custom
-- chrome). Custom chrome: one hit size, one gap, everything centred on the
-- title bar, outer glyph ink mirrored on both edges. Native WoW HUD (the
-- Blizzard template) keeps its own compact offsets.
local TitleBarLayout = {}

local HUD_GAP = 2

local function place(region, point, relativeTo, relativePoint, x, y)
  region:ClearAllPoints()
  region:SetPoint(point, relativeTo, relativePoint, x, y)
end

local function applyModern(parts, L)
  local size, gap = L.TITLE_BUTTON_SIZE, L.TITLE_BUTTON_GAP
  local titleInset = L.TITLE_BAR_INSET_X + (size - L.CHROME_BUTTON_ICON_SIZE) / 2
  -- Buttons are siblings of the title bar; at an equal frame level its
  -- near-opaque background can paint over the glyphs, so lift them above it.
  local buttonLevel = parts.titleBar:GetFrameLevel() + 1
  for _, button in ipairs(parts.buttons) do
    button:SetSize(size, size)
    button:SetFrameLevel(buttonLevel)
  end
  place(parts.title, "LEFT", parts.titleBar, "LEFT", titleInset, 0)
  place(parts.closeButton, "RIGHT", parts.titleBar, "RIGHT", -L.TITLE_BAR_INSET_X, 0)
  place(parts.newConversationButton, "LEFT", parts.title, "RIGHT", gap, 0)
  place(parts.patchNotesButton, "LEFT", parts.newConversationButton, "RIGHT", gap, 0)
  place(parts.optionsButton, "RIGHT", parts.closeButton, "LEFT", -gap, 0)
  place(parts.backButton, "RIGHT", parts.optionsButton, "LEFT", -gap, 0)
end

local function applyHud(parts, L)
  local size = L.CHROME_BUTTON_SIZE
  for _, button in ipairs(parts.buttons) do
    button:SetSize(size, size)
  end
  -- The template owns the close button and title.
  place(parts.newConversationButton, "TOPLEFT", parts.frame, "TOPLEFT", 6, -3)
  place(parts.patchNotesButton, "LEFT", parts.newConversationButton, "RIGHT", HUD_GAP, 0)
  if parts.closeButton then
    place(parts.optionsButton, "RIGHT", parts.closeButton, "LEFT", -HUD_GAP, 0)
  else
    place(parts.optionsButton, "TOPRIGHT", parts.frame, "TOPRIGHT", -28, -4)
  end
  place(parts.backButton, "RIGHT", parts.optionsButton, "LEFT", -HUD_GAP, 0)
end

-- parts: frame, titleBar (custom chrome only), title, closeButton,
-- newConversationButton, patchNotesButton, optionsButton, backButton,
-- blizzardChrome (bool).
function TitleBarLayout.Apply(parts, theme)
  parts.buttons = parts.buttons
    or {
      parts.newConversationButton,
      parts.patchNotesButton,
      parts.optionsButton,
      parts.backButton,
      not parts.blizzardChrome and parts.closeButton or nil,
    }
  if parts.blizzardChrome then
    applyHud(parts, theme.LAYOUT)
    return
  end
  applyModern(parts, theme.LAYOUT)
end

ns.MessengerWindowChromeBuilderTitleBarLayout = TitleBarLayout
return TitleBarLayout
