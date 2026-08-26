local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local PickerStyles = ns.PickerStyles or require("WhisperMessenger.UI.Shared.PickerStyles")
local Assets = ns.ChatBubbleReactionAssets or require("WhisperMessenger.UI.ChatBubble.ReactionAssets")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local MessageReactions = ns.MessageReactions or require("WhisperMessenger.Model.MessageReactions")

local ReactionPicker = {}
local PICKER_FRAME_NAME = "WhisperMessengerReactionPicker"
local pickerFrame



local function addSpecialFrame()
  _G.UISpecialFrames = _G.UISpecialFrames or {}
  for _, name in ipairs(_G.UISpecialFrames) do
    if name == PICKER_FRAME_NAME then
      return
    end
  end
  table.insert(_G.UISpecialFrames, PICKER_FRAME_NAME)
end

local function isMouseOver(frame)
  if type(frame.IsMouseOver) ~= "function" then
    return false
  end
  local ok, over = pcall(frame.IsMouseOver, frame)
  return ok and over == true
end

local function registerGlobalMouse(frame)
  if frame._globalMouseRegistered or type(frame.RegisterEvent) ~= "function" then
    return
  end
  local ok = pcall(frame.RegisterEvent, frame, "GLOBAL_MOUSE_DOWN")
  frame._globalMouseRegistered = ok
end

local function unregisterGlobalMouse(frame)
  if not frame._globalMouseRegistered or type(frame.UnregisterEvent) ~= "function" then
    return
  end
  pcall(frame.UnregisterEvent, frame, "GLOBAL_MOUSE_DOWN")
  frame._globalMouseRegistered = nil
end

local function applyPickerLayout(frame)
  local layout = Assets.GetPickerLayout()
  frame:SetSize(layout.frameWidth, layout.frameHeight)
  for index, button in ipairs(frame._reactionButtons) do
    local slot = index - 1
    local column = slot % layout.columns
    local row = math.floor(slot / layout.columns)
    button:SetSize(layout.buttonSize, layout.buttonSize)
    button:ClearAllPoints()
    button:SetPoint("TOPLEFT", frame, "TOPLEFT", 6 + column * layout.buttonSize, -5 - row * layout.buttonSize)
    button._icon:SetSize(layout.iconSize, layout.iconSize)
  end
  frame._copyButton:ClearAllPoints()
  frame._copyButton:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, layout.copyOffsetY)
  frame._copyButton:SetSize(layout.copyWidth, 24)
end

local function createPicker(factory)
  local parent = _G.UIParent
  if type(factory) ~= "table" or type(factory.CreateFrame) ~= "function" or parent == nil then
    return nil
  end

  local frame = factory.CreateFrame("Frame", PICKER_FRAME_NAME, parent)
  if frame.Hide then
    frame:Hide()
  end
  frame._factory = factory
  frame._reactionButtons = {}
  if frame.SetFrameStrata then
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
  end
  if frame.SetClampedToScreen then
    frame:SetClampedToScreen(true)
  end
  if frame.EnableMouse then
    frame:EnableMouse(true)
  end

  local background = frame:CreateTexture(nil, "BACKGROUND")
  background:SetAllPoints(frame)
  frame._background = background
  if type(UIHelpers.createBorderBox) == "function" then
    frame._border = UIHelpers.createBorderBox(frame, PickerStyles.BorderColor(), 1, "BORDER")
  end
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

  local copyButton = factory.CreateFrame("Button", nil, frame)
  local highlight = copyButton:CreateTexture(nil, "BACKGROUND")
  highlight:SetAllPoints(copyButton)
  PickerStyles.ApplyColor(highlight, PickerStyles.HighlightColor(0.35))
  highlight:Hide()
  copyButton._highlight = highlight

  local copyLabel = copyButton:CreateFontString(nil, "OVERLAY")
  copyLabel:SetPoint("CENTER", copyButton, "CENTER", 0, 0)
  UIHelpers.setFontObject(copyLabel, Theme.FONTS.icon_label)
  copyLabel:SetText(Localization.Text("Copy text"))
  UIHelpers.setTextColor(copyLabel, Theme.COLORS.option_button_text or Theme.COLORS.text_primary)
  copyButton:SetScript("OnEnter", function(self)
    PickerStyles.ApplyColor(self._highlight, PickerStyles.HighlightColor(0.35))
    self._highlight:Show()
  end)
  copyButton:SetScript("OnLeave", function(self)
    self._highlight:Hide()
  end)
  copyButton:SetScript("OnClick", function()
    local message = frame._message
    local copyText = frame._copyText
    ReactionPicker.Close()
    if type(copyText) == "function" then
      copyText(message and message.text or "")
    end
  end)
  frame._copyButton = copyButton
  frame._copyLabel = copyLabel
  applyPickerLayout(frame)

  frame:SetScript("OnEvent", function(self, event)
    if event == "GLOBAL_MOUSE_DOWN" and self._dismissArmed and not isMouseOver(self) then
      ReactionPicker.Close()
    end
  end)
  frame:SetScript("OnHide", function(self)
    unregisterGlobalMouse(self)
    self:SetScript("OnUpdate", nil)
    self._dismissArmed = nil
    PickerStyles.HideTooltip()
    self._anchor = nil
    self._message = nil
    self._onReact = nil
    self._copyText = nil
    self._canReact = nil
  end)

  frame._wmReactionPicker = true
  rawset(_G, PICKER_FRAME_NAME, frame)
  addSpecialFrame()
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

function ReactionPicker.Open(factory, anchorFrame, message, onReact, copyText, canReact)
  if type(onReact) ~= "function" or type(message) ~= "table" then
    return false
  end
  local frame = ensurePicker(factory)
  if frame == nil then
    return false
  end

  PickerStyles.ApplyPanelTheme(frame, frame._border)
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
  frame:ClearAllPoints()
  frame:SetPoint("BOTTOMLEFT", anchorFrame, "TOPLEFT", 0, 4)
  frame._dismissArmed = false
  registerGlobalMouse(frame)
  frame:SetScript("OnUpdate", function(self)
    self._dismissArmed = true
    self:SetScript("OnUpdate", nil)
  end)
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
end

function ReactionPicker.GetFrame()
  return pickerFrame
end

ns.ChatBubbleReactionPicker = ReactionPicker
return ReactionPicker
