local ProtectedMenuEntries = require("WhisperMessenger.UI.ContactsList.ProtectedMenuEntries")
local ContextMenu = require("WhisperMessenger.UI.ContactsList.ContextMenu")
local PopupUI = require("WhisperMessenger.UI.ChatBubble.ContextMenu.ManualCopy.PopupUI")
local FlavorCompat = require("WhisperMessenger.Core.FlavorCompat")
local FakeUI = require("tests.helpers.fake_ui")

-- Some Blizzard player-menu entries call functions the game blocks when an
-- addon opened the menu (ADDON_ACTION_FORBIDDEN): Copy Character Name is
-- pointed at our own copy dialog.

local COPY_LABEL = "Copy Character Name"

local function newElement(text)
  local element = { text = text, children = {} }
  function element:SetResponder(callback)
    self.responder = callback
  end
  function element:SetEnabled(enabled)
    self.enabled = enabled
  end
  function element:EnumerateElementDescriptions()
    return ipairs(self.children)
  end
  return element
end

-- Fake Menu root: Blizzard's entries, the copy one inside a submenu when nested.
local function newRoot(nested)
  local root = newElement(nil)
  root.CreateButton = function() end
  local copy = newElement(COPY_LABEL)
  root.children[1] = newElement("Whisper")
  if nested then
    local other = newElement("Other Options")
    other.children[1] = copy
    root.children[2] = other
  else
    root.children[2] = copy
  end
  return root, copy
end

return function()
  local saved = {
    label = _G.COPY_CHARACTER_NAME,
    MenuUtil = _G.MenuUtil,
    Menu = _G.Menu,
    UnitPopup_OpenMenu = _G.UnitPopup_OpenMenu,
    showDialog = PopupUI.ShowManualCopyDialog,
    forever = FlavorCompat.isForever,
  }
  rawset(_G, "COPY_CHARACTER_NAME", COPY_LABEL)
  _G.MenuUtil = {
    GetElementText = function(element)
      return element.text
    end,
  }
  local copied, prompt
  rawset(PopupUI, "ShowManualCopyDialog", function(text, options)
    copied = text
    prompt = options and options.prompt
    return true
  end)
  FlavorCompat.isForever = false

  -- test_copy_entry_copies_whisper_name_through_our_dialog
  local root, copy = newRoot(false)
  ProtectedMenuEntries.Fix(root, { channel = "WOW", displayName = "Arthas-Area52" })
  assert(type(copy.responder) == "function", "copy entry gets our responder")
  copy.responder()
  assert(copied == "Arthas-Area52", "copies the whisper name, got " .. tostring(copied))

  -- test_copy_dialog_asks_to_copy_the_name
  assert(prompt == "Press Ctrl+C to copy the name.", "dialog prompt names a name, got " .. tostring(prompt))

  -- test_copy_entry_in_submenu_is_found
  copied = nil
  root, copy = newRoot(true)
  ProtectedMenuEntries.Fix(root, { channel = "WOW", displayName = "Jaina-Proudmoore" })
  assert(type(copy.responder) == "function", "nested copy entry gets our responder")
  copy.responder()
  assert(copied == "Jaina-Proudmoore", "copies the nested whisper name, got " .. tostring(copied))

  -- test_copy_entry_disabled_for_a_name_hidden_by_the_chat_lock
  local secretName = "Secret-Area52"
  local savedIsSecret = _G.issecretvalue
  rawset(_G, "issecretvalue", function(value)
    return value == secretName
  end)
  root, copy = newRoot(false)
  ProtectedMenuEntries.Fix(root, { channel = "WOW", displayName = secretName })
  rawset(_G, "issecretvalue", savedIsSecret)
  assert(copy.responder == nil, "no responder for a hidden name")
  assert(copy.enabled == false, "entry with a hidden name is disabled")

  -- test_copy_entry_drops_realm_from_whisper_name_on_forever
  -- (Forever's own Copy Character Name copies the name without the realm.)
  FlavorCompat.isForever = true
  copied = nil
  root, copy = newRoot(false)
  ProtectedMenuEntries.Fix(root, { channel = "WOW", displayName = "Arthas-Area52" })
  copy.responder()
  assert(copied == "Arthas", "Forever copies the whisper name without realm, got " .. tostring(copied))
  FlavorCompat.isForever = false

  -- test_copy_entry_disabled_without_a_character_name
  root, copy = newRoot(false)
  ProtectedMenuEntries.Fix(root, { channel = "WOW" })
  assert(copy.responder == nil, "no responder without a character name")
  assert(copy.enabled == false, "blocked entry is disabled instead")

  -- test_other_entries_stay_untouched
  root = newRoot(false)
  ProtectedMenuEntries.Fix(root, { channel = "WOW", displayName = "Arthas-Area52" })
  assert(root.children[1].enabled == nil and root.children[1].responder == nil, "other entries stay as Blizzard made them")

  -- test_menu_opened_from_row_fixes_copy_entry_even_without_our_section
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
  local anchor = FakeUI.NewFactory().CreateFrame("Button", nil, nil)
  assert(ContextMenu.Open({ channel = "WOW", displayName = "Sylvanas-Area52" }, anchor) == true, "menu opens")
  root, copy = newRoot(false)
  modifiers["MENU_UNIT_FRIEND"](anchor, root, openedContext)
  copied = nil
  copy.responder()
  assert(copied == "Sylvanas-Area52", "row menu copy uses our dialog, got " .. tostring(copied))

  -- test_menu_blizzard_opened_keeps_its_own_copy_entry
  root, copy = newRoot(false)
  modifiers["MENU_UNIT_FRIEND"](anchor, root, { name = "Someone" })
  assert(copy.responder == nil, "menus we did not open stay untouched")

  rawset(_G, "COPY_CHARACTER_NAME", saved.label)
  _G.MenuUtil = saved.MenuUtil
  _G.Menu = saved.Menu
  rawset(_G, "UnitPopup_OpenMenu", saved.UnitPopup_OpenMenu)
  rawset(PopupUI, "ShowManualCopyDialog", saved.showDialog)
  FlavorCompat.isForever = saved.forever
end
