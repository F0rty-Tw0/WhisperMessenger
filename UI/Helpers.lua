local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local UIHelpers = {}

function UIHelpers.sizeValue(target, getterName, fieldName, fallback)
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

function UIHelpers.applyColor(fontString, colorTable)
  if fontString and colorTable then
    fontString:SetTextColor(colorTable[1], colorTable[2], colorTable[3], colorTable[4] or 1)
  end
end

function UIHelpers.applyColorTexture(region, colorTable)
  if not region or not colorTable then
    return
  end
  if region.SetColorTexture then
    region:SetColorTexture(colorTable[1], colorTable[2], colorTable[3], colorTable[4] or 1)
  end
end

function UIHelpers.applyVertexColor(region, colorTable)
  if not region or not colorTable then
    return
  end
  if region.SetVertexColor then
    region:SetVertexColor(colorTable[1], colorTable[2], colorTable[3], colorTable[4] or 1)
  end
end

function UIHelpers.applyClassColor(fontString, classTag, fallbackColor)
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

function UIHelpers.captureFramePosition(frame)
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

function UIHelpers.setFontObject(fontString, fontKey)
  local fontObj = _G[fontKey] or fontKey
  if fontString.SetFontObject then
    fontString:SetFontObject(fontObj)
  end
end

function UIHelpers.setTextColor(fontString, colorTable)
  if fontString.SetTextColor and colorTable then
    fontString:SetTextColor(colorTable[1], colorTable[2], colorTable[3], colorTable[4] or 1)
  end
end

local CIRCLE_MASK = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
local ICON_ZOOM = 1.15

function UIHelpers.createCircularIcon(factory, parent, size)
  local frame = factory.CreateFrame("Frame", nil, parent)
  frame:SetSize(size, size)
  if frame.SetClipsChildren then
    frame:SetClipsChildren(true)
  end

  local zoom = math.floor(size * ICON_ZOOM + 0.5)
  local texture = frame:CreateTexture(nil, "ARTWORK")
  texture:SetSize(zoom, zoom)
  texture:SetPoint("CENTER", frame, "CENTER", 0, 0)
  if texture.SetMask then
    texture:SetMask(CIRCLE_MASK)
  end

  return { frame = frame, texture = texture }
end

function UIHelpers.createOptionButton(factory, parent, label, colors, layout)
  local bgColor = colors.bg
  local bgHover = colors.bgHover
  local textColor = colors.text
  local textHover = colors.textHover
  local btnHeight = layout.height or 30
  local btnWidth = layout.width or 200

  local button = factory.CreateFrame("Button", nil, parent)
  button:SetSize(btnWidth, btnHeight)

  local bg = button:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints(button)
  UIHelpers.applyColorTexture(bg, bgColor)

  local labelFs = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  labelFs:SetPoint("CENTER", button, "CENTER", 0, 0)
  labelFs:SetText(label)
  UIHelpers.setTextColor(labelFs, textColor)

  button:SetScript("OnEnter", function()
    UIHelpers.applyColorTexture(bg, bgHover)
    UIHelpers.setTextColor(labelFs, textHover)
  end)

  button:SetScript("OnLeave", function()
    UIHelpers.applyColorTexture(bg, bgColor)
    UIHelpers.setTextColor(labelFs, textColor)
  end)

  return button
end

ns.UIHelpers = UIHelpers

return UIHelpers
