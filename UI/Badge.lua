local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local applyVertexColor = UIHelpers.applyVertexColor

-- Circular unread counter shared by the widget, minimap icon, contact rows
-- and Whispers/Groups tabs. Callers own anchoring and frame level.
local Badge = {}

local CIRCLE_TEX = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
local OUTLINE_PAD = 2 -- px of dark rim around the badge
local OUTLINE_COLOR = { 0, 0, 0, 0.75 }
local OVERFLOW = 99

-- opts.size    : px, default Theme.LAYOUT.ICON_BADGE_SIZE (SetSize, not
--                SetScale, so small badges keep readable digits)
-- opts.outline : dark rim for badges drawn over busy art
function Badge.Create(factory, parent, opts)
  opts = opts or {}
  local size = opts.size or Theme.LAYOUT.ICON_BADGE_SIZE

  local frame = factory.CreateFrame("Frame", nil, parent)
  frame:SetSize(size, size)

  local outline = nil
  if opts.outline then
    outline = frame:CreateTexture(nil, "BACKGROUND", nil, -1)
    outline:SetPoint("TOPLEFT", frame, "TOPLEFT", -OUTLINE_PAD, OUTLINE_PAD)
    outline:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", OUTLINE_PAD, -OUTLINE_PAD)
    outline:SetTexture(CIRCLE_TEX)
    applyVertexColor(outline, OUTLINE_COLOR)
  end

  local background = frame:CreateTexture(nil, "BACKGROUND")
  background:SetAllPoints(frame)
  background:SetTexture(CIRCLE_TEX)

  local label = frame:CreateFontString(nil, "OVERLAY", Theme.FONTS.unread_badge)
  label:SetAllPoints(frame)
  label:SetJustifyH("CENTER")
  label:SetJustifyV("MIDDLE")
  label:SetText("")
  if outline then
    UIHelpers.polishBadge(label, outline, background)
  else
    UIHelpers.polishBadge(label, background)
  end

  -- Read at call time so the badge follows live preset switches.
  local function paint()
    local bg, text = Theme.BadgeColors()
    applyVertexColor(background, bg)
    UIHelpers.setTextColor(label, text)
  end

  local function setCount(count)
    local n = tonumber(count) or 0
    if n <= 0 then
      label:SetText("")
      frame:Hide()
      return
    end
    label:SetText(n > OVERFLOW and (OVERFLOW .. "+") or tostring(n))
    frame:Show()
  end

  paint()
  frame:Hide()

  return {
    frame = frame,
    background = background,
    outline = outline,
    label = label,
    setCount = setCount,
    paint = paint,
  }
end

ns.Badge = Badge
return Badge
