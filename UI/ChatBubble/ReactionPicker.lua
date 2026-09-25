local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local PickerStyles = ns.PickerStyles or require("WhisperMessenger.UI.Shared.PickerStyles")
local PickerPopup = ns.PickerPopup or require("WhisperMessenger.UI.Shared.PickerPopup")
local Assets = ns.ChatBubbleReactionAssets or require("WhisperMessenger.UI.ChatBubble.ReactionAssets")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local MessageReactions = ns.MessageReactions or require("WhisperMessenger.Model.MessageReactions")

local ReactionPicker = {}
local PICKER_FRAME_NAME = "WhisperMessengerReactionPicker"
-- Inner padding: left of the first column, above the first row.
local PAD_LEFT = 6
local PAD_TOP = 5
local pickerFrame

local function applyPickerLayout(frame)
  local layout = Assets.GetPickerLayout()
  frame:SetSize(layout.frameWidth, layout.frameHeight)
  for index, button in ipairs(frame._reactionButtons) do
    local slot = index - 1
    local column = slot % layout.columns
    local row = math.floor(slot / layout.columns)
    button:SetSize(layout.buttonSize, layout.buttonSize)
    button:ClearAllPoints()
    button:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD_LEFT + column * layout.buttonSize, -PAD_TOP - row * layout.buttonSize)
    button._icon:SetSize(layout.iconSize, layout.iconSize)
  end
  -- With a reply handler the bottom row splits into [Reply][Copy text].
  local copyX, copyWidth = PAD_LEFT, layout.copyWidth
  frame._replyButton:ClearAllPoints()
  if frame._onReply then
    local half = math.floor(layout.copyWidth / 2)
    frame._replyButton:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD_LEFT, layout.copyOffsetY)
    frame._replyButton:SetSize(half, PickerStyles.ROW_HEIGHT)
    frame._replyButton:Show()
    copyX, copyWidth = PAD_LEFT + half, layout.copyWidth - half
  else
    frame._replyButton:Hide()
  end
  frame._copyButton:ClearAllPoints()
  frame._copyButton:SetPoint("TOPLEFT", frame, "TOPLEFT", copyX, layout.copyOffsetY)
  frame._copyButton:SetSize(copyWidth, PickerStyles.ROW_HEIGHT)
end

local function createPicker(factory)
  local parent = _G.UIParent
  if type(factory) ~= "table" or type(factory.CreateFrame) ~= "function" or parent == nil then
    return nil
  end

  local frame = PickerPopup.CreatePanel(factory, parent, PICKER_FRAME_NAME, "FULLSCREEN_DIALOG")
  frame._factory = factory
  frame._reactionButtons = {}
  PickerStyles.ApplyPanelTheme(frame, frame._border)

  for index, key in ipairs(Assets.KEYS) do
    local button = factory.CreateFrame("Button", nil, frame)
    button._reactionKey = key

    local selectedMark = button:CreateTexture(nil, "BACKGROUND")
    selectedMark:SetAllPoints(button)
    PickerStyles.ApplyColor(selectedMark, PickerStyles.HighlightColor(0.35))
    selectedMark:Hide()
    button._selectedMark = selectedMark

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("CENTER", button, "CENTER", 0, 0)
    icon:SetTexture(Assets.TEXTURE)
    local coords = Assets.GetTexCoords(key)
    icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
    button._icon = icon

    button:SetScript("OnEnter", function(self)
      if not self._selected then
        PickerStyles.ApplyColor(selectedMark, PickerStyles.HighlightColor(0.35))
        selectedMark:Show()
      end
      PickerStyles.ShowTooltip(self, key)
    end)
    button:SetScript("OnLeave", function(self)
      if not self._selected then
        selectedMark:Hide()
      end
      PickerStyles.HideTooltip()
    end)
    button:SetScript("OnClick", function()
      local message = frame._message
      local onReact = frame._onReact
      local canReact = frame._canReact
      ReactionPicker.Close()
      if type(onReact) == "function" and (type(canReact) ~= "function" or canReact(message)) then
        onReact(message, key)
      end
    end)
    frame._reactionButtons[index] = button
  end

  local copyButton, copyLabel = PickerPopup.CreateTextButton(factory, frame, "Copy text", function()
    local message = frame._message
    local copyText = frame._copyText
    ReactionPicker.Close()
    if type(copyText) == "function" then
      copyText(message and message.text or "")
    end
  end)
  frame._copyButton = copyButton
  frame._copyLabel = copyLabel
  local replyButton, replyLabel = PickerPopup.CreateTextButton(factory, frame, "Reply", function()
    local message = frame._message
    local onReply = frame._onReply
    ReactionPicker.Close()
    if type(onReply) == "function" then
      onReply(message)
    end
  end)
  frame._replyButton = replyButton
  frame._replyLabel = replyLabel
  applyPickerLayout(frame)

  frame:SetScript("OnEvent", function(self, event)
    PickerPopup.HandleEvent(self, event, ReactionPicker.Close)
  end)
  frame:SetScript("OnHide", function(self)
    PickerPopup.Disarm(self)
    PickerStyles.HideTooltip()
    self._anchor = nil
    self._message = nil
    self._onReact = nil
    self._copyText = nil
    self._canReact = nil
    self._onReply = nil
  end)

  frame._wmReactionPicker = true
  rawset(_G, PICKER_FRAME_NAME, frame)
  PickerPopup.RegisterEscape(PICKER_FRAME_NAME)
  frame:Hide()
  return frame
end

local function ensurePicker(factory)
  if pickerFrame then
    return pickerFrame
  end
  local existing = rawget(_G, PICKER_FRAME_NAME)
  if type(existing) == "table" and existing._wmReactionPicker then
    pickerFrame = existing
    return pickerFrame
  end
  pickerFrame = createPicker(factory)
  return pickerFrame
end

-- onReply(message), optional: adds a Reply button beside Copy text.
function ReactionPicker.Open(factory, anchorFrame, message, onReact, copyText, canReact, onReply)
  if type(onReact) ~= "function" or type(message) ~= "table" then
    return false
  end
  local frame = ensurePicker(factory)
  if frame == nil then
    return false
  end

  PickerStyles.ApplyPanelTheme(frame, frame._border)
  frame._onReply = onReply
  applyPickerLayout(frame)
  frame._anchor = anchorFrame
  frame._message = message
  frame._onReact = onReact
  frame._copyText = copyText
  frame._canReact = canReact
  local visibleReaction = MessageReactions.VisibleReaction(message)
  local selectedKey = type(visibleReaction) == "table" and visibleReaction.key or nil
  for _, button in ipairs(frame._reactionButtons) do
    button._selected = button._reactionKey == selectedKey
    if button._selected then
      PickerStyles.ApplyColor(button._selectedMark, PickerStyles.HighlightColor())
      button._selectedMark:Show()
    else
      button._selectedMark:Hide()
    end
  end

  frame._copyLabel:SetText(Localization.Text("Copy text"))
  frame._replyLabel:SetText(Localization.Text("Reply"))
  frame:ClearAllPoints()
  frame:SetPoint("BOTTOMLEFT", anchorFrame, "TOPLEFT", 0, 4)
  PickerPopup.ArmDismiss(frame)
  frame:Show()
  return true
end

function ReactionPicker.Close()
  if pickerFrame == nil then
    return
  end
  pickerFrame:Hide()
  pickerFrame._anchor = nil
  pickerFrame._message = nil
  pickerFrame._onReact = nil
  pickerFrame._copyText = nil
  pickerFrame._canReact = nil
  pickerFrame._onReply = nil
end

function ReactionPicker.GetFrame()
  return pickerFrame
end

ns.ChatBubbleReactionPicker = ReactionPicker
return ReactionPicker
