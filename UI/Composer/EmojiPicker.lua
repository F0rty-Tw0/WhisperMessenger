local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local PickerStyles = ns.PickerStyles or require("WhisperMessenger.UI.Shared.PickerStyles")
local Assets = ns.ChatBubbleReactionAssets or require("WhisperMessenger.UI.ChatBubble.ReactionAssets")
local Popover = ns.ComposerPopover or require("WhisperMessenger.UI.Composer.Popover")

local EmojiPicker = {}

function EmojiPicker.Create(factory, parent, anchorFrame, onSelect)
  local popover = Popover.Create(factory, parent, anchorFrame)
  local frame = popover.frame

  local picker = {
    frame = frame,
    buttons = {},
    enabled = true,
  }

  local layout = Assets.GetPickerLayout()
  local iconSize = layout.iconSize
  local buttonSize = layout.buttonSize
  frame:SetSize(layout.frameWidth, buttonSize * layout.rows + 12)

  for index, key in ipairs(Assets.KEYS) do
    local slot = index - 1
    local column = slot % layout.columns
    local row = math.floor(slot / layout.columns)
    local button = factory.CreateFrame("Button", nil, frame)
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
      popover.close()
      onSelect(key)
    end)
    picker.buttons[index] = button
  end

  function picker:open()
    if not self.enabled then
      return false
    end
    popover.open()
    return true
  end

  function picker:close()
    popover.close()
  end

  function picker:toggle()
    if frame:IsShown() then
      popover.close()
      return false
    end
    return self:open()
  end

  function picker:setEnabled(enabled)
    self.enabled = enabled == true
    if not self.enabled then
      popover.close()
    end
  end

  function picker:refreshTheme()
    popover.refreshTheme()
    local highlightColor = PickerStyles.HighlightColor(0.35)
    for _, button in ipairs(self.buttons) do
      PickerStyles.ApplyColor(button._highlight, highlightColor)
    end
  end

  return picker
end

ns.ComposerEmojiPicker = EmojiPicker
return EmojiPicker
