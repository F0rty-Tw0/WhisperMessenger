local FakeUI = require("tests.helpers.fake_ui")
local ContextMenu = require("WhisperMessenger.UI.ChatBubble.ContextMenu")
local BubbleFrame = require("WhisperMessenger.UI.ChatBubble.BubbleFrame")

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
    _G.EasyMenu = function() end
    local opened = ContextMenu.Open(nil)
    assert(opened == false, "context menu should not open without bubble text")
  end

  -- test_open_returns_false_with_empty_text
  do
    _G.EasyMenu = function() end
    local opened = ContextMenu.Open("")
    assert(opened == false, "context menu should not open when bubble text is empty")
  end

  -- test_open_returns_false_without_any_menu_api
  do
    _G.EasyMenu = nil
    _G.UIDropDownMenu_Initialize = nil
    _G.UIDropDownMenu_CreateInfo = nil
    _G.UIDropDownMenu_AddButton = nil
    _G.ToggleDropDownMenu = nil

    local opened = ContextMenu.Open("hello")
    assert(opened == false, "context menu should fail when no dropdown menu API is available")
  end

  -- test_open_returns_false_without_menu_frame_api
  do
    _G.EasyMenu = function() end
    _G.CreateFrame = nil
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

    _G.CreateFrame = factory.CreateFrame
    _G.UIParent = uiParent
    _G.EasyMenu = nil
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

    _G.CreateFrame = factory.CreateFrame
    _G.UIParent = uiParent
    _G.CopyToClipboard = function()
      protectedCallAttempted = true
      error("forbidden")
    end
    _G.C_Clipboard = {
      SetClipboard = function(text)
        copiedText = text
      end,
    }
    _G[MENU_FRAME_NAME] = nil

    _G.EasyMenu = function(menuList, menuFrame, menuAnchor, x, y, displayMode)
      easyMenuCall = {
        menuList = menuList,
        menuFrame = menuFrame,
        menuAnchor = menuAnchor,
        x = x,
        y = y,
        displayMode = displayMode,
      }
    end

    local opened = ContextMenu.Open("bubble text", anchor)

    assert(opened == true, "context menu should open when EasyMenu is available")
    assert(easyMenuCall ~= nil, "EasyMenu should be called")
    assert(easyMenuCall.menuAnchor == anchor, "menu should anchor to the provided frame")
    assert(easyMenuCall.displayMode == "MENU", "menu should use context MENU display mode")
    assert(type(easyMenuCall.menuList) == "table", "menu list should be a table")
    assert(easyMenuCall.menuList[1] ~= nil, "menu should include first entry")
    assert(type(easyMenuCall.menuList[1].text) == "string", "menu entry text should be a string")
    assert(string.find(easyMenuCall.menuList[1].text, "Copy Text", 1, true) ~= nil, "menu should expose Copy Text action")
    assert(type(easyMenuCall.menuList[1].func) == "function", "Copy Text entry should be callable")

    easyMenuCall.menuList[1].func()
    assert(copiedText == "bubble text", "Copy Text action should copy the selected bubble text")
    assert(protectedCallAttempted == false, "Copy Text should not call protected CopyToClipboard in addon code")
  end

  -- test_copy_text_uses_clipboard_namespace_fallback
  do
    local copiedText = nil
    _G.CopyToClipboard = nil
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
    _G.CopyToClipboard = nil
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

    _G.CopyToClipboard = function()
      protectedCallAttempted = true
      return 7
    end
    _G.C_Clipboard = nil
    _G.securecallfunction = function(fn, ...)
      return fn(...)
    end
    _G.StaticPopupDialogs = {}
    _G.StaticPopup_Show = function(which, _textArg1, _textArg2, data)
      shown = { which = which, data = data }
      return {}
    end

    local copied = ContextMenu.CopyText("manual")
    assert(copied == true, "CopyText should show manual-copy popup when clipboard APIs are unavailable")
    assert(protectedCallAttempted == false, "CopyText should never call protected CopyToClipboard from addon code")
    assert(shown ~= nil, "CopyText should open a manual copy popup")
    assert(shown.data == "manual", "manual copy popup should receive the original text")
  end

  -- test_copy_text_falls_back_to_manual_popup_when_clipboard_method_errors
  do
    local shown = nil
    _G.CopyToClipboard = nil
    _G.C_Clipboard = {
      SetClipboard = function()
        error("blocked")
      end,
    }
    _G.StaticPopupDialogs = {}
    _G.StaticPopup_Show = function(which, _textArg1, _textArg2, data)
      shown = { which = which, data = data }
      return {}
    end

    local copied = ContextMenu.CopyText("recover")
    assert(copied == true, "CopyText should fall back to manual popup when clipboard methods error")
    assert(shown ~= nil and shown.data == "recover", "manual popup fallback should receive copied text")
  end

  -- test_manual_popup_uses_dialog_data_when_onshow_data_arg_missing
  do
    local popupText = nil
    _G.CopyToClipboard = nil
    _G.C_Clipboard = nil
    _G.StaticPopupDialogs = {}
    _G.StaticPopup_Show = function(which, _textArg1, _textArg2, data)
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
    end

    local copied = ContextMenu.CopyText("from-data")
    assert(copied == true, "CopyText should still open manual popup when only dialog data is available")
    assert(popupText == "from-data", "popup should read text from dialog data when OnShow data arg is missing")
  end

  -- test_manual_popup_supports_capitalized_editbox_field
  do
    local popupText = nil
    _G.CopyToClipboard = nil
    _G.C_Clipboard = nil
    _G.StaticPopupDialogs = {}
    _G.StaticPopup_Show = function(which, _textArg1, _textArg2, data)
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
    end

    local copied = ContextMenu.CopyText("from-EditBox")
    assert(copied == true, "CopyText should open manual popup with alternate editbox field")
    assert(popupText == "from-EditBox", "manual popup should prefill text when dialog exposes EditBox")
  end

  -- test_manual_popup_supports_editbox_as_child_only
  do
    local popupText = nil
    _G.CopyToClipboard = nil
    _G.C_Clipboard = nil
    _G.StaticPopupDialogs = {}
    _G.StaticPopup_Show = function(which, _textArg1, _textArg2, data)
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
    end

    local copied = ContextMenu.CopyText("from-child")
    assert(copied == true, "CopyText should open manual popup when editbox is only discoverable through children")
    assert(popupText == "from-child", "manual popup should prefill text when editbox is exposed via GetChildren")
  end

  -- test_manual_popup_prefers_real_editbox_when_child_order_mixed
  do
    local popupText = nil
    _G.CopyToClipboard = nil
    _G.C_Clipboard = nil
    _G.StaticPopupDialogs = {}
    _G.StaticPopup_Show = function(which, _textArg1, _textArg2, data)
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
    end

    local copied = ContextMenu.CopyText("ordered")
    assert(copied == true, "CopyText should open manual popup when mixed child types are present")
    assert(popupText == "ordered", "CopyText should target editbox child even when it is not the first child")
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
    ContextMenu.Open = function(text, anchorFrame)
      openedWithText = text
      openedWithAnchor = anchorFrame
      openCount = openCount + 1
      return true
    end

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

    ContextMenu.Open = originalOpen
  end

  _G.EasyMenu = savedEasyMenu
  _G.CreateFrame = savedCreateFrame
  _G.UIParent = savedUIParent
  _G.CopyToClipboard = savedCopyToClipboard
  _G.C_Clipboard = savedClipboardNamespace
  _G[MENU_FRAME_NAME] = savedMenuFrame
  _G.UIDropDownMenu_Initialize = savedDropdownInitialize
  _G.UIDropDownMenu_CreateInfo = savedDropdownCreateInfo
  _G.UIDropDownMenu_AddButton = savedDropdownAddButton
  _G.ToggleDropDownMenu = savedToggleDropDownMenu
  _G.securecallfunction = savedSecureCallFunction
  _G.StaticPopup_Show = savedStaticPopupShow
  _G.StaticPopupDialogs = savedStaticPopupDialogs
end
