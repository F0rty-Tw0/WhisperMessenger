local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")

local HoverCopy = {}

local COPY_BUTTON_SIZE = 14
-- Inside the bubble's top corner. The HIGH strata below keeps the button on
-- top of the sender name + time text strip above the bubble even when the
-- bubble is short and the name extends past the bubble's far edge.
local COPY_BUTTON_EDGE_INSET = 5
local COPY_BUTTON_TOP_OFFSET = 7
local COPY_BUTTON_DIM_ALPHA = 0.45
local COPY_BUTTON_TEXTURE = "Interface\\Buttons\\UI-GuildButton-PublicNote-Up"

local function isMouseOver(region)
  if region == nil or type(region.IsMouseOver) ~= "function" then
    return false
  end
  local ok, value = pcall(region.IsMouseOver, region)
  if ok then
    return value == true
  end
  return false
end

local function copyButtonOnEnter(self)
  if self.SetAlpha then
    self:SetAlpha(1)
  end
  local tooltip = _G.GameTooltip
  if type(tooltip) ~= "table" or type(tooltip.SetOwner) ~= "function" or type(tooltip.SetText) ~= "function" then
    return
  end
  tooltip:SetOwner(self, "ANCHOR_TOP")
  tooltip:SetText(Localization.Text("Copy text"))
  if type(tooltip.Show) == "function" then
    tooltip:Show()
  end
end

local function copyButtonOnLeave(self)
  if self.SetAlpha then
    self:SetAlpha(COPY_BUTTON_DIM_ALPHA)
  end
  local tooltip = _G.GameTooltip
  if type(tooltip) == "table" and type(tooltip.Hide) == "function" then
    local owner = type(tooltip.GetOwner) == "function" and tooltip:GetOwner() or nil
    if owner == nil or owner == self then
      tooltip:Hide()
    end
  end
  if not isMouseOver(self._wmCopyBubble) and self.Hide then
    self:Hide()
  end
end

local function copyButtonOnClick(self)
  local message = self._wmCopyMessage
  local text = message and message.text or nil
  if type(text) ~= "string" or text == "" or type(self._wmCopyText) ~= "function" then
    return
  end
  self._wmCopyText(text)
end

local function bubbleOnEnter(self)
  local button = self._copyButton
  if button and button.Show then
    button:Show()
  end
end

local function bubbleOnLeave(self)
  local button = self._copyButton
  if button == nil or isMouseOver(button) then
    return
  end
  if button.Hide then
    button:Hide()
  end
end

local function bubbleOnHide(self)
  local button = self._copyButton
  if button and button.Hide then
    button:Hide()
  end
end

local function ensureCopyButton(persistentFactory, frame)
  local button = frame._copyButton
  if button then
    return button
  end
  if type(persistentFactory) ~= "table" or type(persistentFactory.CreateFrame) ~= "function" then
    return nil
  end

  local buttonParent = (type(frame.GetParent) == "function" and frame:GetParent()) or frame
  button = persistentFactory.CreateFrame("Button", nil, buttonParent)
  button._wmCopyButton = true
  button._wmCopyBubble = frame
  button:SetSize(COPY_BUTTON_SIZE, COPY_BUTTON_SIZE)
  if button.EnableMouse then
    button:EnableMouse(true)
  end

  local texture = button:CreateTexture(nil, "OVERLAY")
  if texture.SetAllPoints then
    texture:SetAllPoints(button)
  end
  if texture.SetTexture then
    texture:SetTexture(COPY_BUTTON_TEXTURE)
  end
  if texture.SetVertexColor then
    texture:SetVertexColor(1, 1, 1, 1)
  end
  button._copyTexture = texture

  if button.SetAlpha then
    button:SetAlpha(COPY_BUTTON_DIM_ALPHA)
  end
  if button.Hide then
    button:Hide()
  end
  if button.SetScript then
    button:SetScript("OnEnter", copyButtonOnEnter)
    button:SetScript("OnLeave", copyButtonOnLeave)
    button:SetScript("OnClick", copyButtonOnClick)
  end

  frame._copyButton = button
  return button
end

function HoverCopy.Attach(persistentFactory, frame, message, copyText)
  local button = ensureCopyButton(persistentFactory, frame)
  if button == nil then
    return
  end
  button._wmCopyMessage = message
  button._wmCopyText = copyText
  button:ClearAllPoints()
  if message.direction == "out" then
    button:SetPoint("TOPLEFT", frame, "TOPLEFT", COPY_BUTTON_EDGE_INSET, COPY_BUTTON_TOP_OFFSET)
  else
    button:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -COPY_BUTTON_EDGE_INSET, COPY_BUTTON_TOP_OFFSET)
  end
  if button.SetFrameStrata then
    button:SetFrameStrata("HIGH")
  end
  if button.SetFrameLevel and frame.GetFrameLevel then
    local level = frame:GetFrameLevel() or 1
    button:SetFrameLevel(level + 10)
  end
  if button.Raise then
    button:Raise()
  end
  if button.SetAlpha then
    button:SetAlpha(COPY_BUTTON_DIM_ALPHA)
  end
  if button.Hide then
    button:Hide()
  end

  if frame.SetScript then
    frame:SetScript("OnEnter", bubbleOnEnter)
    frame:SetScript("OnLeave", bubbleOnLeave)
    frame:SetScript("OnHide", bubbleOnHide)
  end
end

ns.ChatBubbleHoverCopy = HoverCopy
return HoverCopy
