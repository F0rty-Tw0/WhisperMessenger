rawset(_G, "time", rawget(_G, "time") or os.time)
rawset(_G, "date", rawget(_G, "date") or os.date)

local ContextMenu = require("WhisperMessenger.UI.ContactsList.ContextMenu")
local Localization = require("WhisperMessenger.Locale.Localization")
local FakeUI = require("tests.helpers.fake_ui")
local ExportPanel = require("WhisperMessenger.UI.ContactsList.ExportPanel")

-- "Export conversation" in the contact menu (rows, header, whisper sender
-- names) opens the export panel with the conversation's lines.

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
    UnitName = _G.UnitName,
    C_Timer = _G.C_Timer,
    Show = ExportPanel.Show,
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

  local shown = nil
  ExportPanel.Show = function(spec)
    shown = spec
  end

  local noop = function() end

  local function whisperMenu(item)
    ContextMenu.Open(item, anchor, noop, noop, nil)
    local root = newRoot()
    modifiers["MENU_UNIT_FRIEND"](anchor, root, openedContext)
    return root
  end

  -- test_whisper_menu_export_opens_the_panel_with_the_conversation
  do
    local root = whisperMenu(conversationItem("WOW"))
    local button = findButton(root, "Export conversation")
    assert(button ~= nil, "whisper menu offers Export conversation")
    button.callback()
    assert(shown ~= nil, "opens the export panel")
    assert(shown.title == "Arthas", "titled with the contact, got " .. tostring(shown.title))
    assert(shown.header == "Conversation with Arthas", "header line, got " .. tostring(shown.header))
    assert(#shown.lines == 2, "one line per message, got " .. #shown.lines)
    assert(shown.lines[1] == "[" .. os.date("%Y-%m-%d %H:%M", T1) .. "] Arthas: hi", "first line, got " .. tostring(shown.lines[1]))
    assert(shown.lines[2] == "[" .. os.date("%Y-%m-%d %H:%M", T1 + 60) .. "] Jaina: " .. string.rep("x", 300), "own line, whole")
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

  ExportPanel.Show = saved.Show
  rawset(_G, "UnitPopup_OpenMenu", saved.UnitPopup_OpenMenu)
  rawset(_G, "UnitName", saved.UnitName)
  _G.Menu, _G.MenuUtil, _G.C_Timer = saved.Menu, saved.MenuUtil, saved.C_Timer
end
