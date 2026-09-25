local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Base = {}

-- Shared fully transparent color; treat as read-only.
Base.TRANSPARENT = { 0, 0, 0, 0 }

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

function Base.applyBorderBoxColor(border, colorTable)
  if type(border) ~= "table" or not colorTable then
    return
  end

  for _, edge in pairs(border) do
    Base.applyColorTexture(edge, colorTable)
  end
end

-- Paint `color` as a gradient between two alphas (Retail SetGradient +
-- CreateColor; min = left/bottom, max = right/top). The base texture is the
-- intended colour at its peak alpha and the gradient only scales that alpha
-- (vertex colours multiply the base), so if the gradient is unsupported or
-- dropped the worst case is the flat intended colour, never opaque white.
local function applyAlphaGradient(texture, orientation, color, minAlpha, maxAlpha)
  if not texture or not texture.SetColorTexture then
    return
  end
  local peak = math.max(minAlpha, maxAlpha)
  texture:SetColorTexture(color[1], color[2], color[3], peak)
  local createColor = _G.CreateColor
  if peak <= 0 or not texture.SetGradient or type(createColor) ~= "function" then
    return
  end
  pcall(texture.SetGradient, texture, orientation, createColor(1, 1, 1, minAlpha / peak), createColor(1, 1, 1, maxAlpha / peak))
end

-- Left edge at the color's alpha, fading to transparent on the right.
function Base.applyHorizontalFade(texture, color)
  applyAlphaGradient(texture, "HORIZONTAL", color, color[4] or 1, 0)
end

-- Right edge at the color's alpha, fading to transparent on the left.
function Base.applyHorizontalFadeLeft(texture, color)
  applyAlphaGradient(texture, "HORIZONTAL", color, 0, color[4] or 1)
end

-- Transparent at the bottom, the color's alpha at the top.
function Base.applyVerticalFade(texture, color)
  applyAlphaGradient(texture, "VERTICAL", color, 0, color[4] or 1)
end

-- Fill for small hover buttons (new whisper, empty-state start button).
-- White-plus-alpha tokens use their own alpha, doubled on hover, so the
-- fill never turns solid white.
function Base.hoverButtonFill(color, hovered)
  local alpha = (color[4] or 1) * (hovered and 2 or 1)
  return { color[1], color[2], color[3], alpha }
end

-- Show only the listed sides of a createBorderBox table (nil = every side).
function Base.setBorderEdgesShown(border, visibleSides)
  if type(border) ~= "table" then
    return
  end
  for side, edge in pairs(border) do
    if visibleSides == nil or visibleSides[side] then
      edge:Show()
    else
      edge:Hide()
    end
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

-- "|cffRRGGBB" escape for inline-coloured text; close it with "|r".
function Base.colorEscape(color)
  local function component(value)
    local v = math.floor((tonumber(value) or 1) * 255 + 0.5)
    return math.max(0, math.min(255, v))
  end
  return string.format("|cff%02x%02x%02x", component(color and color[1]), component(color and color[2]), component(color and color[3]))
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

-- Creates a frame from a Blizzard template, or returns nil when this client
-- flavor lacks the template (CreateFrame raises). Callers fall back to their
-- custom-drawn widget on nil.
function Base.createTemplatedFrame(factory, frameType, name, parent, template)
  local ok, frame = pcall(factory.CreateFrame, frameType, name, parent, template)
  if ok then
    return frame
  end
  return nil
end

ns.UIHelpersBase = Base

return Base
