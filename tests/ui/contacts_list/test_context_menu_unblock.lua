local ContextMenu = require("WhisperMessenger.UI.ContactsList.ContextMenu")
local Localization = require("WhisperMessenger.Locale.Localization")
local FakeUI = require("tests.helpers.fake_ui")

-- A blocked player's row offers "Unblock" in place of "Block…".

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

  local unblocked = {}
  local rowActions = {
    onIgnorePlayer = function() end,
    onUnblockPlayer = function(name)
      unblocked[#unblocked + 1] = name
    end,
    isPlayerBlocked = function(name)
      return name == "Arthas-Area52"
    end,
  }
  local function menuFor(item)
    ContextMenu.Open(item, anchor, nil, nil, rowActions)
    local root = newRoot()
    modifiers["MENU_UNIT_FRIEND"](anchor, root, openedContext)
    return root
  end

  -- test_blocked_row_offers_unblock_instead_of_block
  do
    local root = menuFor({ channel = "WOW", displayName = "Arthas-Area52", conversationKey = "wow::arthas" })
    assert(findButton(root, "Block…") == nil, "no Block… for a blocked player")
    local unblock = findButton(root, "Unblock")
    assert(unblock ~= nil, "blocked row offers Unblock")
    unblock.callback()
    assert(unblocked[1] == "Arthas-Area52", "unblocks the character, got " .. tostring(unblocked[1]))
  end

  -- test_unblocked_row_keeps_block
  do
    local root = menuFor({ channel = "WOW", displayName = "Jaina-Area52", conversationKey = "wow::jaina" })
    assert(findButton(root, "Block…") ~= nil and findButton(root, "Unblock") == nil, "Block… only")
  end

  _G.Menu = saved.Menu
  rawset(_G, "UnitPopup_OpenMenu", saved.UnitPopup_OpenMenu)
end
