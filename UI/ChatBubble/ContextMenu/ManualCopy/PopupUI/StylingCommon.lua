local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")

local StylingCommon = {}

function StylingCommon.setPartsShown(parts, shown)
  if type(parts) ~= "table" then
    return
  end

  local function setShown(part)
    if type(part) ~= "table" then
      return
    end
    if shown then
      if part.Show then
        part:Show()
      end
    elseif part.Hide then
      part:Hide()
    end
  end

  if type(parts.fills) == "table" then
    for _, part in ipairs(parts.fills) do
      setShown(part)
    end
  end
  if type(parts.corners) == "table" then
    for _, part in ipairs(parts.corners) do
      setShown(part)
    end
  end

  for _, part in pairs(parts) do
    setShown(part)
  end
end

function StylingCommon.captureTextColor(fontString)
  if type(fontString) ~= "table" then
    return nil
  end
  if type(fontString.GetTextColor) == "function" then
    local r, g, b, a = fontString:GetTextColor()
    if r ~= nil then
      return { r, g, b, a or 1 }
    end
  end
  if type(fontString.textColor) == "table" then
    return {
      fontString.textColor[1],
      fontString.textColor[2],
      fontString.textColor[3],
      fontString.textColor[4],
    }
  end
  return nil
end

function StylingCommon.applyTextColor(fontString, color)
  if type(fontString) ~= "table" or type(color) ~= "table" then
    return
  end
  if UIHelpers.setTextColor then
    UIHelpers.setTextColor(fontString, color)
    return
  end
  if fontString.SetTextColor then
    fontString:SetTextColor(color[1], color[2], color[3], color[4] or 1)
  end
end

local function isTextureRegion(region)
  if type(region) ~= "table" then
    return false
  end
  if type(region.GetObjectType) == "function" then
    return region:GetObjectType() == "Texture"
  end
  return region.frameType == "Texture"
end

local function regionShown(region)
  if type(region) ~= "table" then
    return false
  end
  if type(region.IsShown) == "function" then
    return region:IsShown() == true
  end
  return region.shown == true
end

function StylingCommon.collectTextureParts(parts, out)
  if type(parts) ~= "table" then
    return out
  end
  out = out or {}

  if type(parts.fills) == "table" then
    for _, texture in ipairs(parts.fills) do
      out[texture] = true
    end
  end
  if type(parts.corners) == "table" then
    for _, texture in ipairs(parts.corners) do
      out[texture] = true
    end
  end
  for _, texture in pairs(parts) do
    if isTextureRegion(texture) then
      out[texture] = true
    end
  end

  return out
end

function StylingCommon.suppressFrameTextures(frame, stateKey, skipSet)
  if type(frame) ~= "table" or type(frame.GetRegions) ~= "function" then
    return
  end

  local snapshots = {}
  for _, region in ipairs({ frame:GetRegions() }) do
    if isTextureRegion(region) and not (skipSet and skipSet[region]) then
      local snapshot = {
        region = region,
        shown = regionShown(region),
      }
      if type(region.GetAlpha) == "function" then
        snapshot.alpha = region:GetAlpha()
      else
        snapshot.alpha = region.alpha
      end
      snapshots[#snapshots + 1] = snapshot

      if type(region.SetAlpha) == "function" then
        region:SetAlpha(0)
      end
      if type(region.Hide) == "function" then
        region:Hide()
      end
    end
  end

  frame[stateKey] = snapshots
end

function StylingCommon.restoreSuppressedFrameTextures(frame, stateKey)
  if type(frame) ~= "table" then
    return
  end

  local snapshots = frame[stateKey]
  if type(snapshots) ~= "table" then
    return
  end

  for _, snapshot in ipairs(snapshots) do
    local region = snapshot.region
    if type(region) == "table" then
      if snapshot.alpha ~= nil and type(region.SetAlpha) == "function" then
        region:SetAlpha(snapshot.alpha)
      end
      if snapshot.shown and type(region.Show) == "function" then
        region:Show()
      elseif not snapshot.shown and type(region.Hide) == "function" then
        region:Hide()
      end
    end
  end

  frame[stateKey] = nil
end

ns.ChatBubbleContextMenuManualCopyPopupUIStylingCommon = StylingCommon

return StylingCommon
