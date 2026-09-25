local ContextMenu = require("WhisperMessenger.UI.ContactsList.ContextMenu")
local Localization = require("WhisperMessenger.Locale.Localization")
local FakeUI = require("tests.helpers.fake_ui")

-- Our entries in Blizzard's player menu sit under their own divider and a
-- gold "WhisperMessenger" section title.

-- Fake Menu root description recording every element in order.
local function newRoot(withSectionApi)
  local root = { elements = {} }
  function root:CreateButton(text, callback)
    local button = { kind = "button", text = text, callback = callback }
    function button:SetEnabled(enabled)
      self.enabled = enabled
    end
    self.elements[#self.elements + 1] = button
    return button
  end
  if withSectionApi then
    function root:CreateDivider()
      self.elements[#self.elements + 1] = { kind = "divider" }
    end
    function root:CreateTitle(text)
      self.elements[#self.elements + 1] = { kind = "title", text = text }
    end
  end
  return root
end

return function()
  Localization.Configure({ language = "enUS" })
  local factory = FakeUI.NewFactory()
  local anchor = factory.CreateFrame("Button", nil, nil)
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

  local whisper = { channel = "WOW", displayName = "Arthas-Area52", conversationKey = "wow::arthas" }
  assert(ContextMenu.Open(whisper, anchor, function() end, function() end) == true, "whisper menu opens")

  -- test_player_menu_entries_start_with_divider_and_gold_title
  local root = newRoot(true)
  modifiers["MENU_UNIT_FRIEND"](anchor, root, openedContext)
  assert(root.elements[1].kind == "divider", "divider separates our section")
  local title = root.elements[2]
  assert(title.kind == "title", "section title follows the divider")
  assert(string.find(title.text, "WhisperMessenger", 1, true) ~= nil, "title names the addon")
  assert(string.find(title.text, "^|cff") ~= nil and string.find(title.text, "|r$") ~= nil, "title is colour-escaped gold")
  assert(root.elements[3].kind == "button", "our entries follow the title")
  assert(string.find(root.elements[3].text, "|c", 1, true) == nil, "entry labels stay plain")

  -- test_player_menu_without_section_api_still_adds_entries
  root = newRoot(false)
  modifiers["MENU_UNIT_FRIEND"](anchor, root, openedContext)
  assert(#root.elements > 0 and root.elements[1].kind == "button", "entries added without divider/title API")

  -- test_player_menu_without_callbacks_adds_no_empty_section
  assert(ContextMenu.Open(whisper, anchor) == true, "bare whisper menu opens")
  root = newRoot(true)
  modifiers["MENU_UNIT_FRIEND"](anchor, root, openedContext)
  assert(#root.elements == 0, "no divider/title without entries, got " .. #root.elements)

  _G.Menu = saved.Menu
  rawset(_G, "UnitPopup_OpenMenu", saved.UnitPopup_OpenMenu)
end
