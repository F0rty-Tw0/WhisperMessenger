local FakeUI = require("tests.helpers.fake_ui")
local WindowScripts = require("WhisperMessenger.UI.MessengerWindow.WindowScripts")
local Theme = require("WhisperMessenger.UI.Theme")

return function()
  assert(WindowScripts ~= nil, "expected WindowScripts module to load")

  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)

  -- Shared stubs
  local function noop() end

  -- test_wire_buttons_sets_close_click

  do
    local closeButton = factory.CreateFrame("Frame", nil, parent)
    local optionsButton = factory.CreateFrame("Frame", nil, parent)
    local resetWindowButton = factory.CreateFrame("Frame", nil, parent)
    local resetIconButton = factory.CreateFrame("Frame", nil, parent)
    local clearAllChatsButton = factory.CreateFrame("Frame", nil, parent)
    local optionsPanel = factory.CreateFrame("Frame", nil, parent)

    local refs = {
      closeButton = closeButton,
      optionsButton = optionsButton,
      resetWindowButton = resetWindowButton,
      resetIconButton = resetIconButton,
      clearAllChatsButton = clearAllChatsButton,
      optionsPanel = optionsPanel,
    }
    local options = {
      onClose = noop,
      onResetWindowPosition = noop,
      onResetIconPosition = noop,
      onClearAllChats = noop,
      setOptionsVisible = noop,
      isShown = function(_target)
        return false
      end,
      applyState = noop,
      refreshSelection = noop,
    }

    WindowScripts.WireButtons(refs, options)

    assert(
      type(closeButton.scripts) == "table" and type(closeButton.scripts.OnClick) == "function",
      "test_wire_buttons_sets_close_click: expected closeButton to have OnClick script"
    )
  end

  -- test_wire_buttons_sets_options_click

  do
    local closeButton = factory.CreateFrame("Frame", nil, parent)
    local optionsButton = factory.CreateFrame("Frame", nil, parent)
    local resetWindowButton = factory.CreateFrame("Frame", nil, parent)
    local resetIconButton = factory.CreateFrame("Frame", nil, parent)
    local clearAllChatsButton = factory.CreateFrame("Frame", nil, parent)
    local optionsPanel = factory.CreateFrame("Frame", nil, parent)

    local refs = {
      closeButton = closeButton,
      optionsButton = optionsButton,
      resetWindowButton = resetWindowButton,
      resetIconButton = resetIconButton,
      clearAllChatsButton = clearAllChatsButton,
      optionsPanel = optionsPanel,
    }
    local options = {
      onClose = noop,
      onResetWindowPosition = noop,
      onResetIconPosition = noop,
      onClearAllChats = noop,
      setOptionsVisible = noop,
      isShown = function(_target)
        return false
      end,
      applyState = noop,
      refreshSelection = noop,
    }

    WindowScripts.WireButtons(refs, options)

    assert(
      type(optionsButton.scripts) == "table" and type(optionsButton.scripts.OnClick) == "function",
      "test_wire_buttons_sets_options_click: expected optionsButton to have OnClick script"
    )
  end

  -- test_wire_buttons_sets_new_conversation_click

  do
    local closeButton = factory.CreateFrame("Frame", nil, parent)
    local optionsButton = factory.CreateFrame("Frame", nil, parent)
    local newConversationButton = factory.CreateFrame("Frame", nil, parent)
    local resetWindowButton = factory.CreateFrame("Frame", nil, parent)
    local resetIconButton = factory.CreateFrame("Frame", nil, parent)
    local clearAllChatsButton = factory.CreateFrame("Frame", nil, parent)
    local optionsPanel = factory.CreateFrame("Frame", nil, parent)

    local refs = {
      closeButton = closeButton,
      optionsButton = optionsButton,
      newConversationButton = newConversationButton,
      resetWindowButton = resetWindowButton,
      resetIconButton = resetIconButton,
      clearAllChatsButton = clearAllChatsButton,
      optionsPanel = optionsPanel,
    }
    local options = {
      onClose = noop,
      onStartConversation = noop,
      onResetWindowPosition = noop,
      onResetIconPosition = noop,
      onClearAllChats = noop,
      setOptionsVisible = noop,
      isShown = function(_target)
        return false
      end,
      applyState = noop,
      refreshSelection = noop,
    }

    WindowScripts.WireButtons(refs, options)

    assert(
      type(newConversationButton.scripts) == "table" and type(newConversationButton.scripts.OnClick) == "function",
      "test_wire_buttons_sets_new_conversation_click: expected newConversationButton to have OnClick script"
    )
  end

  -- test_new_conversation_click_shows_popup

  do
    local popupShown = nil
    rawset(_G, "StaticPopup_Show", function(dialogName)
      popupShown = dialogName
      return nil
    end)
    _G.StaticPopupDialogs = nil

    local newConversationButton = factory.CreateFrame("Frame", nil, parent)
    local refs = {
      closeButton = factory.CreateFrame("Frame", nil, parent),
      optionsButton = factory.CreateFrame("Frame", nil, parent),
      newConversationButton = newConversationButton,
      resetWindowButton = factory.CreateFrame("Frame", nil, parent),
      resetIconButton = factory.CreateFrame("Frame", nil, parent),
      clearAllChatsButton = factory.CreateFrame("Frame", nil, parent),
      optionsPanel = factory.CreateFrame("Frame", nil, parent),
    }
    local options = {
      onClose = noop,
      onStartConversation = noop,
      onResetWindowPosition = noop,
      onResetIconPosition = noop,
      onClearAllChats = noop,
      setOptionsVisible = noop,
      isShown = function()
        return false
      end,
      applyState = noop,
      refreshSelection = noop,
    }

    WindowScripts.WireButtons(refs, options)
    newConversationButton.scripts.OnClick(newConversationButton)

    assert(
      popupShown == "WHISPER_MESSENGER_START_CONVERSATION",
      "test_new_conversation_click_shows_popup: expected StaticPopup_Show to be called with start conversation dialog name"
    )

    rawset(_G, "StaticPopup_Show", nil)
    _G.StaticPopupDialogs = nil
  end

  -- test_new_conversation_accept_trims_and_invokes_callback

  do
    local startedPlayerName = nil
    _G.StaticPopupDialogs = {}

    local refs = {
      closeButton = factory.CreateFrame("Frame", nil, parent),
      optionsButton = factory.CreateFrame("Frame", nil, parent),
      newConversationButton = factory.CreateFrame("Frame", nil, parent),
      resetWindowButton = factory.CreateFrame("Frame", nil, parent),
      resetIconButton = factory.CreateFrame("Frame", nil, parent),
      clearAllChatsButton = factory.CreateFrame("Frame", nil, parent),
      optionsPanel = factory.CreateFrame("Frame", nil, parent),
    }
    local options = {
      onClose = noop,
      onStartConversation = function(playerName)
        startedPlayerName = playerName
      end,
      onResetWindowPosition = noop,
      onResetIconPosition = noop,
      onClearAllChats = noop,
      setOptionsVisible = noop,
      isShown = function()
        return false
      end,
      applyState = noop,
      refreshSelection = noop,
    }

    WindowScripts.WireButtons(refs, options)

    local dialog = _G.StaticPopupDialogs["WHISPER_MESSENGER_START_CONVERSATION"]
    assert(dialog ~= nil, "test_new_conversation_accept_trims_and_invokes_callback: expected dialog registration")
    assert(type(dialog.OnAccept) == "function", "test_new_conversation_accept_trims_and_invokes_callback: expected OnAccept")
    assert(type(dialog.OnShow) == "function", "test_new_conversation_accept_trims_and_invokes_callback: expected OnShow")
    assert(type(dialog.OnHide) == "function", "test_new_conversation_accept_trims_and_invokes_callback: expected OnHide")

    dialog.OnAccept({
      editBox = {
        GetText = function()
          return "   Jaina Proudmoore   "
        end,
      },
    })

    assert(
      startedPlayerName == "Jaina Proudmoore",
      "test_new_conversation_accept_trims_and_invokes_callback: expected trimmed player name to be forwarded"
    )

    _G.StaticPopupDialogs = nil
  end

  -- test_new_conversation_accept_ignores_empty_names

  do
    local callbackCount = 0
    _G.StaticPopupDialogs = {}

    local refs = {
      closeButton = factory.CreateFrame("Frame", nil, parent),
      optionsButton = factory.CreateFrame("Frame", nil, parent),
      newConversationButton = factory.CreateFrame("Frame", nil, parent),
      resetWindowButton = factory.CreateFrame("Frame", nil, parent),
      resetIconButton = factory.CreateFrame("Frame", nil, parent),
      clearAllChatsButton = factory.CreateFrame("Frame", nil, parent),
      optionsPanel = factory.CreateFrame("Frame", nil, parent),
    }
    local options = {
      onClose = noop,
      onStartConversation = function(_)
        callbackCount = callbackCount + 1
      end,
      onResetWindowPosition = noop,
      onResetIconPosition = noop,
      onClearAllChats = noop,
      setOptionsVisible = noop,
      isShown = function()
        return false
      end,
      applyState = noop,
      refreshSelection = noop,
    }

    WindowScripts.WireButtons(refs, options)

    local dialog = _G.StaticPopupDialogs["WHISPER_MESSENGER_START_CONVERSATION"]
    assert(dialog ~= nil, "test_new_conversation_accept_ignores_empty_names: expected dialog registration")

    dialog.OnAccept({
      editBox = {
        GetText = function()
          return " \n\t "
        end,
      },
    })

    assert(callbackCount == 0, "test_new_conversation_accept_ignores_empty_names: expected callback to stay untouched for whitespace input")

    _G.StaticPopupDialogs = nil
  end

  -- test_new_conversation_popup_show_hide_handlers_are_safe

  do
    _G.StaticPopupDialogs = {}

    local refs = {
      closeButton = factory.CreateFrame("Frame", nil, parent),
      optionsButton = factory.CreateFrame("Frame", nil, parent),
      newConversationButton = factory.CreateFrame("Frame", nil, parent),
      resetWindowButton = factory.CreateFrame("Frame", nil, parent),
      resetIconButton = factory.CreateFrame("Frame", nil, parent),
      clearAllChatsButton = factory.CreateFrame("Frame", nil, parent),
      optionsPanel = factory.CreateFrame("Frame", nil, parent),
    }
    local options = {
      onClose = noop,
      onStartConversation = noop,
      onResetWindowPosition = noop,
      onResetIconPosition = noop,
      onClearAllChats = noop,
      setOptionsVisible = noop,
      isShown = function()
        return false
      end,
      applyState = noop,
      refreshSelection = noop,
    }

    WindowScripts.WireButtons(refs, options)

    local dialog = _G.StaticPopupDialogs["WHISPER_MESSENGER_START_CONVERSATION"]
    assert(dialog ~= nil, "test_new_conversation_popup_show_hide_handlers_are_safe: expected dialog registration")
    assert(type(dialog.OnShow) == "function", "test_new_conversation_popup_show_hide_handlers_are_safe: expected OnShow")
    assert(type(dialog.OnHide) == "function", "test_new_conversation_popup_show_hide_handlers_are_safe: expected OnHide")

    local function makePopupButton(name)
      local button = factory.CreateFrame("Button", name, parent)
      button._normalTexture = "orig-normal-" .. tostring(name)
      function button:GetNormalTexture()
        return self._normalTexture
      end
      function button:SetNormalTexture(value)
        self._normalTexture = value
      end
      button.text = factory.CreateFrame("FontString", nil, button)
      return button
    end

    local fakePopup = factory.CreateFrame("Frame", nil, parent)
    fakePopup:SetWidth(420)
    fakePopup.editBox = factory.CreateFrame("EditBox", nil, fakePopup)
    fakePopup.editBox:SetText("")
    fakePopup.button1 = makePopupButton("start")
    fakePopup.button2 = makePopupButton("cancel")
    fakePopup.text = factory.CreateFrame("FontString", nil, fakePopup)

    local showOk, showErr = pcall(dialog.OnShow, fakePopup, "Thrall")
    assert(showOk == true, "test_new_conversation_popup_show_hide_handlers_are_safe: expected OnShow to be safe: " .. tostring(showErr))
    assert(fakePopup.editBox.text == "Thrall", "test_new_conversation_popup_show_hide_handlers_are_safe: expected OnShow to prime editbox text")
    assert(
      fakePopup.editBox.width == 392,
      "test_new_conversation_popup_show_hide_handlers_are_safe: expected OnShow to stretch editbox to near full popup width"
    )
    assert(fakePopup._wmManualCopyStyleActive == true, "test_new_conversation_popup_show_hide_handlers_are_safe: expected dialog style to activate")
    assert(
      fakePopup.button1._wmManualCopyStyleActive == true,
      "test_new_conversation_popup_show_hide_handlers_are_safe: expected start button style to activate"
    )
    assert(
      fakePopup.button2._wmManualCopyStyleActive == true,
      "test_new_conversation_popup_show_hide_handlers_are_safe: expected cancel button style to activate"
    )
    assert(
      fakePopup.button1._normalTexture == "",
      "test_new_conversation_popup_show_hide_handlers_are_safe: expected style to override start button normal texture"
    )

    local hideOk, hideErr = pcall(dialog.OnHide, fakePopup)
    assert(hideOk == true, "test_new_conversation_popup_show_hide_handlers_are_safe: expected OnHide to be safe: " .. tostring(hideErr))
    assert(fakePopup.editBox.text == "", "test_new_conversation_popup_show_hide_handlers_are_safe: expected OnHide to clear editbox text")
    assert(fakePopup._wmManualCopyStyleActive == false, "test_new_conversation_popup_show_hide_handlers_are_safe: expected dialog style to restore")
    assert(
      fakePopup.button1._wmManualCopyStyleActive == false,
      "test_new_conversation_popup_show_hide_handlers_are_safe: expected start button style to restore"
    )
    assert(
      fakePopup.button2._wmManualCopyStyleActive == false,
      "test_new_conversation_popup_show_hide_handlers_are_safe: expected cancel button style to restore"
    )
    assert(
      fakePopup.button1._normalTexture == "orig-normal-start",
      "test_new_conversation_popup_show_hide_handlers_are_safe: expected start button normal texture to restore exactly"
    )
    assert(
      fakePopup.button2._normalTexture == "orig-normal-cancel",
      "test_new_conversation_popup_show_hide_handlers_are_safe: expected cancel button normal texture to restore exactly"
    )
    _G.StaticPopupDialogs = nil
  end

  -- test_wire_frame_sets_on_show

  do
    local frame = factory.CreateFrame("Frame", nil, parent)
    local resizeGrip = factory.CreateFrame("Frame", nil, parent)

    local refs = { frame = frame, resizeGrip = resizeGrip }
    local options = {
      refreshWindowAlpha = noop,
      layout = {},
      composer = nil,
      contactsController = nil,
      conversation = nil,
      buildState = function(_target)
        return {}
      end,
      trace = noop,
      onPositionChanged = noop,
      Theme = Theme,
    }

    WindowScripts.WireFrame(refs, options)

    assert(
      type(frame.scripts) == "table" and type(frame.scripts.OnShow) == "function",
      "test_wire_frame_sets_on_show: expected frame to have OnShow script"
    )
  end

  -- test_wire_frame_sets_on_size_changed

  do
    local frame = factory.CreateFrame("Frame", nil, parent)
    local resizeGrip = factory.CreateFrame("Frame", nil, parent)

    local refs = { frame = frame, resizeGrip = resizeGrip }
    local options = {
      refreshWindowAlpha = noop,
      layout = {},
      composer = nil,
      contactsController = nil,
      conversation = nil,
      buildState = function(_target)
        return {}
      end,
      trace = noop,
      onPositionChanged = noop,
      Theme = Theme,
    }

    WindowScripts.WireFrame(refs, options)

    assert(
      type(frame.scripts) == "table" and type(frame.scripts.OnSizeChanged) == "function",
      "test_wire_frame_sets_on_size_changed: expected frame to have OnSizeChanged script"
    )
  end

  -- test_wire_frame_sets_drag_scripts

  do
    local frame = factory.CreateFrame("Frame", nil, parent)
    local resizeGrip = factory.CreateFrame("Frame", nil, parent)

    local refs = { frame = frame, resizeGrip = resizeGrip }
    local options = {
      refreshWindowAlpha = noop,
      layout = {},
      composer = nil,
      contactsController = nil,
      conversation = nil,
      buildState = function(_target)
        return {}
      end,
      trace = noop,
      onPositionChanged = noop,
      Theme = Theme,
    }

    WindowScripts.WireFrame(refs, options)

    assert(
      type(frame.scripts) == "table" and type(frame.scripts.OnDragStart) == "function",
      "test_wire_frame_sets_drag_scripts: expected frame to have OnDragStart script"
    )
    assert(type(frame.scripts.OnDragStop) == "function", "test_wire_frame_sets_drag_scripts: expected frame to have OnDragStop script")
  end

  -- test_on_show_focuses_composer_when_auto_focus_enabled

  do
    local frame = factory.CreateFrame("Frame", nil, parent)
    local resizeGrip = factory.CreateFrame("Frame", nil, parent)
    local composerInput = factory.CreateFrame("EditBox", nil, parent)

    local refs = { frame = frame, resizeGrip = resizeGrip }
    local options = {
      refreshWindowAlpha = noop,
      layout = {},
      composer = nil,
      contactsController = nil,
      conversation = nil,
      buildState = function(_target)
        return {}
      end,
      trace = noop,
      onPositionChanged = noop,
      Theme = Theme,
      composerInput = composerInput,
      getAutoFocusChatInput = function()
        return true
      end,
    }

    WindowScripts.WireFrame(refs, options)

    -- Trigger OnShow
    frame:Show()

    assert(composerInput._hasFocus == true, "test_on_show_focuses_composer_when_auto_focus_enabled: composer input should have focus")
  end

  -- test_on_show_does_not_focus_when_auto_focus_disabled

  do
    local frame = factory.CreateFrame("Frame", nil, parent)
    local resizeGrip = factory.CreateFrame("Frame", nil, parent)
    local composerInput = factory.CreateFrame("EditBox", nil, parent)

    local refs = { frame = frame, resizeGrip = resizeGrip }
    local options = {
      refreshWindowAlpha = noop,
      layout = {},
      composer = nil,
      contactsController = nil,
      conversation = nil,
      buildState = function(_target)
        return {}
      end,
      trace = noop,
      onPositionChanged = noop,
      Theme = Theme,
      composerInput = composerInput,
      getAutoFocusChatInput = function()
        return false
      end,
    }

    WindowScripts.WireFrame(refs, options)

    frame:Show()

    assert(composerInput._hasFocus == false, "test_on_show_does_not_focus_when_auto_focus_disabled: composer input should NOT have focus")
  end

  -- test_select_tab_sets_active_bg_persists_after_leave

  do
    local UIHelpers = require("WhisperMessenger.UI.Helpers")
    local optionsPanel = factory.CreateFrame("Frame", nil, parent)

    local tabColors = {
      bg = Theme.COLORS.option_button_bg,
      bgHover = Theme.COLORS.option_button_hover,
      text = Theme.COLORS.option_button_text,
      textHover = Theme.COLORS.option_button_text_hover,
    }
    local tabLayout = { height = 30, width = 200 }

    local tab1 = UIHelpers.createOptionButton(factory, optionsPanel, "General", tabColors, tabLayout)
    local tab2 = UIHelpers.createOptionButton(factory, optionsPanel, "Appearance", tabColors, tabLayout)

    local panel1 = factory.CreateFrame("Frame", nil, parent)
    local panel2 = factory.CreateFrame("Frame", nil, parent)

    local refs = {
      closeButton = factory.CreateFrame("Frame", nil, parent),
      optionsButton = factory.CreateFrame("Frame", nil, parent),
      resetWindowButton = factory.CreateFrame("Frame", nil, parent),
      resetIconButton = factory.CreateFrame("Frame", nil, parent),
      clearAllChatsButton = factory.CreateFrame("Frame", nil, parent),
      optionsPanel = factory.CreateFrame("Frame", nil, parent),
      settingsTabs = { tab1, tab2 },
      settingsPanels = { panel1, panel2 },
    }
    local opts = {
      onClose = noop,
      onResetWindowPosition = noop,
      onResetIconPosition = noop,
      onClearAllChats = noop,
      setOptionsVisible = noop,
      isShown = function()
        return false
      end,
      applyState = noop,
      refreshSelection = noop,
    }

    WindowScripts.WireButtons(refs, opts)

    -- Click tab2 while hovered to make it active
    tab2.mouseOver = true
    tab2.scripts.OnClick()

    assert(tab2.bg ~= nil, "tab2 should have a .bg reference")

    local activeColor = Theme.COLORS.option_button_active or Theme.COLORS.bg_contact_selected or { 0.16, 0.18, 0.28, 0.80 }
    local activeHoverColor = Theme.COLORS.option_button_active_hover or activeColor

    assert(
      tab2.bg.color[1] == activeHoverColor[1] and tab2.bg.color[2] == activeHoverColor[2],
      "test_select_tab_sets_active_bg_persists_after_leave: active hovered tab should use hover-active color immediately"
    )
    tab2.mouseOver = false
    -- Simulate mouse leave on the active tab
    if tab2.scripts.OnLeave then
      tab2.scripts.OnLeave()
    end

    -- After leaving, active tab should retain its active bg color
    assert(
      tab2.bg.color[1] == activeColor[1] and tab2.bg.color[2] == activeColor[2],
      "test_select_tab_sets_active_bg_persists_after_leave: active tab bg should persist after OnLeave"
    )

    -- Inactive tab (tab1) should have inactive bg after leave
    if tab1.scripts.OnLeave then
      tab1.scripts.OnLeave()
    end
    local inactiveColor = Theme.COLORS.option_button_bg or { 0.14, 0.15, 0.20, 0.80 }
    assert(
      tab1.bg.color[1] == inactiveColor[1] and tab1.bg.color[2] == inactiveColor[2],
      "test_select_tab_sets_active_bg_persists_after_leave: inactive tab bg should revert after OnLeave"
    )
  end

  -- test_wire_frame_sets_resize_grip_scripts

  do
    local frame = factory.CreateFrame("Frame", nil, parent)
    local resizeGrip = factory.CreateFrame("Frame", nil, parent)

    local refs = { frame = frame, resizeGrip = resizeGrip }
    local options = {
      refreshWindowAlpha = noop,
      layout = {},
      composer = nil,
      contactsController = nil,
      conversation = nil,
      buildState = function(_target)
        return {}
      end,
      trace = noop,
      onPositionChanged = noop,
      Theme = Theme,
    }

    WindowScripts.WireFrame(refs, options)

    assert(
      type(resizeGrip.scripts) == "table" and type(resizeGrip.scripts.OnMouseDown) == "function",
      "test_wire_frame_sets_resize_grip_scripts: expected resizeGrip to have OnMouseDown script"
    )
    assert(type(resizeGrip.scripts.OnMouseUp) == "function", "test_wire_frame_sets_resize_grip_scripts: expected resizeGrip to have OnMouseUp script")
  end

  -- test_resize_grip_uses_preview_and_commits_on_release

  do
    local frame = factory.CreateFrame("Frame", nil, parent)
    frame:SetSize(920, 580)
    frame.resizeBounds = { 640, 420, 1280, 720 }
    local resizeGrip = factory.CreateFrame("Frame", nil, parent)

    local relayoutArgs = nil
    local persistedState = nil
    local refs = { frame = frame, resizeGrip = resizeGrip }
    local options = {
      refreshWindowAlpha = noop,
      relayout = function(w, h, requestedContactsWidth, refreshContactsLayout)
        relayoutArgs = {
          width = w,
          height = h,
          contactsWidth = requestedContactsWidth,
          refresh = refreshContactsLayout,
        }
      end,
      buildState = function(target)
        return { width = target.width, height = target.height }
      end,
      trace = noop,
      onPositionChanged = function(state)
        persistedState = state
      end,
      Theme = Theme,
      getCursorX = function()
        return 1200
      end,
      getCursorY = function()
        return 100
      end,
      getFrameLeft = function()
        return 100
      end,
      getFrameTop = function()
        return 760
      end,
    }

    WindowScripts.WireFrame(refs, options)

    resizeGrip.scripts.OnMouseDown(resizeGrip, "LeftButton")
    assert(frame.sizingAnchor == nil, "expected deferred resize to avoid native StartSizing")
    assert(resizeGrip.preview ~= nil and resizeGrip.preview.bg:IsShown(), "expected resize preview to be visible during drag")
    assert(resizeGrip.preview.bg.parent ~= frame, "expected resize preview to live outside the resized frame")
    assert(frame:GetAlpha() <= 0.08, "expected window alpha to fade during deferred resize drag")
    frame.scripts.OnLeave(frame)
    assert(frame:GetAlpha() <= 0.08, "expected OnLeave to not override resize fade while dragging")

    frame.scripts.OnUpdate(frame, Theme.WINDOW_ALPHA_UPDATE_INTERVAL)
    resizeGrip.scripts.OnMouseUp(resizeGrip, "LeftButton")

    assert(resizeGrip.preview.bg:IsShown() == false, "expected resize preview to hide after release")
    assert(frame:GetAlpha() > 0.08, "expected window alpha to restore after deferred resize release")
    assert(relayoutArgs ~= nil, "expected relayout to run when deferred resize commits")
    assert(relayoutArgs.width == 1100 and relayoutArgs.height == 660, "expected committed resize dimensions from preview")
    assert(frame.point[1] == "TOPLEFT", "expected deferred resize commit to preserve top-left anchor")
    assert(frame.point[4] == 100 and frame.point[5] == 760, "expected deferred resize commit to preserve top-left position")
    assert(persistedState ~= nil, "expected committed resize to persist state")
    assert(persistedState.width == 1100 and persistedState.height == 660, "expected persisted dimensions to match committed preview")
  end

  -- test_wire_frame_wires_contacts_resize_handle_and_persists_width

  do
    local frame = factory.CreateFrame("Frame", nil, parent)
    frame:SetSize(920, 580)
    local resizeGrip = factory.CreateFrame("Frame", nil, parent)
    local contactsResizeHandle = factory.CreateFrame("Frame", nil, parent)
    if Theme.SetPreset then
      Theme.SetPreset("wow_default")
    end

    local contactsDivider = frame:CreateTexture(nil, "BORDER")
    contactsResizeHandle.hoverBg = contactsResizeHandle:CreateTexture(nil, "BACKGROUND")
    contactsResizeHandle.outline = {
      top = contactsResizeHandle:CreateTexture(nil, "OVERLAY"),
      bottom = contactsResizeHandle:CreateTexture(nil, "OVERLAY"),
      left = contactsResizeHandle:CreateTexture(nil, "OVERLAY"),
      right = contactsResizeHandle:CreateTexture(nil, "OVERLAY"),
    }
    for _, edge in pairs(contactsResizeHandle.outline) do
      edge:Hide()
    end

    local relayoutArgs = nil
    local persistedState = nil
    local refs = {
      frame = frame,
      resizeGrip = resizeGrip,
      contactsResizeHandle = contactsResizeHandle,
    }
    local options = {
      refreshWindowAlpha = noop,
      relayout = function(w, h, requestedContactsWidth, refreshContactsLayout)
        relayoutArgs = {
          width = w,
          height = h,
          contactsWidth = requestedContactsWidth,
          refresh = refreshContactsLayout,
        }
      end,
      buildState = function()
        return { contactsWidth = relayoutArgs and relayoutArgs.contactsWidth or nil }
      end,
      trace = noop,
      onPositionChanged = function(state)
        persistedState = state
      end,
      Theme = Theme,
      layout = { contactsDivider = contactsDivider },
      getCursorX = function()
        return 260
      end,
      getFrameLeft = function()
        return 100
      end,
    }

    WindowScripts.WireFrame(refs, options)

    assert(
      type(contactsResizeHandle.scripts) == "table" and type(contactsResizeHandle.scripts.OnMouseDown) == "function",
      "test_wire_frame_wires_contacts_resize_handle_and_persists_width: expected contactsResizeHandle OnMouseDown"
    )
    assert(
      type(contactsResizeHandle.scripts.OnEnter) == "function",
      "test_wire_frame_wires_contacts_resize_handle_and_persists_width: expected contactsResizeHandle OnEnter"
    )
    assert(
      type(contactsResizeHandle.scripts.OnLeave) == "function",
      "test_wire_frame_wires_contacts_resize_handle_and_persists_width: expected contactsResizeHandle OnLeave"
    )
    assert(
      type(contactsResizeHandle.scripts.OnMouseUp) == "function",
      "test_wire_frame_wires_contacts_resize_handle_and_persists_width: expected contactsResizeHandle OnMouseUp"
    )

    local activeDividerColor = Theme.COLORS.contacts_divider_hover
    local activeHoverFill = Theme.COLORS.contacts_resize_hover_fill
    local activeOutline = Theme.COLORS.contacts_resize_outline
    local idleDividerColor = Theme.COLORS.contacts_divider

    contactsResizeHandle.scripts.OnEnter(contactsResizeHandle)
    assert(
      contactsDivider.color[1] == activeDividerColor[1] and contactsDivider.color[2] == activeDividerColor[2],
      "expected contacts divider to use hover color on handle hover"
    )
    assert(
      contactsResizeHandle.hoverBg.color[1] == activeHoverFill[1] and contactsResizeHandle.hoverBg.color[4] == activeHoverFill[4],
      "expected contacts resize hover fill color to apply on handle hover"
    )
    assert(
      contactsResizeHandle.outline.top.color[1] == activeOutline[1] and contactsResizeHandle.outline.top.shown == true,
      "expected contacts resize outline to apply on handle hover"
    )

    contactsResizeHandle.scripts.OnLeave(contactsResizeHandle)
    assert(
      contactsDivider.color[1] == idleDividerColor[1] and contactsDivider.color[2] == idleDividerColor[2],
      "expected contacts divider to restore idle color after hover"
    )
    assert(contactsResizeHandle.hoverBg.color[4] == 0, "expected contacts resize hover fill to clear after hover")
    assert(contactsResizeHandle.outline.top.shown == false, "expected contacts resize outline to hide after hover")
    contactsResizeHandle.scripts.OnMouseDown(contactsResizeHandle, "LeftButton")
    assert(relayoutArgs ~= nil, "expected relayout call while resizing contacts")
    assert(relayoutArgs.contactsWidth == 160, "expected requested contacts width 160 from cursor delta")
    assert(relayoutArgs.refresh == true, "expected contacts resize relayout to request list refresh")

    frame.scripts.OnMouseUp(frame, "LeftButton")
    assert(persistedState ~= nil, "expected contacts resize mouseup to persist state")
    assert(persistedState.contactsWidth == 160, "expected persisted contacts width 160, got " .. tostring(persistedState.contactsWidth))
  end

  -- test_resize_grip_honors_layout_min_width_without_resizebounds_field

  do
    local frame = factory.CreateFrame("Frame", nil, parent)
    frame:SetSize(920, 580)
    frame.resizeBounds = nil
    local resizeGrip = factory.CreateFrame("Frame", nil, parent)

    local originalMinWidth = Theme.LAYOUT.WINDOW_MIN_WIDTH
    Theme.LAYOUT.WINDOW_MIN_WIDTH = 400

    local relayoutArgs = nil
    local refs = { frame = frame, resizeGrip = resizeGrip }
    local options = {
      refreshWindowAlpha = noop,
      relayout = function(w, h)
        relayoutArgs = { width = w, height = h }
      end,
      buildState = function(target)
        return { width = target.width, height = target.height }
      end,
      trace = noop,
      onPositionChanged = noop,
      Theme = Theme,
      getCursorX = function()
        return 300
      end,
      getCursorY = function()
        return 660
      end,
      getFrameLeft = function()
        return 100
      end,
      getFrameTop = function()
        return 760
      end,
    }

    WindowScripts.WireFrame(refs, options)

    resizeGrip.scripts.OnMouseDown(resizeGrip, "LeftButton")
    frame.scripts.OnUpdate(frame, Theme.WINDOW_ALPHA_UPDATE_INTERVAL)
    resizeGrip.scripts.OnMouseUp(resizeGrip, "LeftButton")

    Theme.LAYOUT.WINDOW_MIN_WIDTH = originalMinWidth

    assert(relayoutArgs ~= nil, "expected resize to commit when LAYOUT min is used")
    assert(relayoutArgs.width == 400, "expected committed width clamped to LAYOUT.WINDOW_MIN_WIDTH=400, got " .. tostring(relayoutArgs.width))
  end
end
