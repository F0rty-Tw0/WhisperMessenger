local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Base = {}

function Base.sizeValue(target, getterName, fieldName, fallback)
  if target and type(target[getterName]) == "function" then
    local value = target[getterName](target)
    if type(value) == "number" and value > 0 then
      return value
    end
  end

  if target and type(target[fieldName]) == "number" then
    return target[fieldName]
  end

  return fallback
end

function Base.applyColor(fontString, colorTable)
  if fontString and colorTable then
    fontString:SetTextColor(colorTable[1], colorTable[2], colorTable[3], colorTable[4] or 1)
  end
end

function Base.applyColorTexture(region, colorTable)
  if not region or not colorTable then
    return
  end
  if region.SetColorTexture then
    region:SetColorTexture(colorTable[1], colorTable[2], colorTable[3], colorTable[4] or 1)
  end
end

-- Paint a pane background with either the active skin's Blizzard texture
-- (if `skinTexturePath` is non-nil) or fall back to the flat color paint.
-- Caller passes the theme color regardless; helper handles the swap so
-- live preset switches between skinned and modern paint clear cleanly.
function Base.applyPaneBackground(region, colorTable, skinTexturePath)
  if not region then
    return
  end
  if skinTexturePath and region.SetTexture then
    region:SetTexture(skinTexturePath)
    if region.SetVertexColor then
      region:SetVertexColor(1, 1, 1, 1)
    end
  else
    if region.SetTexture then
      region:SetTexture(nil)
    end
    Base.applyColorTexture(region, colorTable)
  end
end

function Base.applyBorderBoxColor(border, colorTable)
  if type(border) ~= "table" or not colorTable then
    return
  end

  for _, edge in pairs(border) do
    Base.applyColorTexture(edge, colorTable)
  end
end

function Base.applyVertexColor(region, colorTable)
  if not region or not colorTable then
    return
  end
  if region.SetVertexColor then
    region:SetVertexColor(colorTable[1], colorTable[2], colorTable[3], colorTable[4] or 1)
  end
end

function Base.applyClassColor(fontString, classTag, fallbackColor)
  if not fontString then
    return
  end
  if classTag and _G.RAID_CLASS_COLORS then
    local classColor = _G.RAID_CLASS_COLORS[string.upper(classTag)]
    if classColor then
      if classColor.r then
        fontString:SetTextColor(classColor.r, classColor.g, classColor.b, 1)
      elseif type(classColor[1]) == "number" then
        fontString:SetTextColor(classColor[1], classColor[2], classColor[3], 1)
      end
      return
    end
  end
  if fallbackColor and fontString.SetTextColor then
    fontString:SetTextColor(fallbackColor[1], fallbackColor[2], fallbackColor[3], fallbackColor[4] or 1)
  end
end

function Base.captureFramePosition(frame)
  local point, _, relative, offsetX, offsetY
  if frame.GetPoint then
    point, _, relative, offsetX, offsetY = frame:GetPoint()
  else
    local savedPoint = frame.point or {}
    point, relative, offsetX, offsetY = savedPoint[1], savedPoint[3], savedPoint[4], savedPoint[5]
  end
  return {
    anchorPoint = point or "CENTER",
    relativePoint = relative or point or "CENTER",
    x = offsetX or 0,
    y = offsetY or 0,
  }
end

function Base.setFontObject(fontString, fontKey)
  local fontObj = _G[fontKey] or fontKey
  if fontString.SetFontObject then
    fontString:SetFontObject(fontObj)
  end
end

function Base.setTextColor(fontString, colorTable)
  if fontString.SetTextColor and colorTable then
    fontString:SetTextColor(colorTable[1], colorTable[2], colorTable[3], colorTable[4] or 1)
  end
end

local UTF8_CHAR_PATTERN = "[%z\1-\127\194-\244][\128-\191]*"
local ELLIPSIS = "..."

local function utf8CodepointCount(text)
  local count = 0
  for _ in string.gmatch(text or "", UTF8_CHAR_PATTERN) do
    count = count + 1
  end
  return count
end

local function utf8Prefix(text, maxChars)
  if maxChars <= 0 then
    return ""
  end

  local chars = {}
  local index = 0
  for char in string.gmatch(text or "", UTF8_CHAR_PATTERN) do
    index = index + 1
    if index > maxChars then
      break
    end
    chars[#chars + 1] = char
  end

  return table.concat(chars)
end

function Base.fitTextWithEllipsis(label, text, maxWidth)
  local resolvedText = text or ""
  label:SetText(resolvedText)
  if maxWidth <= 0 or type(label.GetStringWidth) ~= "function" then
    return resolvedText
  end

  if label:GetStringWidth() <= maxWidth then
    return resolvedText
  end

  label:SetText(ELLIPSIS)
  local ellipsisWidth = label:GetStringWidth() or 0
  if ellipsisWidth >= maxWidth then
    return ELLIPSIS
  end

  local totalChars = utf8CodepointCount(resolvedText)
  for keepChars = totalChars - 1, 1, -1 do
    local candidate = utf8Prefix(resolvedText, keepChars) .. ELLIPSIS
    label:SetText(candidate)
    if label:GetStringWidth() <= maxWidth then
      return candidate
    end
  end

  return ELLIPSIS
end

ns.UIHelpersBase = Base

return Base
