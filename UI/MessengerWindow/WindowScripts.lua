local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local AlphaController = ns.MessengerWindowAlphaController
  or require("WhisperMessenger.UI.MessengerWindow.AlphaController")
local LayoutBuilder = ns.MessengerWindowLayoutBuilder or require("WhisperMessenger.UI.MessengerWindow.LayoutBuilder")
local ConversationPane = ns.ConversationPane or require("WhisperMessenger.UI.ConversationPane")

local WindowScripts = {}

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
function WindowScripts.WireButtons(refs, options)
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
    _G.StaticPopupDialogs = _G.StaticPopupDialogs or {}
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
    local activeHighlight = Theme.COLORS.bg_contact_selected or { 0.16, 0.18, 0.28, 0.80 }
    local inactiveBg = Theme.COLORS.option_button_bg or { 0.14, 0.15, 0.20, 0.80 }

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
        if tab and tab.children then
          for _, child in ipairs(tab.children) do
            if child.SetColorTexture then
              if i == index then
                child:SetColorTexture(
                  activeHighlight[1],
                  activeHighlight[2],
                  activeHighlight[3],
                  activeHighlight[4] or 1
                )
              else
                child:SetColorTexture(inactiveBg[1], inactiveBg[2], inactiveBg[3], inactiveBg[4] or 1)
              end
              break
            end
          end
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

-- Wire OnShow, OnHide, OnEnter, OnLeave, OnUpdate, OnSizeChanged,
-- OnDragStart, OnDragStop on the main frame, plus OnMouseDown/OnMouseUp
-- on the resize grip.
--
-- refs:
--   frame, resizeGrip
--
-- options:
--   refreshWindowAlpha, layout, composer, contactsController, conversation,
--   buildState, trace, onPositionChanged, Theme
function WindowScripts.WireFrame(refs, options)
  local frame = refs.frame
  local resizeGrip = refs.resizeGrip

  local alphaElapsed = 0
  local frameTheme = options.Theme or Theme

  if frame and frame.SetScript then
    frame:SetScript("OnShow", function()
      alphaElapsed = 0
      options.refreshWindowAlpha(true)
      options.trace("window shown")
    end)

    frame:SetScript("OnHide", function()
      alphaElapsed = 0
      options.trace("window hidden")
    end)

    frame:SetScript("OnEnter", function()
      options.refreshWindowAlpha(true)
    end)

    frame:SetScript("OnLeave", function()
      options.refreshWindowAlpha()
    end)

    frame:SetScript("OnUpdate", function(_, elapsed)
      alphaElapsed = alphaElapsed + (elapsed or 0)
      if alphaElapsed < frameTheme.WINDOW_ALPHA_UPDATE_INTERVAL then
        return
      end
      alphaElapsed = 0
      options.refreshWindowAlpha()
    end)

    frame:SetScript("OnSizeChanged", function(_self, w, h)
      LayoutBuilder.Relayout(options.layout, w, h)
      local contentW = w - frameTheme.CONTACTS_WIDTH - frameTheme.DIVIDER_THICKNESS
      if options.composer and options.composer.relayout then
        options.composer.relayout(contentW)
      end
      local contactsH = h - frameTheme.TOP_BAR_HEIGHT
      if options.contactsController and options.contactsController.fillViewport then
        options.contactsController.fillViewport(contactsH)
      end
      local threadH = contactsH - frameTheme.COMPOSER_HEIGHT - frameTheme.DIVIDER_THICKNESS
      if options.conversation then
        ConversationPane.Relayout(options.conversation, contentW, threadH)
      end
    end)

    frame:SetScript("OnDragStart", function(self)
      if self.IsMovable == nil or self:IsMovable() then
        self:StartMoving()
        options.trace("window drag start")
      end
    end)

    frame:SetScript("OnDragStop", function(self)
      self:StopMovingOrSizing()
      local nextState = options.buildState(self)
      options.trace("window drag stop", nextState.anchorPoint, nextState.x, nextState.y)
      if options.onPositionChanged then
        options.onPositionChanged(nextState)
      end
    end)
  end

  if resizeGrip and resizeGrip.SetScript then
    resizeGrip:SetScript("OnMouseDown", function(_self, button)
      if button == "LeftButton" then
        frame:StartSizing("BOTTOMRIGHT")
        options.trace("window resize start")
      end
    end)

    resizeGrip:SetScript("OnMouseUp", function(_self, button)
      if button == "LeftButton" then
        frame:StopMovingOrSizing()
        local nextState = options.buildState(frame)
        options.trace("window resize stop", nextState.width, nextState.height)
        if options.onPositionChanged then
          options.onPositionChanged(nextState)
        end
      end
    end)
  end
end

ns.MessengerWindowWindowScripts = WindowScripts

return WindowScripts
