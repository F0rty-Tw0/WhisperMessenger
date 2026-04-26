local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local StyledTextInputPopup = ns.StyledTextInputPopup or require("WhisperMessenger.UI.Shared.StyledTextInputPopup")
local ScrollView = ns.ScrollView or require("WhisperMessenger.UI.ScrollView.ScrollView")

-- Returns the visible tab's content extent (distance from the panel's top
-- to the last laid-out widget's bottom) so the shared options scrollview
-- can size its content frame per-tab. Each settings panel exposes a bottom
-- marker via `frame._wmBottomMarker` — a 1×PADDING spacer anchored under
-- the last control. The marker's bottom IS the panel's content bottom.
-- Returns 0 when the frame chain hasn't been laid out yet (GetTop nil) so
-- the caller can defer to the next frame and leave the previous size in
-- place rather than collapsing to a clipped state.
local function measurePanelContentHeight(panel)
  if type(panel) ~= "table" then
    return 0
  end
  local marker = panel._wmBottomMarker
  if not marker or type(panel.GetTop) ~= "function" or type(marker.GetBottom) ~= "function" then
    return 0
  end
  local panelTop = panel:GetTop()
  local markerBottom = marker:GetBottom()
  if type(panelTop) ~= "number" or type(markerBottom) ~= "number" then
    return 0
  end
  local height = panelTop - markerBottom
  if height <= 0 then
    return 0
  end
  return height
end

local Buttons = {}

-- Wire close, options, reset-window, reset-icon, clear-all-chats, and
-- settings tab buttons.
--
-- refs:
--   closeButton, optionsButton, newConversationButton, resetWindowButton,
--   resetIconButton, clearAllChatsButton, optionsPanel, settingsPanels,
--   settingsTabs
--
-- options:
--   onClose, onStartConversation, onResetWindowPosition,
--   onResetIconPosition, onClearAllChats, setOptionsVisible, isShown,
--   applyState, refreshSelection
function Buttons.WireButtons(refs, options)
  local closeButton = refs.closeButton
  local optionsButton = refs.optionsButton
  local newConversationButton = refs.newConversationButton
  local resetWindowButton = refs.resetWindowButton
  local resetIconButton = refs.resetIconButton
  local clearAllChatsButton = refs.clearAllChatsButton
  local optionsPanel = refs.optionsPanel
  local settingsPanels = refs.settingsPanels or {}
  local settingsTabs = refs.settingsTabs or {}
  local optionsScrollView = refs.optionsScrollView

  local function trimPlayerName(value)
    if type(value) ~= "string" then
      return nil
    end

    local trimmed = string.match(value, "^%s*(.-)%s*$") or ""
    if trimmed == "" then
      return nil
    end

    return trimmed
  end

  local function resolveConversationPopupEditBox(popup, dialogName)
    local resolved = StyledTextInputPopup.ResolveEditBox(popup, dialogName)
    if resolved ~= nil then
      return resolved
    end
    if type(popup) ~= "table" then
      return nil
    end
    if type(popup.editBox) == "table" then
      return popup.editBox
    end
    if type(popup.EditBox) == "table" then
      return popup.EditBox
    end
    if type(popup.GetEditBox) == "function" then
      local ok, editBox = pcall(popup.GetEditBox, popup)
      if ok then
        return editBox
      end
    end
    return nil
  end

  local function styleStartConversationDialog(popup, dialogName, value)
    StyledTextInputPopup.Apply(popup, dialogName, value, {
      styleSecondaryButton = true,
      fullWidthInput = true,
      inputHorizontalPadding = 14,
      minInputWidth = 260,
    })
  end

  local function restoreStartConversationDialog(popup, dialogName)
    StyledTextInputPopup.Restore(popup, dialogName, {
      styleSecondaryButton = true,
      clearEditBox = true,
    })
  end

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

  if newConversationButton and newConversationButton.SetScript and options.onStartConversation then
    local dialogName = "WHISPER_MESSENGER_START_CONVERSATION"
    if type(_G.StaticPopupDialogs) ~= "table" then
      _G.StaticPopupDialogs = {}
    end

    local dialog = _G.StaticPopupDialogs[dialogName]
    if type(dialog) ~= "table" then
      dialog = {
        text = "Start a new conversation",
        button1 = "Start",
        button2 = "Cancel",
        hasEditBox = true,
        editBoxWidth = 340,
        maxLetters = 255,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
      }
      _G.StaticPopupDialogs[dialogName] = dialog
    end

    dialog.OnAccept = function(popup)
      local editBox = resolveConversationPopupEditBox(popup, dialogName)
      local playerName = trimPlayerName(editBox and editBox.GetText and editBox:GetText() or nil)
      if playerName ~= nil and dialog._wmOnStartConversation then
        dialog._wmOnStartConversation(playerName)
      end
    end
    dialog._wmOnStartConversation = options.onStartConversation
    dialog.OnShow = function(popup, data)
      local value = tostring((popup and popup.data) or data or "")
      styleStartConversationDialog(popup, dialogName, value)
    end
    dialog.OnHide = function(popup)
      restoreStartConversationDialog(popup, dialogName)
    end

    newConversationButton:SetScript("OnClick", function()
      if type(_G.StaticPopup_Show) ~= "function" then
        return
      end

      local popup = _G.StaticPopup_Show(dialogName)
      if type(popup) == "table" then
        popup.data = ""
        styleStartConversationDialog(popup, dialogName, "")
      end

      local editBox = resolveConversationPopupEditBox(popup, dialogName) or _G.StaticPopup1EditBox
      if editBox and editBox.SetFocus then
        editBox:SetFocus()
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
    -- Apply the visible tab's measured content height to the shared
    -- scrollview. Touches HEIGHT only so the responsive width (driven by
    -- RefreshMetrics on every window resize) stays intact. Returns true if
    -- the measurement landed; false means layout wasn't resolved yet and
    -- the caller should retry on the next frame.
    local function applyVisibleTabContentHeight(visiblePanel)
      if not visiblePanel or not optionsScrollView or not optionsScrollView.content then
        return false
      end
      if type(optionsScrollView.content.SetHeight) ~= "function" then
        return false
      end
      local contentHeight = measurePanelContentHeight(visiblePanel)
      if contentHeight <= 0 then
        return false
      end
      optionsScrollView.content:SetHeight(contentHeight)
      if ScrollView and type(ScrollView.Sync) == "function" then
        ScrollView.Sync(optionsScrollView)
      end
      return true
    end

    local function scheduleVisibleTabRemeasure(visiblePanel)
      if not visiblePanel then
        return
      end
      -- WoW resolves frame geometry on the next render frame, so a
      -- measurement taken right after Show() can read nil GetTop. Schedule
      -- a follow-up tick that lands after layout settles. C_Timer is
      -- absent in fake_ui — the synchronous attempt above is the only
      -- path the tests exercise.
      if _G.C_Timer and type(_G.C_Timer.After) == "function" then
        _G.C_Timer.After(0, function()
          applyVisibleTabContentHeight(visiblePanel)
        end)
      end
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
      local visiblePanel = settingsPanels[index]
      if not applyVisibleTabContentHeight(visiblePanel) then
        scheduleVisibleTabRemeasure(visiblePanel)
      end
      -- Reset the shared options scroll position when switching tabs.
      -- Otherwise, scrolling within a long settings panel (e.g. Appearance)
      -- and then switching to a shorter panel leaves the new panel's content
      -- visually offset upward, so it "looks scrolled" even though there is
      -- nothing to scroll. SetVerticalScroll also re-Syncs the scrollbar
      -- range so the new content height takes effect immediately.
      if optionsScrollView and ScrollView and ScrollView.SetVerticalScroll then
        ScrollView.SetVerticalScroll(optionsScrollView, 0)
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

    -- The first selectTab(1) call happens while the options panel is still
    -- hidden, so GetTop/GetHeight return nil and the measurement falls back
    -- to the previous size. Re-run it on every OnShow so the first time the
    -- user opens options the scroll content already matches the active tab.
    if optionsPanel and type(optionsPanel.HookScript) == "function" then
      optionsPanel:HookScript("OnShow", function()
        for i, panel in ipairs(settingsPanels) do
          if panel and type(panel.IsShown) == "function" and panel:IsShown() then
            selectTab(i)
            return
          end
        end
      end)
    end

    -- Window resizes re-run refreshLayout via the existing OnSizeChanged the
    -- settings panel sets in SettingsPanels.createSettingsPanel — that can
    -- re-wrap labels and shift the bottom of content. HookScript stacks on
    -- top of that handler so we re-measure the visible panel afterwards.
    for _, panel in ipairs(settingsPanels) do
      if panel and type(panel.HookScript) == "function" then
        panel:HookScript("OnSizeChanged", function(self)
          if type(self.IsShown) == "function" and not self:IsShown() then
            return
          end
          if not applyVisibleTabContentHeight(self) then
            scheduleVisibleTabRemeasure(self)
          end
        end)
      end
    end
  end
end

ns.MessengerWindowWindowScriptsButtons = Buttons

return Buttons
