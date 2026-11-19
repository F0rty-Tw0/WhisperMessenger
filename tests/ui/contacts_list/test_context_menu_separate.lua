local ContextMenu = require("WhisperMessenger.UI.ContactsList.ContextMenu")
local Localization = require("WhisperMessenger.Locale.Localization")
local FakeUI = require("tests.helpers.fake_ui")

-- A Battle.net row with characters folded into it offers one
-- "Separate <Character>" per character.
local B = "bnet::BN::jaina#1234"

local function newRoot()
  local root = { buttons = {} }
  function root:CreateButton(text, callback)
    local button = { text = text, callback = callback }
    self.buttons[#self.buttons + 1] = button
    return button
  end
  return root
end

local function separateButtons(root)
  local found = {}
  for _, button in ipairs(root.buttons) do
    if string.find(button.text, "^Separate ") then
      found[#found + 1] = button
    end
  end
  return found
end

return function()
  Localization.Configure({ language = "enUS" })
  local anchor = FakeUI.NewFactory().CreateFrame("Button", nil, nil)
  local saved = { Menu = _G.Menu, UnitPopup_OpenMenu = _G.UnitPopup_OpenMenu }
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

  local separated = {}
  local listed = {}
  local merged = {
    [B] = { { characterKey = "wow::WOW::arthas", name = "Arthas" }, { characterKey = "wow::WOW::arthas-area52", name = "Arthas-Area52" } },
  }
  local rowActions = {
    onPin = function() end,
    onRemove = function() end,
    listMergedCharacters = function(bnetKey)
      listed[#listed + 1] = bnetKey
      return merged[bnetKey] or {}
    end,
    onSeparateCharacter = function(bnetKey, characterKey)
      separated[#separated + 1] = bnetKey .. ">" .. characterKey
    end,
  }
  local function menuFor(item, tag)
    ContextMenu.Open(item, anchor, nil, nil, rowActions)
    local root = newRoot()
    modifiers[tag](anchor, root, openedContext)
    return root
  end
  local friend = { channel = "BN", displayName = "Jaina#1234", battleTag = "Jaina#1234", bnetAccountID = 77, conversationKey = B }

  local ok, err = pcall(function()
    -- test_battle_net_row_lists_one_separate_entry_per_merged_character
    do
      local buttons = separateButtons(menuFor(friend, "MENU_UNIT_BN_FRIEND"))
      assert(#buttons == 2, "a Battle.net row lists one Separate entry per merged character, got " .. #buttons)
      assert(buttons[1].text == "Separate Arthas" and buttons[2].text == "Separate Arthas-Area52", "named as stored, in the map's order")
    end

    -- test_picking_an_entry_separates_that_character
    do
      local buttons = separateButtons(menuFor(friend, "MENU_UNIT_BN_FRIEND"))
      buttons[2].callback()
      assert(
        separated[#separated] == B .. ">wow::WOW::arthas-area52",
        "separates the picked character from this chat, got " .. tostring(separated[#separated])
      )
    end

    -- test_battle_net_row_without_merged_characters_has_no_entry
    do
      local other = { channel = "BN", displayName = "Thrall#1", battleTag = "Thrall#1", bnetAccountID = 9, conversationKey = "bnet::BN::thrall#1" }
      assert(#separateButtons(menuFor(other, "MENU_UNIT_BN_FRIEND")) == 0, "no merged characters: no Separate entry")
    end

    -- test_character_row_has_no_entry
    do
      local before = #listed
      local whisper = { channel = "WOW", displayName = "Arthas", conversationKey = "wow::WOW::arthas" }
      assert(#separateButtons(menuFor(whisper, "MENU_UNIT_FRIEND")) == 0, "a character row has no Separate entry")
      assert(#listed == before, "and does not read the merge map")
    end

    -- test_row_without_the_separate_action_has_no_entry
    do
      local savedSeparate = rowActions.onSeparateCharacter
      rowActions.onSeparateCharacter = nil
      local buttons = separateButtons(menuFor(friend, "MENU_UNIT_BN_FRIEND"))
      rowActions.onSeparateCharacter = savedSeparate
      assert(#buttons == 0, "no Separate callback: no entry")
    end
  end)

  _G.Menu = saved.Menu
  rawset(_G, "UnitPopup_OpenMenu", saved.UnitPopup_OpenMenu)
  assert(ok, err)
end
