local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")

local CIRCLE_TEX = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"

local StatusDot = {}

--- Create a status dot frame anchored to the bottom-right of anchorFrame.
--- Returns { frame = dotFrame, texture = dotTexture }.
---@param factory table frame factory
---@param parent table parent frame
---@param anchorFrame table frame to anchor to
---@param availability table|nil availability data with canWhisper and status fields
function StatusDot.create(factory, parent, anchorFrame, availability)
  local statusSize = Theme.LAYOUT.CONTACT_STATUS_SIZE

  local dotFrame = factory.CreateFrame("Frame", nil, parent)
  dotFrame:SetSize(statusSize, statusSize)
  dotFrame:SetPoint("BOTTOMRIGHT", anchorFrame, "BOTTOMRIGHT", 2, -2)
  if dotFrame.SetFrameLevel and anchorFrame.GetFrameLevel then
    dotFrame:SetFrameLevel(anchorFrame:GetFrameLevel() + 2)
  end

  local dotTexture = dotFrame:CreateTexture(nil, "OVERLAY")
  dotTexture:SetAllPoints()
  dotTexture:SetTexture(CIRCLE_TEX)

  -- Determine color key from availability
  local colorKey
  if availability then
    colorKey = availability.canWhisper and "online" or "offline"
    if availability.status == "WrongFaction" then
      colorKey = "dnd"
    elseif availability.status == "Away" then
      colorKey = "away"
    elseif availability.status == "Busy" then
      colorKey = "dnd"
    end
  else
    colorKey = "offline"
  end

  local c = Theme.COLORS[colorKey]
  if c then
    dotTexture:SetVertexColor(c[1], c[2], c[3], c[4] or 1)
  end

  dotFrame:Show()

  return { frame = dotFrame, texture = dotTexture }
end

ns.ContactsListStatusDot = StatusDot
return StatusDot
