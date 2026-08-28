local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local PickerStyles = ns.PickerStyles or require("WhisperMessenger.UI.Shared.PickerStyles")
local Assets = ns.ChatBubbleReactionAssets or require("WhisperMessenger.UI.ChatBubble.ReactionAssets")

local EmojiPicker = {}

local function isMouseOver(frame)
  if type(frame.IsMouseOver) ~= "function" then
    return false
  end
  local ok, over = pcall(frame.IsMouseOver, frame)
  return ok and over == true
end

function EmojiPicker.Create(factory, parent, anchorFrame, onSelect)
  local frame = factory.CreateFrame("Frame", nil, parent)
  frame:Hide()
  if frame.SetFrameStrata then
    frame:SetFrameStrata("DIALOG")
  end
  if frame.SetClampedToScreen then
    frame:SetClampedToScreen(true)
  end
  if frame.EnableMouse then
    frame:EnableMouse(true)
  end

  local picker = {
    frame = frame,
    buttons = {},
    enabled = true,
  }

  local background = frame:CreateTexture(nil, "BACKGROUND")
  background:SetAllPoints(frame)
  frame._background = background
  if type(UIHelpers.createBorderBox) == "function" then
    frame._border = UIHelpers.createBorderBox(frame, PickerStyles.BorderColor(), 1, "BORDER")
  end
  PickerStyles.ApplyPanelTheme(frame, frame._border)

  local layout = Assets.GetPickerLayout()
  local iconSize = layout.iconSize
  local buttonSize = layout.buttonSize
  frame:SetSize(layout.frameWidth, buttonSize * layout.rows + 12)

  local function close()
    frame:Hide()
  end

  local function unregisterOutsideClick()
    if frame._outsideClickRegistered and type(frame.UnregisterEvent) == "function" then
      pcall(frame.UnregisterEvent, frame, "GLOBAL_MOUSE_DOWN")
    end
    frame._outsideClickRegistered = nil
  end

  local function registerOutsideClick()
    if frame._outsideClickRegistered or type(frame.RegisterEvent) ~= "function" then
      return
    end
    local ok = pcall(frame.RegisterEvent, frame, "GLOBAL_MOUSE_DOWN")
    frame._outsideClickRegistered = ok
  end

  for index, key in ipairs(Assets.KEYS) do
    local slot = index - 1
    local column = slot % layout.columns
    local row = math.floor(slot / layout.columns)
    local button = factory.CreateFrame("Button", nil, frame)
    button._emojiKey = key
    button:SetSize(buttonSize, buttonSize)
    button:SetPoint("TOPLEFT", frame, "TOPLEFT", 6 + column * buttonSize, -6 - row * buttonSize)

    local highlight = button:CreateTexture(nil, "BACKGROUND")
    highlight:SetAllPoints(button)
    PickerStyles.ApplyColor(highlight, PickerStyles.HighlightColor(0.35))
    highlight:Hide()
    button._highlight = highlight

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("CENTER", button, "CENTER", 0, 0)
    icon:SetSize(iconSize, iconSize)
    icon:SetTexture(Assets.TEXTURE)
    local coords = Assets.GetTexCoords(key)
    icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])

    button:SetScript("OnEnter", function(self)
      if picker.enabled then
        highlight:Show()
        PickerStyles.ShowTooltip(self, key)
      end
    end)
    button:SetScript("OnLeave", function()
      highlight:Hide()
      PickerStyles.HideTooltip()
    end)
    button:SetScript("OnClick", function()
      PickerStyles.HideTooltip()
      if not picker.enabled then
        return
      end
      close()
      onSelect(key)
    end)
    picker.buttons[index] = button
  end

  frame:SetScript("OnEvent", function(self, event)
    if event == "GLOBAL_MOUSE_DOWN" and self._dismissArmed and not isMouseOver(self) and not isMouseOver(anchorFrame) then
      close()
    end
  end)
  frame:SetScript("OnHide", function(self)
    unregisterOutsideClick()
    self:SetScript("OnUpdate", nil)
    self._dismissArmed = nil
    PickerStyles.HideTooltip()
  end)

  function picker:open()
    if not self.enabled then
      return false
    end
    PickerStyles.ApplyPanelTheme(frame, frame._border)
    frame:ClearAllPoints()
    frame:SetPoint("BOTTOMRIGHT", anchorFrame, "TOPRIGHT", 0, 4)
    frame._dismissArmed = false
    registerOutsideClick()
    frame:SetScript("OnUpdate", function(updateFrame)
      updateFrame._dismissArmed = true
      updateFrame:SetScript("OnUpdate", nil)
    end)
    frame:Show()
    return true
  end

  function picker:close()
    close()
  end

  function picker:toggle()
    if frame:IsShown() then
      close()
      return false
    end
    return self:open()
  end

  function picker:setEnabled(enabled)
    self.enabled = enabled == true
    if not self.enabled then
      close()
    end
  end

  function picker:refreshTheme()
    PickerStyles.ApplyPanelTheme(frame, frame._border)
    local highlightColor = PickerStyles.HighlightColor(0.35)
    for _, button in ipairs(self.buttons) do
      PickerStyles.ApplyColor(button._highlight, highlightColor)
    end
  end

  PickerStyles.ApplyPanelTheme(frame, frame._border)
  return picker
end

ns.ComposerEmojiPicker = EmojiPicker
return EmojiPicker
