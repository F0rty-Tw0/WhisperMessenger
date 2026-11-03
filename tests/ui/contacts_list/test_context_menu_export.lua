rawset(_G, "time", rawget(_G, "time") or os.time)
rawset(_G, "date", rawget(_G, "date") or os.date)

local ContextMenu = require("WhisperMessenger.UI.ContactsList.ContextMenu")
local Localization = require("WhisperMessenger.Locale.Localization")
local FakeUI = require("tests.helpers.fake_ui")

-- "Export conversation" in the contact menu (rows, header, whisper sender
-- names) opens the manual-copy popup filled with the whole conversation.

local T1 = 1700000000

local function newRoot()
  local root = { buttons = {} }
  function root:CreateButton(text, callback)
    local button = { text = text, callback = callback }
    self.buttons[#self.buttons + 1] = button
    return button
  end
  return root
end

local function findButton(root, text)
  for _, button in ipairs(root.buttons) do
    if button.text == text then
      return button
    end
  end
  return nil
end

local function newEditBox()
  local box = { frameType = "EditBox", multiLine = false, maxLetters = 255, maxBytes = 0 }
  function box:SetText(value)
    -- A single-line box with a letter cap keeps only what fits.
    if self.maxLetters > 0 then
      value = string.sub(value, 1, self.maxLetters)
    end
    self.text = value
  end
  function box:HighlightText() end
  function box:SetFocus() end
  function box:SetMultiLine(value)
    self.multiLine = value
  end
  function box:IsMultiLine()
    return self.multiLine
  end
  function box:SetMaxLetters(value)
    self.maxLetters = value
  end
  function box:GetMaxLetters()
    return self.maxLetters
  end
  function box:SetMaxBytes(value)
    self.maxBytes = value
  end
  function box:GetMaxBytes()
    return self.maxBytes
  end
  return box
end

local function conversationItem(channel)
  local long = string.rep("x", 300)
  return {
    channel = channel,
    displayName = channel == "WOW" and "Arthas" or "Guild",
    conversation = {
      messages = {
        { direction = "in", kind = "user", text = "hi", sentAt = T1, playerName = "Arthas" },
        { direction = "out", kind = "user", text = long, sentAt = T1 + 60, playerName = "Arthas" },
      },
    },
  }
end

return function()
  Localization.Configure({ language = "enUS" })
  local factory = FakeUI.NewFactory()
  local anchor = factory.CreateFrame("Button", nil, nil)
  local saved = {
    Menu = _G.Menu,
    UnitPopup_OpenMenu = _G.UnitPopup_OpenMenu,
    MenuUtil = _G.MenuUtil,
    StaticPopup_Show = _G.StaticPopup_Show,
    StaticPopupDialogs = _G.StaticPopupDialogs,
    UnitName = _G.UnitName,
    C_Timer = _G.C_Timer,
  }

  local modifiers, openedContext, groupGenerator = {}, nil, nil
  _G.Menu = {
    ModifyMenu = function(tag, callback)
      modifiers[tag] = callback
    end,
  }
  rawset(_G, "UnitPopup_OpenMenu", function(_, contextData)
    openedContext = contextData
  end)
  _G.MenuUtil = {
    CreateContextMenu = function(_owner, generator)
      groupGenerator = generator
    end,
  }
  rawset(_G, "UnitName", function()
    return "Jaina"
  end)
  _G.C_Timer = nil
  _G.StaticPopupDialogs = {}

  local editBox = newEditBox()
  local shown = {}
  rawset(_G, "StaticPopup_Show", function(which, _t1, _t2, data)
    local dialog = { data = data, editBox = editBox }
    local def = _G.StaticPopupDialogs[which]
    shown.which, shown.dialog, shown.def = which, dialog, def
    def.OnShow(dialog, data)
    return dialog
  end)

  local noop = function() end

  local function whisperMenu(item)
    ContextMenu.Open(item, anchor, noop, noop, nil)
    local root = newRoot()
    modifiers["MENU_UNIT_FRIEND"](anchor, root, openedContext)
    return root
  end

  -- test_whisper_menu_export_opens_the_copy_popup_with_the_conversation
  do
    local root = whisperMenu(conversationItem("WOW"))
    local button = findButton(root, "Export conversation")
    assert(button ~= nil, "whisper menu offers Export conversation")
    button.callback()
    assert(shown.which == "WHISPER_MESSENGER_BUBBLE_COPY_TEXT", "reuses the manual-copy popup")
    local expected = table.concat({
      "Conversation with Arthas",
      "[" .. os.date("%Y-%m-%d %H:%M", T1) .. "] Arthas: hi",
      "[" .. os.date("%Y-%m-%d %H:%M", T1 + 60) .. "] Jaina: " .. string.rep("x", 300),
    }, "\n")
    assert(editBox.text == expected, "the popup holds the whole conversation, got " .. tostring(editBox.text))
    assert(shown.def.text == "Press Ctrl+C to copy the conversation.", "export prompt, got " .. tostring(shown.def.text))
  end

  -- test_export_box_is_multi_line_and_uncapped_then_restored_on_hide
  do
    assert(editBox.multiLine == true, "export box is multi-line")
    assert(editBox.maxLetters == 0 and editBox.maxBytes == 0, "export box has no length cap")
    shown.def.OnHide(shown.dialog)
    assert(editBox.multiLine == false, "the shared popup box is single-line again after hide")
    assert(editBox.maxLetters == 255, "the shared popup box gets its letter cap back")
  end

  -- test_message_copy_after_export_keeps_the_single_line_box
  do
    local PopupUI = require("WhisperMessenger.UI.ChatBubble.ContextMenu.ManualCopy.PopupUI")
    PopupUI.ShowManualCopyDialog("one message")
    assert(editBox.multiLine == false and editBox.maxLetters == 255, "a single-message copy is unchanged")
    assert(shown.def.text == "Press Ctrl+C to copy the message text.", "message prompt is back")
    shown.def.OnHide(shown.dialog)
  end

  -- test_group_menu_offers_export
  do
    ContextMenu.Open(conversationItem("GUILD"), anchor, noop, noop, nil)
    local root = newRoot()
    assert(groupGenerator ~= nil, "group menu built")
    groupGenerator(anchor, root)
    assert(findButton(root, "Export conversation") ~= nil, "group menu offers Export conversation")
  end

  -- test_no_conversation_no_export_entry
  do
    local root = whisperMenu({ channel = "WOW", displayName = "Thrall" })
    assert(findButton(root, "Export conversation") == nil, "nothing to export, no entry")
  end

  rawset(_G, "StaticPopup_Show", saved.StaticPopup_Show)
  rawset(_G, "UnitPopup_OpenMenu", saved.UnitPopup_OpenMenu)
  rawset(_G, "UnitName", saved.UnitName)
  _G.Menu, _G.MenuUtil, _G.StaticPopupDialogs, _G.C_Timer = saved.Menu, saved.MenuUtil, saved.StaticPopupDialogs, saved.C_Timer
end
