local ContextMenu = require("WhisperMessenger.UI.ContactsList.ContextMenu")
local Localization = require("WhisperMessenger.Locale.Localization")
local FakeUI = require("tests.helpers.fake_ui")

-- Right-click menu entries for mute, nickname and note. Whisper rows extend
-- Blizzard's player menu; group rows get a small menu of their own.

-- Fake Menu root description recording every button.
local function newRoot()
  local root = { buttons = {} }
  function root:CreateButton(text, callback)
    local button = { text = text, callback = callback }
    function button:SetEnabled(enabled)
      self.enabled = enabled
    end
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

local function stubPopup(typed)
  local shown = {}
  _G.StaticPopupDialogs = {}
  rawset(_G, "StaticPopup_Show", function(name, textArg, _, data)
    shown.name, shown.textArg, shown.data = name, textArg, data
    shown.popup = {
      data = data,
      editBox = {
        frameType = "EditBox",
        GetText = function()
          return typed
        end,
        SetText = function() end,
      },
    }
    return shown.popup
  end)
  return shown
end

return function()
  Localization.Configure({ language = "enUS" })
  local factory = FakeUI.NewFactory()
  local anchor = factory.CreateFrame("Button", nil, nil)
  local saved = { Menu = _G.Menu, UnitPopup_OpenMenu = _G.UnitPopup_OpenMenu, MenuUtil = _G.MenuUtil }

  local modifiers = {}
  local openedContext
  _G.Menu = {
    ModifyMenu = function(tag, callback)
      modifiers[tag] = callback
    end,
  }
  rawset(_G, "UnitPopup_OpenMenu", function(_, contextData)
    openedContext = contextData
  end)

  local updates = {}
  local function onUpdatePrefs(item, changes)
    updates[#updates + 1] = { item = item, changes = changes }
  end

  local whisper = { channel = "WOW", displayName = "Arthas-Area52", conversationKey = "wow::arthas", nickname = "Boss" }

  -- test_whisper_menu_adds_mute_nickname_and_note
  assert(ContextMenu.Open(whisper, anchor, function() end, onUpdatePrefs) == true, "whisper menu opens")
  local root = newRoot()
  modifiers["MENU_UNIT_FRIEND"](anchor, root, openedContext)
  assert(findButton(root, "Mark last messages as unread") ~= nil, "existing entry kept")
  local mute = findButton(root, "Mute")
  assert(mute ~= nil, "Mute entry added")
  assert(findButton(root, "Set nickname…") ~= nil and findButton(root, "Edit note…") ~= nil, "nickname and note entries added")

  -- test_mute_entry_mutes_the_clicked_conversation
  mute.callback()
  assert(updates[1].item == whisper and updates[1].changes.muted == true, "mute requested")

  -- test_muted_contact_offers_unmute
  whisper.muted = true
  root = newRoot()
  modifiers["MENU_UNIT_FRIEND"](anchor, root, openedContext)
  findButton(root, "Unmute").callback()
  assert(updates[2].changes.muted == false, "unmute requested")

  -- test_nickname_entry_opens_prefilled_popup_and_saves
  local shown = stubPopup("  Big Boss ")
  findButton(root, "Set nickname…").callback()
  assert(shown.name == "WHISPER_MESSENGER_SET_NICKNAME", "nickname popup shown")
  assert(shown.data == "Boss", "popup prefilled with the current nickname")
  assert(shown.textArg == "Arthas-Area52", "popup names the contact")
  local dialog = _G.StaticPopupDialogs[shown.name]
  assert(dialog.maxLetters == 32, "nickname input capped at 32 characters")
  dialog.OnAccept(shown.popup)
  assert(updates[3].changes.nickname == "  Big Boss ", "typed nickname sent for saving")

  -- test_note_entry_opens_popup_capped_at_255_bytes
  shown = stubPopup("")
  findButton(root, "Edit note…").callback()
  dialog = _G.StaticPopupDialogs[shown.name]
  assert(shown.name == "WHISPER_MESSENGER_EDIT_NOTE", "note popup shown")
  assert(shown.data == "", "empty prefill without a note")
  assert(dialog.maxBytes == 256, "note input capped at 255 bytes (+ terminator)")
  dialog.OnAccept(shown.popup)
  assert(updates[4].changes.note == "", "empty text clears the note")

  -- test_group_row_opens_own_menu_with_mute_only
  local generator
  _G.MenuUtil = {
    CreateContextMenu = function(owner, gen)
      assert(owner == anchor, "menu anchored on the row")
      generator = gen
    end,
  }
  openedContext = nil
  local group = { channel = "GUILD", displayName = "Guild", conversationKey = "guild::x" }
  assert(ContextMenu.Open(group, anchor, function() end, onUpdatePrefs) == true, "group menu opens")
  assert(openedContext == nil, "group rows never open Blizzard's player menu")
  root = newRoot()
  generator(anchor, root)
  assert(findButton(root, "Mute") ~= nil, "group can be muted")
  assert(findButton(root, "Mark last messages as unread") ~= nil, "group keeps mark-unread")
  assert(findButton(root, "Set nickname…") == nil and findButton(root, "Edit note…") == nil, "no nickname or note for groups")
  findButton(root, "Mute").callback()
  assert(updates[5].item == group and updates[5].changes.muted == true, "group mute requested")

  -- test_group_row_without_menu_api_falls_back_to_select
  _G.MenuUtil = nil
  assert(ContextMenu.Open(group, anchor, function() end, onUpdatePrefs) == false, "no menu api: row click selects instead")

  _G.Menu = saved.Menu
  _G.UnitPopup_OpenMenu = saved.UnitPopup_OpenMenu
  _G.MenuUtil = saved.MenuUtil
  _G.StaticPopupDialogs = nil
  rawset(_G, "StaticPopup_Show", nil)
end
