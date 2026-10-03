local ContextMenu = require("WhisperMessenger.UI.ContactsList.ContextMenu")
local Localization = require("WhisperMessenger.Locale.Localization")
local FakeUI = require("tests.helpers.fake_ui")

-- Right-click "Block…" on a whisper row asks for a reason, then reports the
-- player to the silent ignore list. Group rows are not players: no entry.

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

-- StaticPopup stub that accepts at once with `typed`.
local function stubPopup(typed)
  _G.StaticPopupDialogs = {}
  rawset(_G, "StaticPopup_Show", function(name)
    _G.StaticPopupDialogs[name].OnAccept({
      editBox = {
        frameType = "EditBox",
        GetText = function()
          return typed
        end,
        SetText = function() end,
      },
    })
  end)
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

  local ignored = {}
  local rowActions = {
    onIgnorePlayer = function(name, reason)
      ignored[#ignored + 1] = { name = name, reason = reason }
    end,
  }

  -- test_whisper_row_menu_offers_ignore
  local whisper = { channel = "WOW", displayName = "Arthas-Area52", conversationKey = "wow::arthas", nickname = "Boss" }
  assert(ContextMenu.Open(whisper, anchor, nil, nil, rowActions) == true, "whisper menu opens")
  local root = newRoot()
  modifiers["MENU_UNIT_FRIEND"](anchor, root, openedContext)
  local ignore = findButton(root, "Block…")
  assert(ignore ~= nil, "whisper row offers Block…")

  -- test_accepting_the_dialog_ignores_with_the_reason
  stubPopup("  spam ")
  ignore.callback()
  assert(#ignored == 1, "player reported once")
  assert(ignored[1].name == "Arthas-Area52", "ignores the character, not the nickname")
  assert(ignored[1].reason == "spam", "trimmed reason passed on")

  -- test_ignore_uses_the_character_behind_the_guid
  local savedPlayerInfo = _G.GetPlayerInfoByGUID
  rawset(_G, "GetPlayerInfoByGUID", function(guid)
    if guid == "Player-3676-0A" then
      return "Mage", "MAGE", "Human", "Human", 2, "Arthas", "Area 52"
    end
  end)
  local nicknamed = { channel = "WOW", displayName = "Boss", guid = "Player-3676-0A", conversationKey = "wow::WOW::boss" }
  ContextMenu.Open(nicknamed, anchor, nil, nil, rowActions)
  root = newRoot()
  modifiers["MENU_UNIT_FRIEND"](anchor, root, openedContext)
  findButton(root, "Block…").callback()
  rawset(_G, "GetPlayerInfoByGUID", savedPlayerInfo)
  assert(ignored[2] and ignored[2].name == "Arthas-Area52", "ignores the character's full name, got " .. tostring(ignored[2] and ignored[2].name))

  -- test_battle_net_row_has_no_ignore
  local bnet = { channel = "BN", displayName = "Jaina", battleTag = "Jaina#1234", conversationKey = "bn::jaina" }
  ContextMenu.Open(bnet, anchor, nil, nil, rowActions)
  root = newRoot()
  modifiers["MENU_UNIT_BN_FRIEND"](anchor, root, openedContext)
  assert(findButton(root, "Block…") == nil, "Battle.net rows have no Block…")

  -- test_guild_row_has_no_ignore
  local groupRoot = newRoot()
  rawset(_G, "MenuUtil", {
    CreateContextMenu = function(owner, generator)
      generator(owner, groupRoot)
    end,
  })
  local guild = { channel = "GUILD", displayName = "Guild", conversationKey = "guild::x" }
  assert(ContextMenu.Open(guild, anchor, nil, function() end, rowActions) == true, "group menu opens")
  assert(findButton(groupRoot, "Block…") == nil, "guild rows have no Block…")

  -- test_ignore_entries_are_translated
  Localization.Configure({ language = "ruRU" })
  assert(Localization.Text("Block…") ~= "Block…", "row entry translated")
  assert(Localization.Text("Block sender…") ~= "Block sender…", "message entry translated")
  Localization.Configure({ language = "enUS" })

  _G.Menu = saved.Menu
  rawset(_G, "UnitPopup_OpenMenu", saved.UnitPopup_OpenMenu)
  rawset(_G, "MenuUtil", saved.MenuUtil)
  _G.StaticPopupDialogs = nil
  rawset(_G, "StaticPopup_Show", nil)
end
