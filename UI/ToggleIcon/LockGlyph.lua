local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- Lock glyph overlay: small padlock texture pinned to the bottom-right of
-- the icon. Hidden by default; shown only while the icon is locked AND the
-- cursor is hovering it, so the indicator stays out of sight otherwise.
local LockGlyph = {}

local LOCK_GLYPH_RATIO = 0.45 -- lock indicator size vs ICON_SIZE
local LOCK_GLYPH_TEXTURE = "Interface\\LFGFrame\\UI-LFG-ICON-LOCK"

-- options.isLocked: function returning true while the icon is locked.
-- options.hover: the icon's shared hover state table; `hover.active` is true
-- while the cursor is over the icon.
function LockGlyph.Create(frame, iconSize, options)
  local isLocked = options.isLocked
  local hover = options.hover

  local lockGlyph = frame:CreateTexture(nil, "OVERLAY")
  local function applyLayout(size)
    local s = math.max(8, math.floor((tonumber(size) or iconSize) * LOCK_GLYPH_RATIO))
    lockGlyph:SetSize(s, s)
    if lockGlyph.ClearAllPoints then
      lockGlyph:ClearAllPoints()
    end
    lockGlyph:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 2, -2)
  end
  applyLayout(iconSize)
  lockGlyph:SetTexture(LOCK_GLYPH_TEXTURE)
  if lockGlyph.Hide then
    lockGlyph:Hide()
  end

  local function syncVisibility()
    local show = hover.active and isLocked()
    if show then
      if lockGlyph.Show then
        lockGlyph:Show()
      end
    else
      if lockGlyph.Hide then
        lockGlyph:Hide()
      end
    end
  end

  local function refresh()
    if frame.SetMovable then
      frame:SetMovable(not isLocked())
    end
    syncVisibility()
  end

  return {
    texture = lockGlyph,
    applyLayout = applyLayout,
    syncVisibility = syncVisibility,
    refresh = refresh,
  }
end

ns.ToggleIconLockGlyph = LockGlyph
return LockGlyph
