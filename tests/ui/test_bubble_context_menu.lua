-- Tests for ContextMenu.lua orchestrator: open guards, EasyMenu / dropdown
-- fallback, and the bubble-frame right-click integration.
--
-- Clipboard fan-out and PopupUI styling live in test_bubble_manual_copy.lua;
-- the assertions here only check what ContextMenu itself does.

local FakeUI = require("tests.helpers.fake_ui")
local ContextMenu = require("WhisperMessenger.UI.ChatBubble.ContextMenu")
local BubbleFrame = require("WhisperMessenger.UI.ChatBubble.BubbleFrame")

local MENU_FRAME_NAME = "WhisperMessengerBubbleContextMenu"

local function snapshotGlobals()
  return {
    EasyMenu = _G.EasyMenu,
    CreateFrame = _G.CreateFrame,
    UIParent = _G.UIParent,
    CopyToClipboard = _G.CopyToClipboard,
    C_Clipboard = _G.C_Clipboard,
    menuFrame = _G[MENU_FRAME_NAME],
    UIDropDownMenu_Initialize = _G.UIDropDownMenu_Initialize,
    UIDropDownMenu_CreateInfo = _G.UIDropDownMenu_CreateInfo,
    UIDropDownMenu_AddButton = _G.UIDropDownMenu_AddButton,
    ToggleDropDownMenu = _G.ToggleDropDownMenu,
    UIDropDownMenuTemplate = _G.UIDropDownMenuTemplate,
  }
end

local function restoreGlobals(saved)
  rawset(_G, "EasyMenu", saved.EasyMenu)
  rawset(_G, "CreateFrame", saved.CreateFrame)
  _G.UIParent = saved.UIParent
  rawset(_G, "CopyToClipboard", saved.CopyToClipboard)
  _G.C_Clipboard = saved.C_Clipboard
  _G[MENU_FRAME_NAME] = saved.menuFrame
  _G.UIDropDownMenu_Initialize = saved.UIDropDownMenu_Initialize
  _G.UIDropDownMenu_CreateInfo = saved.UIDropDownMenu_CreateInfo
  _G.UIDropDownMenu_AddButton = saved.UIDropDownMenu_AddButton
  _G.ToggleDropDownMenu = saved.ToggleDropDownMenu
  _G.UIDropDownMenuTemplate = saved.UIDropDownMenuTemplate
end

local function clearMenuApis()
  rawset(_G, "EasyMenu", nil)
  _G.UIDropDownMenu_Initialize = nil
  _G.UIDropDownMenu_CreateInfo = nil
  _G.UIDropDownMenu_AddButton = nil
  _G.ToggleDropDownMenu = nil
end

return function()
  local saved = snapshotGlobals()

  -- Open returns false for nil/empty text (no menu API call should happen).
  do
    rawset(_G, "EasyMenu", function()
      error("must not invoke EasyMenu without text")
    end)
    assert(ContextMenu.Open(nil) == false, "Open(nil) should refuse to open the menu")
    assert(ContextMenu.Open("") == false, "Open('') should refuse to open the menu")
  end

  -- Open returns false when neither EasyMenu nor the dropdown API is available.
  do
    clearMenuApis()
    assert(ContextMenu.Open("hello") == false, "Open should fail when no menu API exists")
  end

  -- Open returns false when the menu frame can't be created (no CreateFrame /
  -- UIParent stand-ins available).
  do
    rawset(_G, "EasyMenu", function() end)
    rawset(_G, "CreateFrame", nil)
    _G.UIParent = nil
    assert(ContextMenu.Open("hello") == false, "Open should fail when no menu frame can be created")
  end

  -- When the UIDropDownMenuTemplate is missing (Retail 10.0+), Open should
  -- gracefully fall through to CopyText - the user still gets the text.
  do
    local factory = FakeUI.NewFactory()
    local uiParent = factory.CreateFrame("Frame", "UIParent", nil)
    _G.UIParent = uiParent
    _G[MENU_FRAME_NAME] = nil
    _G.UIDropDownMenuTemplate = nil
    rawset(_G, "CreateFrame", function(frameType, name, parent, template)
      if template == "UIDropDownMenuTemplate" then
        error('Unknown template "UIDropDownMenuTemplate"')
      end
      return factory.CreateFrame(frameType, name, parent, template)
    end)
    clearMenuApis()
    rawset(_G, "CopyToClipboard", nil)
    _G.C_Clipboard = { SetClipboard = function() end }

    local ok, opened = pcall(ContextMenu.Open, "fallback", nil)
    assert(ok, "Open must not throw when UIDropDownMenuTemplate is missing")
    assert(opened == true, "Open should fall back to CopyText when template missing")
  end

  -- EasyMenu happy path: Open invokes EasyMenu with a Copy Text entry whose
  -- callback routes through ContextMenu.CopyText (without touching the
  -- protected CopyToClipboard global).
  do
    local factory = FakeUI.NewFactory()
    local uiParent = factory.CreateFrame("Frame", "UIParent", nil)
    local anchor = factory.CreateFrame("Frame", nil, uiParent)
    rawset(_G, "CreateFrame", factory.CreateFrame)
    _G.UIParent = uiParent
    _G[MENU_FRAME_NAME] = nil

    local protectedAttempted = false
    rawset(_G, "CopyToClipboard", function()
      protectedAttempted = true
      error("forbidden")
    end)
    local copiedText = nil
    _G.C_Clipboard = {
      SetClipboard = function(text)
        copiedText = text
      end,
    }

    local easyMenuCall
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

    assert(ContextMenu.Open("bubble text", anchor) == true, "Open should succeed via EasyMenu")
    assert(easyMenuCall ~= nil, "EasyMenu should be invoked")
    assert(easyMenuCall.menuAnchor == anchor, "menu should anchor to the supplied frame")
    assert(easyMenuCall.displayMode == "MENU", "menu should use MENU display mode")
    local entry = easyMenuCall.menuList[1]
    assert(entry and string.find(entry.text, "Copy Text", 1, true), "menu should expose Copy Text label")
    assert(type(entry.func) == "function", "Copy Text entry should be callable")

    entry.func()
    assert(copiedText == "bubble text", "Copy Text callback should copy via C_Clipboard")
    assert(protectedAttempted == false, "Copy Text must not call protected CopyToClipboard")
  end

  -- When EasyMenu is absent, Open uses the legacy dropdown API instead.
  do
    local factory = FakeUI.NewFactory()
    local uiParent = factory.CreateFrame("Frame", "UIParent", nil)
    local anchor = factory.CreateFrame("Frame", nil, uiParent)
    rawset(_G, "CreateFrame", factory.CreateFrame)
    _G.UIParent = uiParent
    _G[MENU_FRAME_NAME] = nil
    rawset(_G, "EasyMenu", nil)

    local entry, toggled
    _G.UIDropDownMenu_Initialize = function(frame, init)
      init(frame, 1)
    end
    _G.UIDropDownMenu_CreateInfo = function()
      return {}
    end
    _G.UIDropDownMenu_AddButton = function(info)
      entry = info
    end
    _G.ToggleDropDownMenu = function(_level, _value, frame, dropdownAnchor, x, y)
      toggled = { frame = frame, anchor = dropdownAnchor, x = x, y = y }
    end

    assert(ContextMenu.Open("fallback menu", anchor) == true, "Open should succeed via dropdown fallback")
    assert(entry and string.find(entry.text, "Copy Text", 1, true), "fallback should add Copy Text entry")
    assert(type(entry.func) == "function", "fallback Copy Text entry should be callable")
    assert(toggled and toggled.anchor == anchor, "fallback should toggle dropdown anchored to the supplied frame")
  end

  -- Right-click on a chat bubble routes through ContextMenu.Open with the
  -- bubble's text and frame as anchor; left-click does nothing.
  do
    local factory = FakeUI.NewFactory()
    local parent = factory.CreateFrame("Frame", nil, nil)
    parent:SetSize(400, 600)

    local capturedText, capturedAnchor, openCount = nil, nil, 0
    local originalOpen = ContextMenu.Open
    rawset(ContextMenu, "Open", function(text, anchorFrame)
      capturedText = text
      capturedAnchor = anchorFrame
      openCount = openCount + 1
      return true
    end)

    local bubble = BubbleFrame.CreateBubble(factory, parent, {
      direction = "in",
      kind = "user",
      text = "right click me",
      sentAt = 1000,
      playerName = "Arthas",
    }, { paneWidth = 400, showIcon = false })

    assert(type(bubble.frame.scripts.OnMouseDown) == "function", "bubble should wire OnMouseDown")
    assert(type(bubble.frame.scripts.OnMouseUp) == "function", "bubble should wire OnMouseUp")

    bubble.frame.scripts.OnMouseDown(bubble.frame, "LeftButton")
    bubble.frame.scripts.OnMouseUp(bubble.frame, "LeftButton")
    assert(openCount == 0, "left click must not open the menu")

    bubble.frame.scripts.OnMouseDown(bubble.frame, "RightButton")
    bubble.frame.scripts.OnMouseUp(bubble.frame, "RightButton")
    assert(openCount == 1, "right click should open the menu once per click")
    assert(capturedText == "right click me", "menu should receive the bubble text")
    assert(capturedAnchor == bubble.frame, "menu should anchor to the bubble frame")

    bubble.frame.scripts.OnMouseUp(bubble.frame, "RightButton")
    assert(openCount == 2, "mouse-up-only right click should still open the menu")

    rawset(ContextMenu, "Open", originalOpen)
  end

  restoreGlobals(saved)
end
