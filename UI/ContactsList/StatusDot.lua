local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")

local CIRCLE_TEX = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"

local StatusDot = {}

local function colorKeyForAvailability(availability)
  if availability then
    local colorKey = availability.canWhisper and "online" or "offline"
    if availability.status == "WrongFaction" then
      return "dnd"
    elseif availability.status == "Away" then
      return "away"
    elseif availability.status == "Busy" then
      return "dnd"
    elseif availability.status == "BNetOnline" then
      return "away"
    elseif availability.status == "Unavailable" then
      return "offline"
    end
    return colorKey
  end

  return "offline"
end

function StatusDot.update(dotFrame, availability)
  local dotTexture = dotFrame and dotFrame.bg or nil
  local c = Theme.COLORS[colorKeyForAvailability(availability)]
  if dotTexture and c then
    dotTexture:SetVertexColor(c[1], c[2], c[3], c[4] or 1)
  end
  if dotFrame and dotFrame.Show then
    dotFrame:Show()
  end
end

function StatusDot.create(factory, parent, anchorFrame, availability)
  local statusSize = Theme.LAYOUT.CONTACT_STATUS_SIZE

  local dotFrame = factory.CreateFrame("Frame", nil, parent)
  dotFrame:SetSize(statusSize, statusSize)
  dotFrame:SetPoint("BOTTOMRIGHT", anchorFrame, "BOTTOMRIGHT", Theme.LAYOUT.STATUS_DOT_CORNER_OFFSET, -Theme.LAYOUT.STATUS_DOT_CORNER_OFFSET)
  if dotFrame.SetFrameLevel and anchorFrame.GetFrameLevel then
    dotFrame:SetFrameLevel(anchorFrame:GetFrameLevel() + 2)
  end

  local dotTexture = dotFrame:CreateTexture(nil, "OVERLAY")
  dotTexture:SetAllPoints()
  dotTexture:SetTexture(CIRCLE_TEX)
  dotFrame.bg = dotTexture
  StatusDot.update(dotFrame, availability)

  return { frame = dotFrame, texture = dotTexture }
end

ns.ContactsListStatusDot = StatusDot
return StatusDot
