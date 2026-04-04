local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")

local Buttons = {}

-- Wire close, options, reset-window, reset-icon, clear-all-chats, and
-- settings tab buttons.
--
-- refs:
--   closeButton, optionsButton, resetWindowButton, resetIconButton,
--   clearAllChatsButton, optionsPanel, settingsPanels, settingsTabs
--
-- options:
--   onClose, onResetWindowPosition, onResetIconPosition, onClearAllChats,
--   setOptionsVisible, isShown, applyState, refreshSelection
function Buttons.WireButtons(refs, options)
  local closeButton = refs.closeButton
  local optionsButton = refs.optionsButton
  local resetWindowButton = refs.resetWindowButton
  local resetIconButton = refs.resetIconButton
  local clearAllChatsButton = refs.clearAllChatsButton
  local optionsPanel = refs.optionsPanel
  local settingsPanels = refs.settingsPanels or {}
  local settingsTabs = refs.settingsTabs or {}

  if closeButton and closeButton.SetScript then
    closeButton:SetScript("OnClick", function()
      options.onClose()
    end)
  end

  if optionsButton and optionsButton.SetScript then
    optionsButton:SetScript("OnClick", function()
      options.setOptionsVisible(not options.isShown(optionsPanel))
    end)
  end

  if resetWindowButton and resetWindowButton.SetScript then
    resetWindowButton:SetScript("OnClick", function()
      if options.onResetWindowPosition == nil then
        return
      end
      local nextState = options.onResetWindowPosition()
      if nextState ~= nil then
        options.applyState(nextState)
      end
    end)
  end

  if resetIconButton and resetIconButton.SetScript then
    resetIconButton:SetScript("OnClick", function()
      if options.onResetIconPosition then
        options.onResetIconPosition()
      end
    end)
  end

  if clearAllChatsButton and clearAllChatsButton.SetScript then
    local dialogName = "WHISPER_MESSENGER_CLEAR_ALL_CHATS"
    if not _G.StaticPopupDialogs then
      _G.StaticPopupDialogs = {}
    end
    _G.StaticPopupDialogs[dialogName] = {
      text = "Are you sure you want to clear all chats?\n\nThis will permanently delete all conversation history.",
      button1 = "Clear All",
      button2 = "Cancel",
      OnAccept = function()
        if options.onClearAllChats then
          options.onClearAllChats()
          options.refreshSelection({
            contacts = {},
            selectedContact = nil,
            conversation = nil,
            status = nil,
          }, true)
        end
      end,
      timeout = 0,
      whileDead = true,
      hideOnEscape = true,
      preferredIndex = 3,
    }

    clearAllChatsButton:SetScript("OnClick", function()
      _G.StaticPopup_Show(dialogName)
    end)
  end

  -- Tab switching: show one panel at a time, highlight active tab
  if #settingsTabs > 0 and #settingsPanels > 0 then
    local function activeHighlightColor()
      return Theme.COLORS.option_button_active or Theme.COLORS.bg_contact_selected or { 0.16, 0.18, 0.28, 0.80 }
    end
    local function activeHoverColor()
      return Theme.COLORS.option_button_active_hover or activeHighlightColor()
    end
    local function inactiveBackgroundColor()
      return Theme.COLORS.option_button_bg or { 0.14, 0.15, 0.20, 0.80 }
    end
    local function inactiveHoverColor()
      return Theme.COLORS.option_button_hover or inactiveBackgroundColor()
    end
    local function inactiveTextColor()
      return Theme.COLORS.option_button_text or Theme.COLORS.text_secondary
    end
    local function inactiveTextHoverColor()
      return Theme.COLORS.option_button_text_hover or Theme.COLORS.text_primary
    end
    local function activeTextColor()
      return Theme.COLORS.option_button_text_active or Theme.COLORS.text_primary
    end
    local function selectTab(index)
      for i, panel in ipairs(settingsPanels) do
        if panel and panel.Hide and panel.Show then
          if i == index then
            panel:Show()
          else
            panel:Hide()
          end
        end
      end
      for i, tab in ipairs(settingsTabs) do
        if tab and tab.bg and tab.SetScript then
          local bg = tab.bg
          local function applyTabVisual(hovered)
            local isActive = tab._wmIsActiveTab == true
            local color
            local textColor
            local hoverBg
            local hoverText
            if isActive then
              color = activeHighlightColor()
              hoverBg = activeHoverColor()
              textColor = activeTextColor()
              hoverText = activeTextColor()
            else
              color = inactiveBackgroundColor()
              hoverBg = inactiveHoverColor()
              textColor = inactiveTextColor()
              hoverText = inactiveTextHoverColor()
            end
            if tab.applyThemeColors then
              tab.applyThemeColors({
                bg = color,
                bgHover = hoverBg,
                text = textColor,
                textHover = hoverText,
              })
            end
            local paintColor = hovered and hoverBg or color
            if bg and bg.SetColorTexture then
              bg:SetColorTexture(paintColor[1], paintColor[2], paintColor[3], paintColor[4] or 1)
            end
            if tab.label and tab.label.SetTextColor then
              local paintText = hovered and hoverText or textColor
              tab.label:SetTextColor(paintText[1], paintText[2], paintText[3], paintText[4] or 1)
            end
          end
          tab._wmIsActiveTab = i == index
          tab._wmIsHoveredTab = tab.IsMouseOver and tab:IsMouseOver() or false
          applyTabVisual(tab._wmIsHoveredTab)
          tab:SetScript("OnEnter", function()
            tab._wmIsHoveredTab = true
            applyTabVisual(true)
          end)
          tab:SetScript("OnLeave", function()
            tab._wmIsHoveredTab = false
            applyTabVisual(false)
          end)
        end
      end
    end

    for i, tab in ipairs(settingsTabs) do
      if tab and tab.SetScript then
        local tabIndex = i
        tab:SetScript("OnClick", function()
          selectTab(tabIndex)
        end)
      end
    end

    -- Default: show first tab (General)
    selectTab(1)
  end
end

ns.MessengerWindowWindowScriptsButtons = Buttons

return Buttons
