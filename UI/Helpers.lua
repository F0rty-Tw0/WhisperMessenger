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

  button.bg = bg
  button.label = labelFs

  return button
end

function UIHelpers.createToggleRow(factory, parent, label, initial, colors, layout, onChange)
  local toggleWidth = layout.width or 280
  local toggleHeight = layout.height or 24
  local dotSize = 14

  local row = factory.CreateFrame("Frame", nil, parent)
  row:SetSize(toggleWidth, toggleHeight)

  local labelFs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  labelFs:SetPoint("LEFT", row, "LEFT", 0, 0)
  labelFs:SetText(label)
  UIHelpers.setTextColor(labelFs, colors.text)

  local dot = factory.CreateFrame("Button", nil, row)
  dot:SetSize(dotSize, dotSize)
  dot:SetPoint("RIGHT", row, "RIGHT", 0, 0)

  local dotBg = dot:CreateTexture(nil, "BACKGROUND")
  dotBg:SetAllPoints(dot)

  local enabled = initial == true
  local function updateVisual()
    if enabled then
      UIHelpers.applyColorTexture(dotBg, colors.on or { 0.30, 0.82, 0.40, 1.0 })
    else
      UIHelpers.applyColorTexture(dotBg, colors.off or { 0.45, 0.45, 0.50, 1.0 })
    end
  end
  updateVisual()

  dot:SetScript("OnClick", function()
    enabled = not enabled
    updateVisual()
    if onChange then
      onChange(enabled)
    end
  end)

  return {
    row = row,
    label = labelFs,
    dot = dot,
    getValue = function()
      return enabled
    end,
    setValue = function(val)
      enabled = val == true
      updateVisual()
    end,
  }
end

local ROUNDED_CIRCLE_TEX = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMaskSmall"

--- Create a rounded-rectangle background on a frame using fill rects + corner textures.
--- Returns { fills = {textures}, corners = {textures}, setColor = function(colorTable) }
function UIHelpers.createRoundedBackground(frame, cornerRadius)
  local r = cornerRadius or 8

  local fills = {}
  local corners = {}

  local bgCenter = frame:CreateTexture(nil, "BACKGROUND")
  bgCenter:SetPoint("TOPLEFT", frame, "TOPLEFT", r, -r)
  bgCenter:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -r, r)
  fills[#fills + 1] = bgCenter

  local bgTop = frame:CreateTexture(nil, "BACKGROUND")
  bgTop:SetPoint("TOPLEFT", frame, "TOPLEFT", r, 0)
  bgTop:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -r, 0)
  bgTop:SetHeight(r)
  fills[#fills + 1] = bgTop

  local bgBottom = frame:CreateTexture(nil, "BACKGROUND")
  bgBottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", r, 0)
  bgBottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -r, 0)
  bgBottom:SetHeight(r)
  fills[#fills + 1] = bgBottom

  local bgLeft = frame:CreateTexture(nil, "BACKGROUND")
  bgLeft:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -r)
  bgLeft:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, r)
  bgLeft:SetWidth(r)
  fills[#fills + 1] = bgLeft

  local bgRight = frame:CreateTexture(nil, "BACKGROUND")
  bgRight:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -r)
  bgRight:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, r)
  bgRight:SetWidth(r)
  fills[#fills + 1] = bgRight

  local function makeCorner(point)
    local c = frame:CreateTexture(nil, "BACKGROUND")
    c:SetSize(r, r)
    c:SetPoint(point, frame, point, 0, 0)
    if c.SetTexture then
      c:SetTexture(ROUNDED_CIRCLE_TEX)
    end
    return c
  end

  local cTL = makeCorner("TOPLEFT")
  local cTR = makeCorner("TOPRIGHT")
  local cBL = makeCorner("BOTTOMLEFT")
  local cBR = makeCorner("BOTTOMRIGHT")

  if cTL.SetTexCoord then
    cTL:SetTexCoord(0, 0.5, 0, 0.5)
    cTR:SetTexCoord(0.5, 1, 0, 0.5)
    cBL:SetTexCoord(0, 0.5, 0.5, 1)
    cBR:SetTexCoord(0.5, 1, 0.5, 1)
  end

  corners[#corners + 1] = cTL
  corners[#corners + 1] = cTR
  corners[#corners + 1] = cBL
  corners[#corners + 1] = cBR

  local function setColor(colorTable)
    local cr, cg, cb, ca = colorTable[1], colorTable[2], colorTable[3], colorTable[4] or 1
    for _, part in ipairs(fills) do
      if part.SetColorTexture then
        part:SetColorTexture(cr, cg, cb, ca)
      end
    end
    for _, part in ipairs(corners) do
      if part.SetVertexColor then
        part:SetVertexColor(cr, cg, cb, ca)
      end
    end
  end

  return { fills = fills, corners = corners, setColor = setColor }
end

ns.UIHelpers = UIHelpers

return UIHelpers
