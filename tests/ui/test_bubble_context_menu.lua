local FakeUI = require("tests.helpers.fake_ui")
local ContextMenu = require("WhisperMessenger.UI.ChatBubble.ContextMenu")
local BubbleFrame = require("WhisperMessenger.UI.ChatBubble.BubbleFrame")
local Theme = require("WhisperMessenger.UI.Theme")

return function()
  local MENU_FRAME_NAME = "WhisperMessengerBubbleContextMenu"

  local savedEasyMenu = _G.EasyMenu
  local savedCreateFrame = _G.CreateFrame
  local savedUIParent = _G.UIParent
  local savedCopyToClipboard = _G.CopyToClipboard
  local savedClipboardNamespace = _G.C_Clipboard
  local savedMenuFrame = _G[MENU_FRAME_NAME]
  local savedDropdownInitialize = _G.UIDropDownMenu_Initialize
  local savedDropdownCreateInfo = _G.UIDropDownMenu_CreateInfo
  local savedDropdownAddButton = _G.UIDropDownMenu_AddButton
  local savedToggleDropDownMenu = _G.ToggleDropDownMenu
  local savedSecureCallFunction = _G.securecallfunction
  local savedStaticPopupShow = _G.StaticPopup_Show
  local savedStaticPopupDialogs = _G.StaticPopupDialogs

  -- test_open_returns_false_without_text
  do
    rawset(_G, "EasyMenu", function() end)
    local opened = ContextMenu.Open(nil)
    assert(opened == false, "context menu should not open without bubble text")
  end

  -- test_open_returns_false_with_empty_text
  do
    rawset(_G, "EasyMenu", function() end)
    local opened = ContextMenu.Open("")
    assert(opened == false, "context menu should not open when bubble text is empty")
  end

  -- test_open_returns_false_without_any_menu_api
  do
    rawset(_G, "EasyMenu", nil)
    _G.UIDropDownMenu_Initialize = nil
    _G.UIDropDownMenu_CreateInfo = nil
    _G.UIDropDownMenu_AddButton = nil
    _G.ToggleDropDownMenu = nil

    local opened = ContextMenu.Open("hello")
    assert(opened == false, "context menu should fail when no dropdown menu API is available")
  end

  -- test_open_returns_false_without_menu_frame_api
  do
    rawset(_G, "EasyMenu", function() end)
    rawset(_G, "CreateFrame", nil)
    _G.UIParent = nil

    local opened = ContextMenu.Open("hello")
    assert(opened == false, "context menu should fail when menu frame cannot be created")
  end

  -- test_open_uses_dropdown_fallback_when_easy_menu_missing
  do
    local factory = FakeUI.NewFactory()
    local uiParent = factory.CreateFrame("Frame", "UIParent", nil)
    local anchor = factory.CreateFrame("Frame", nil, uiParent)
    local menuEntry = nil
    local toggledWith = nil

    rawset(_G, "CreateFrame", factory.CreateFrame)
    _G.UIParent = uiParent
    rawset(_G, "EasyMenu", nil)
    _G[MENU_FRAME_NAME] = nil
    _G.UIDropDownMenu_Initialize = function(frame, initFunction)
      initFunction(frame, 1)
    end
    _G.UIDropDownMenu_CreateInfo = function()
      return {}
    end
    _G.UIDropDownMenu_AddButton = function(info, _level)
      menuEntry = info
    end
    _G.ToggleDropDownMenu = function(_level, _value, frame, dropdownAnchor, x, y)
      toggledWith = { frame = frame, anchor = dropdownAnchor, x = x, y = y }
    end

    local opened = ContextMenu.Open("fallback menu", anchor)
    assert(opened == true, "context menu should open through dropdown fallback APIs")
    assert(menuEntry ~= nil and type(menuEntry.text) == "string", "fallback dropdown should provide a text label")
    assert(string.find(menuEntry.text, "Copy Text", 1, true) ~= nil, "fallback dropdown should include Copy Text label")
    assert(type(menuEntry.func) == "function", "fallback dropdown should include callable copy handler")
    assert(toggledWith ~= nil, "fallback dropdown should toggle menu visibility")
    assert(toggledWith.anchor == anchor, "fallback dropdown should anchor to the provided frame")
  end

  -- test_open_invokes_easy_menu_and_copy_action
  do
    local factory = FakeUI.NewFactory()
    local uiParent = factory.CreateFrame("Frame", "UIParent", nil)
    local anchor = factory.CreateFrame("Frame", nil, uiParent)

    local easyMenuCall = nil
    local copiedText = nil
    local protectedCallAttempted = false

    rawset(_G, "CreateFrame", factory.CreateFrame)
    _G.UIParent = uiParent
    rawset(_G, "CopyToClipboard", function()
      protectedCallAttempted = true
      error("forbidden")
    end)
    _G.C_Clipboard = {
      SetClipboard = function(text)
        copiedText = text
      end,
    }
    _G[MENU_FRAME_NAME] = nil

    rawset(_G, "EasyMenu", function(menuList, menuFrame, menuAnchor, x, y, displayMode)
      easyMenuCall = {
        menuList = menuList,
        menuFrame = menuFrame,
        menuAnchor = menuAnchor,
        x = x,
        y = y,
        displayMode = displayMode,
      }
    end)

    local opened = ContextMenu.Open("bubble text", anchor)

    assert(opened == true, "context menu should open when EasyMenu is available")
    assert(easyMenuCall ~= nil, "EasyMenu should be called")
    assert(easyMenuCall.menuAnchor == anchor, "menu should anchor to the provided frame")
    assert(easyMenuCall.displayMode == "MENU", "menu should use context MENU display mode")
    assert(type(easyMenuCall.menuList) == "table", "menu list should be a table")
    assert(easyMenuCall.menuList[1] ~= nil, "menu should include first entry")
    assert(type(easyMenuCall.menuList[1].text) == "string", "menu entry text should be a string")
    assert(
      string.find(easyMenuCall.menuList[1].text, "Copy Text", 1, true) ~= nil,
      "menu should expose Copy Text action"
    )
    assert(type(easyMenuCall.menuList[1].func) == "function", "Copy Text entry should be callable")

    easyMenuCall.menuList[1].func()
    assert(copiedText == "bubble text", "Copy Text action should copy the selected bubble text")
    assert(protectedCallAttempted == false, "Copy Text should not call protected CopyToClipboard in addon code")
  end

  -- test_copy_text_uses_clipboard_namespace_fallback
  do
    local copiedText = nil
    rawset(_G, "CopyToClipboard", nil)
    _G.C_Clipboard = {
      SetClipboard = function(text)
        copiedText = text
      end,
    }

    local copied = ContextMenu.CopyText("fallback")
    assert(copied == true, "CopyText should return true when C_Clipboard.SetClipboard is available")
    assert(copiedText == "fallback", "CopyText should pass text to C_Clipboard.SetClipboard")
  end

  -- test_copy_text_supports_alternate_clipboard_method_names
  do
    local copiedText = nil
    rawset(_G, "CopyToClipboard", nil)
    _G.C_Clipboard = {
      SetClipboardText = function(text)
        copiedText = text
      end,
    }

    local copied = ContextMenu.CopyText("alternate")
    assert(copied == true, "CopyText should support C_Clipboard alternate setter names")
    assert(copiedText == "alternate", "alternate clipboard method should receive copied text")
  end

  -- test_copy_text_uses_manual_popup_when_clipboard_unavailable
  do
    local protectedCallAttempted = false
    local shown = nil

    rawset(_G, "CopyToClipboard", function()
      protectedCallAttempted = true
      return 7
    end)
    _G.C_Clipboard = nil
    _G.securecallfunction = function(fn, ...)
      return fn(...)
    end
    _G.StaticPopupDialogs = {}
    rawset(_G, "StaticPopup_Show", function(which, _textArg1, _textArg2, data)
      shown = { which = which, data = data }
      return {}
    end)

    local copied = ContextMenu.CopyText("manual")
    assert(copied == true, "CopyText should show manual-copy popup when clipboard APIs are unavailable")
    assert(protectedCallAttempted == false, "CopyText should never call protected CopyToClipboard from addon code")
    assert(shown ~= nil, "CopyText should open a manual copy popup")
    assert(shown.data == "manual", "manual copy popup should receive the original text")
  end

  -- test_copy_text_falls_back_to_manual_popup_when_clipboard_method_errors
  do
    local shown = nil
    rawset(_G, "CopyToClipboard", nil)
    _G.C_Clipboard = {
      SetClipboard = function()
        error("blocked")
      end,
    }
    _G.StaticPopupDialogs = {}
    rawset(_G, "StaticPopup_Show", function(which, _textArg1, _textArg2, data)
      shown = { which = which, data = data }
      return {}
    end)

    local copied = ContextMenu.CopyText("recover")
    assert(copied == true, "CopyText should fall back to manual popup when clipboard methods error")
    assert(shown ~= nil and shown.data == "recover", "manual popup fallback should receive copied text")
  end

  -- test_manual_popup_uses_dialog_data_when_onshow_data_arg_missing
  do
    local popupText = nil
    rawset(_G, "CopyToClipboard", nil)
    _G.C_Clipboard = nil
    _G.StaticPopupDialogs = {}
    rawset(_G, "StaticPopup_Show", function(which, _textArg1, _textArg2, data)
      local def = _G.StaticPopupDialogs[which]
      local dialog = {
        data = data,
        editBox = {
          SetText = function(_self, value)
            popupText = value
          end,
          HighlightText = function() end,
          SetFocus = function() end,
        },
      }
      if def and def.OnShow then
        def.OnShow(dialog)
      end
      return {}
    end)

    local copied = ContextMenu.CopyText("from-data")
    assert(copied == true, "CopyText should still open manual popup when only dialog data is available")
    assert(popupText == "from-data", "popup should read text from dialog data when OnShow data arg is missing")
  end

  -- test_manual_popup_supports_capitalized_editbox_field
  do
    local popupText = nil
    rawset(_G, "CopyToClipboard", nil)
    _G.C_Clipboard = nil
    _G.StaticPopupDialogs = {}
    rawset(_G, "StaticPopup_Show", function(which, _textArg1, _textArg2, data)
      local def = _G.StaticPopupDialogs[which]
      local dialog = {
        data = data,
        EditBox = {
          SetText = function(_self, value)
            popupText = value
          end,
          HighlightText = function() end,
          SetFocus = function() end,
        },
      }
      if def and def.OnShow then
        def.OnShow(dialog)
      end
      return dialog
    end)

    local copied = ContextMenu.CopyText("from-EditBox")
    assert(copied == true, "CopyText should open manual popup with alternate editbox field")
    assert(popupText == "from-EditBox", "manual popup should prefill text when dialog exposes EditBox")
  end

  -- test_manual_popup_supports_editbox_as_child_only
  do
    local popupText = nil
    rawset(_G, "CopyToClipboard", nil)
    _G.C_Clipboard = nil
    _G.StaticPopupDialogs = {}
    rawset(_G, "StaticPopup_Show", function(which, _textArg1, _textArg2, data)
      local def = _G.StaticPopupDialogs[which]
      local childEditBox = {
        SetText = function(_self, value)
          popupText = value
        end,
        HighlightText = function() end,
        SetFocus = function() end,
      }
      local dialog = {
        data = data,
        GetChildren = function()
          return childEditBox
        end,
      }
      if def and def.OnShow then
        def.OnShow(dialog)
      end
      return dialog
    end)

    local copied = ContextMenu.CopyText("from-child")
    assert(copied == true, "CopyText should open manual popup when editbox is only discoverable through children")
    assert(popupText == "from-child", "manual popup should prefill text when editbox is exposed via GetChildren")
  end

  -- test_manual_popup_prefers_real_editbox_when_child_order_mixed
  do
    local popupText = nil
    rawset(_G, "CopyToClipboard", nil)
    _G.C_Clipboard = nil
    _G.StaticPopupDialogs = {}
    rawset(_G, "StaticPopup_Show", function(which, _textArg1, _textArg2, data)
      local def = _G.StaticPopupDialogs[which]
      local buttonLikeChild = {
        SetText = function() end,
      }
      local editBoxChild = {
        SetText = function(_self, value)
          popupText = value
        end,
        HighlightText = function() end,
        SetFocus = function() end,
        GetObjectType = function()
          return "EditBox"
        end,
      }
      local dialog = {
        data = data,
        GetChildren = function()
          return buttonLikeChild, editBoxChild
        end,
      }
      if def and def.OnShow then
        def.OnShow(dialog)
      end
      return dialog
    end)

    local copied = ContextMenu.CopyText("ordered")
    assert(copied == true, "CopyText should open manual popup when mixed child types are present")
    assert(popupText == "ordered", "CopyText should target editbox child even when it is not the first child")
  end

  -- test_manual_popup_styles_are_scoped_and_restored_on_reuse
  do
    local factory = FakeUI.NewFactory()
    local uiParent = factory.CreateFrame("Frame", "UIParent", nil)
    local dialog = factory.CreateFrame("Frame", "StaticPopup1", uiParent)
    local dialogText = dialog:CreateFontString(nil, "OVERLAY")
    local editBox = factory.CreateFrame("EditBox", "StaticPopup1EditBox", dialog)
    local button1 = factory.CreateFrame("Button", "StaticPopup1Button1", dialog)
    local buttonLabel = button1:CreateFontString(nil, "OVERLAY")
    local editBoxDecoration = editBox:CreateTexture(nil, "ARTWORK")
    editBoxDecoration:SetAllPoints(editBox)
    editBoxDecoration:Show()
    local buttonDecoration = button1:CreateTexture(nil, "ARTWORK")
    buttonDecoration:SetAllPoints(button1)
    buttonDecoration:Show()
    local originalButtonTextColor = { 0.7, 0.71, 0.73, 1 }
    dialog.text = dialogText
    dialog.editBox = editBox
    dialog.button1 = button1
    button1.text = buttonLabel
    buttonLabel:SetText("OK")
    buttonLabel:SetTextColor(
      originalButtonTextColor[1],
      originalButtonTextColor[2],
      originalButtonTextColor[3],
      originalButtonTextColor[4]
    )
    _G.StaticPopup1 = dialog
    _G.StaticPopup1EditBox = editBox
    _G.StaticPopup1Button1 = button1
    rawset(_G, "CreateFrame", factory.CreateFrame)
    _G.UIParent = uiParent
    rawset(_G, "CopyToClipboard", nil)
    _G.C_Clipboard = nil
    _G.StaticPopupDialogs = {
      WM_TEST_GENERIC_DIALOG = {
        text = "Generic dialog",
        button1 = "Logout",
      },
    }
    rawset(_G, "StaticPopup_Show", function(which, _textArg1, _textArg2, data)
      local def = _G.StaticPopupDialogs[which]
      dialog.which = which
      dialog.data = data
      dialog:Show()
      if def and def.OnShow then
        def.OnShow(dialog, data)
      end
      return dialog
    end)

    local copied = ContextMenu.CopyText("styled")
    assert(copied == true, "CopyText should open manual popup when clipboard APIs are unavailable")
    assert(dialog._wmRoundedBackground ~= nil, "manual popup should create dialog background styling")
    assert(
      dialog._wmRoundedBackground.fills[1].shown == true,
      "manual popup dialog background should be active while shown"
    )
    assert(editBox._wmManualCopyBorder ~= nil, "manual popup should add a bordered input style")
    assert(editBox._wmManualCopyBorder.top.shown == true, "manual popup input border should be active while shown")
    assert(button1._wmManualCopySkin ~= nil, "manual popup should style the OK button")
    assert(button1._wmManualCopySkin.fills[1].shown == true, "manual popup button skin should be active while shown")
    assert(editBoxDecoration.shown == false, "manual popup should hide default edit box decoration textures")
    assert(buttonDecoration.shown == false, "manual popup should hide default button decoration textures")
    assert(buttonLabel.textColor ~= nil, "manual popup should recolor the OK button label")
    assert(
      buttonLabel.textColor[1] == Theme.COLORS.option_button_text[1]
        and buttonLabel.textColor[2] == Theme.COLORS.option_button_text[2]
        and buttonLabel.textColor[3] == Theme.COLORS.option_button_text[3],
      "manual popup should use settings-style OK button text colors"
    )

    local manualDef = _G.StaticPopupDialogs["WHISPER_MESSENGER_BUBBLE_COPY_TEXT"]
    assert(
      manualDef ~= nil and type(manualDef.OnHide) == "function",
      "manual popup definition should expose OnHide cleanup"
    )
    manualDef.OnHide(dialog)
    dialog:Hide()

    assert(
      dialog._wmRoundedBackground.fills[1].shown == false,
      "manual popup dialog styling should be hidden after close"
    )
    assert(editBox._wmManualCopyBorder.top.shown == false, "manual popup input border should be hidden after close")
    assert(button1._wmManualCopySkin.fills[1].shown == false, "manual popup button skin should be hidden after close")
    assert(
      editBoxDecoration.shown == true,
      "manual popup should restore default edit box decoration textures after close"
    )
    assert(buttonDecoration.shown == true, "manual popup should restore default button decoration textures after close")
    assert(
      buttonLabel.textColor[1] == originalButtonTextColor[1]
        and buttonLabel.textColor[2] == originalButtonTextColor[2]
        and buttonLabel.textColor[3] == originalButtonTextColor[3],
      "manual popup should restore the original OK button text color after close"
    )

    local reusedDialog = _G.StaticPopup_Show("WM_TEST_GENERIC_DIALOG")
    assert(reusedDialog == dialog, "test should reuse the same StaticPopup frame")
    assert(
      dialog._wmRoundedBackground.fills[1].shown == false,
      "manual popup dialog styling should stay inactive for reused generic popups"
    )
    assert(
      editBox._wmManualCopyBorder.top.shown == false,
      "manual popup input border should stay inactive for reused generic popups"
    )
    assert(
      button1._wmManualCopySkin.fills[1].shown == false,
      "manual popup button styling should stay inactive for reused generic popups"
    )

    local genericDialogFont = {
      name = "GenericPopupFont",
      GetFont = function()
        return "Fonts\\FRIZQT__.TTF", 12, ""
      end,
    }
    local genericEditFont = {
      name = "GenericPopupEditFont",
      GetFont = function()
        return "Fonts\\ARIALN.TTF", 12, ""
      end,
    }
    dialogText:SetFontObject(genericDialogFont)
    dialogText:SetTextColor(0.92, 0.41, 0.36, 1)
    editBox:SetFontObject(genericEditFont)
    editBox:SetTextColor(0.24, 0.82, 0.54, 1)
    editBox:SetTextInsets(3, 4, 5, 6)
    buttonLabel:SetTextColor(0.31, 0.55, 0.94, 1)

    local genericLeaveCount = 0
    local genericOnEnter = function(self)
      self.genericHoverActive = true
    end
    local genericOnLeave = function(self)
      self.genericHoverActive = false
      genericLeaveCount = genericLeaveCount + 1
    end
    button1.genericHoverActive = false
    button1:SetScript("OnEnter", genericOnEnter)
    button1:SetScript("OnLeave", genericOnLeave)

    local reopened = ContextMenu.CopyText("styled-again")
    assert(reopened == true, "CopyText should support repeated opens on the same StaticPopup frame")
    assert(
      button1:GetScript("OnEnter") ~= genericOnEnter,
      "manual popup should install a fresh hover OnEnter handler for each session"
    )
    assert(
      button1:GetScript("OnLeave") ~= genericOnLeave,
      "manual popup should install a fresh hover OnLeave handler for each session"
    )

    manualDef.OnHide(dialog)
    dialog:Hide()
    assert(
      genericLeaveCount == 0,
      "manual popup cleanup should not fire generic OnLeave when the popup was never hovered"
    )

    local reopenedAfterHover = ContextMenu.CopyText("styled-third")
    assert(reopenedAfterHover == true, "CopyText should support a third open on the same StaticPopup frame")
    assert(
      button1:GetScript("OnEnter") ~= genericOnEnter,
      "manual popup should keep installing wrapped hover handlers after repeated reuse"
    )
    assert(
      button1:GetScript("OnLeave") ~= genericOnLeave,
      "manual popup should keep installing wrapped leave handlers after repeated reuse"
    )
    button1:GetScript("OnEnter")(button1)
    assert(
      button1._wmManualCopyHovered == true,
      "manual popup hover handler should still update button state after reused-frame script changes"
    )
    button1:GetScript("OnLeave")(button1)
    assert(button1._wmManualCopyHovered == false, "manual popup leave handler should clear manual hover state")
    assert(
      genericLeaveCount == 1,
      "manual popup leave handler should delegate to generic OnLeave exactly once during hover exit"
    )

    manualDef.OnHide(dialog)
    dialog:Hide()

    assert(
      dialogText.fontObject == genericDialogFont,
      "manual popup should restore dialog font object for reused frames"
    )
    assert(
      dialogText.textColor[1] == 0.92 and dialogText.textColor[2] == 0.41 and dialogText.textColor[3] == 0.36,
      "manual popup should restore dialog text color for reused frames"
    )
    assert(editBox.fontObject == genericEditFont, "manual popup should restore edit box font object for reused frames")
    assert(
      editBox.textColor[1] == 0.24 and editBox.textColor[2] == 0.82 and editBox.textColor[3] == 0.54,
      "manual popup should restore edit box text color for reused frames"
    )
    assert(
      editBox.textInsets[1] == 3
        and editBox.textInsets[2] == 4
        and editBox.textInsets[3] == 5
        and editBox.textInsets[4] == 6,
      "manual popup should restore edit box text insets for reused frames"
    )
    assert(
      buttonLabel.textColor[1] == 0.31 and buttonLabel.textColor[2] == 0.55 and buttonLabel.textColor[3] == 0.94,
      "manual popup should restore button label color from the most recent non-manual styling"
    )
    assert(
      button1.genericHoverActive == false,
      "manual popup cleanup should clear generic hover side effects before frame reuse"
    )
    assert(
      genericLeaveCount == 1,
      "manual popup cleanup should not double-fire generic OnLeave after the hover already ended"
    )
    assert(
      button1:GetScript("OnEnter") == genericOnEnter,
      "manual popup should restore button OnEnter handler for reused frames"
    )
    assert(
      button1:GetScript("OnLeave") == genericOnLeave,
      "manual popup should restore button OnLeave handler for reused frames"
    )

    local recursiveLeaveCalls = 0
    local recursiveOnLeave = function()
      recursiveLeaveCalls = recursiveLeaveCalls + 1
      if recursiveLeaveCalls > 1 then
        error("recursive OnLeave teardown")
      end
      manualDef.OnHide(dialog)
    end
    button1:SetScript("OnLeave", recursiveOnLeave)

    local reopenedRecursive = ContextMenu.CopyText("styled-recursive")
    assert(reopenedRecursive == true, "CopyText should support reopen before recursive-teardown check")
    button1:GetScript("OnEnter")(button1)
    assert(button1:GetScript("OnLeave") ~= recursiveOnLeave, "recursive test should execute wrapped OnLeave")
    local safeCloseOk, safeCloseErr = pcall(function()
      button1:GetScript("OnLeave")(button1)
    end)
    assert(
      safeCloseOk == true,
      "manual popup close should not recurse when original OnLeave re-enters OnHide: " .. tostring(safeCloseErr)
    )
    assert(recursiveLeaveCalls <= 1, "manual popup teardown should invoke original OnLeave at most once")
    dialog:Hide()

    local originalGetFontObject = editBox.GetFontObject
    local originalSetFontObject = editBox.SetFontObject
    editBox.GetFontObject = function()
      return editBox
    end
    rawset(editBox, "SetFontObject", function()
      error("unexpected SetFontObject")
    end)

    local reopenedFontGuard = ContextMenu.CopyText("styled-font-guard")
    assert(reopenedFontGuard == true, "CopyText should support reopen before font-restore guard check")
    local fontCloseOk, fontCloseErr = pcall(function()
      manualDef.OnHide(dialog)
    end)
    assert(
      fontCloseOk == true,
      "manual popup should not call edit box SetFontObject during open/close: " .. tostring(fontCloseErr)
    )
    dialog:Hide()
    editBox.GetFontObject = originalGetFontObject
    rawset(editBox, "SetFontObject", originalSetFontObject)
  end

  -- test_bubble_frame_right_click_opens_context_menu
  do
    local factory = FakeUI.NewFactory()
    local parent = factory.CreateFrame("Frame", nil, nil)
    parent:SetSize(400, 600)

    local openedWithText = nil
    local openedWithAnchor = nil
    local openCount = 0
    local originalOpen = ContextMenu.Open
    rawset(ContextMenu, "Open", function(text, anchorFrame)
      openedWithText = text
      openedWithAnchor = anchorFrame
      openCount = openCount + 1
      return true
    end)

    local bubble = BubbleFrame.CreateBubble(factory, parent, {
      direction = "in",
      kind = "user",
      text = "right click me",
      sentAt = 1000,
      playerName = "Arthas",
    }, {
      paneWidth = 400,
      showIcon = false,
    })

    assert(type(bubble.frame.scripts.OnMouseDown) == "function", "bubble frame should wire an OnMouseDown script")
    assert(type(bubble.frame.scripts.OnMouseUp) == "function", "bubble frame should wire an OnMouseUp script")

    bubble.frame.scripts.OnMouseDown(bubble.frame, "LeftButton")
    bubble.frame.scripts.OnMouseUp(bubble.frame, "LeftButton")
    assert(openCount == 0, "left click should not open the bubble context menu")

    bubble.frame.scripts.OnMouseDown(bubble.frame, "RightButton")
    bubble.frame.scripts.OnMouseUp(bubble.frame, "RightButton")
    assert(openCount == 1, "right click down/up should open the menu only once")
    assert(openedWithText == "right click me", "right click should open menu with current bubble text")
    assert(openedWithAnchor == bubble.frame, "right click should anchor menu to bubble frame")

    bubble.frame.scripts.OnMouseUp(bubble.frame, "RightButton")
    assert(openCount == 2, "mouse-up-only right click should still open the menu")

    rawset(ContextMenu, "Open", originalOpen)
  end

  rawset(_G, "EasyMenu", savedEasyMenu)
  rawset(_G, "CreateFrame", savedCreateFrame)
  _G.UIParent = savedUIParent
  rawset(_G, "CopyToClipboard", savedCopyToClipboard)
  _G.C_Clipboard = savedClipboardNamespace
  _G[MENU_FRAME_NAME] = savedMenuFrame
  _G.UIDropDownMenu_Initialize = savedDropdownInitialize
  _G.UIDropDownMenu_CreateInfo = savedDropdownCreateInfo
  _G.UIDropDownMenu_AddButton = savedDropdownAddButton
  _G.ToggleDropDownMenu = savedToggleDropDownMenu
  _G.securecallfunction = savedSecureCallFunction
  rawset(_G, "StaticPopup_Show", savedStaticPopupShow)
  _G.StaticPopupDialogs = savedStaticPopupDialogs
end
