local ContextMenu = require("WhisperMessenger.UI.ContactsList.ContextMenu")
local Localization = require("WhisperMessenger.Locale.Localization")
local SeenGuild = require("WhisperMessenger.Model.SeenGuild")
local FakeUI = require("tests.helpers.fake_ui")

-- A contact menu wired to stubbed game globals for the "Guild invite" entry.
-- With(fn) calls fn(fixture) and puts every global back afterwards. The
-- fixture starts eligible (in a guild, invite rights, copy dialog available);
-- fixture.reset() returns to that state.
local GuildInviteMenu = {}

local GLOBALS = {
  "Menu",
  "UnitPopup_OpenMenu",
  "C_GuildInfo",
  "ChatFrameUtil",
  "ChatFrame_OpenChat",
  "IsInGuild",
  "CanGuildInvite",
  "UnitGUID",
  "UnitName",
  "GetNormalizedRealmName",
  "Ambiguate",
  "issecretvalue",
  "GetPlayerInfoByGUID",
  "StaticPopup_Show",
}

local function newRoot()
  local root = { buttons = {} }
  function root:CreateButton(text, callback)
    local button = { text = text, callback = callback }
    self.buttons[#self.buttons + 1] = button
    return button
  end
  return root
end

function GuildInviteMenu.FindButton(root, text)
  for _, button in ipairs(root.buttons) do
    if button.text == text then
      return button
    end
  end
  return nil
end

local function yes()
  return true
end

local function stubPlayer()
  rawset(_G, "UnitGUID", function()
    return "Player-1-SELF"
  end)
  rawset(_G, "UnitName", function()
    return "Me"
  end)
  rawset(_G, "GetNormalizedRealmName", function()
    return "Area52"
  end)
  rawset(_G, "Ambiguate", function(name)
    return (string.gsub(name, "%-Area52$", ""))
  end)
end

local function newFixture(anchor, modifiers, opened)
  local fixture = { opened = {}, invited = {} }

  function fixture.reset()
    fixture.opened = {}
    fixture.invited = {}
    SeenGuild._reset()
    rawset(_G, "IsInGuild", yes)
    rawset(_G, "CanGuildInvite", yes)
    rawset(_G, "issecretvalue", nil)
    rawset(_G, "GetPlayerInfoByGUID", nil)
    rawset(_G, "StaticPopup_Show", function() end)
    rawset(_G, "ChatFrame_OpenChat", nil)
    -- Records any fill of the game's chat box; a click must leave it alone.
    rawset(_G, "ChatFrameUtil", {
      OpenChat = function(text)
        fixture.opened[#fixture.opened + 1] = text
      end,
    })
    rawset(_G, "C_GuildInfo", {
      Invite = function(name)
        fixture.invited[#fixture.invited + 1] = name
      end,
      MemberExistsByName = function()
        return false
      end,
    })
  end

  function fixture.menuFor(item)
    ContextMenu.Open(item, anchor, nil, nil, { onPin = function() end })
    local root = newRoot()
    local tag = item.channel == "BN" and "MENU_UNIT_BN_FRIEND" or "MENU_UNIT_FRIEND"
    modifiers[tag](anchor, root, opened.context)
    return root
  end

  function fixture.row(overrides)
    local item = { channel = "WOW", displayName = "Arthas-Area52", guid = "Player-1-A" }
    for key, value in pairs(overrides or {}) do
      item[key] = value
    end
    return item
  end

  function fixture.entry(overrides)
    return GuildInviteMenu.FindButton(fixture.menuFor(fixture.row(overrides)), "Guild invite")
  end

  function fixture.hasEntry(overrides)
    return fixture.entry(overrides) ~= nil
  end

  return fixture
end

function GuildInviteMenu.With(fn)
  Localization.Configure({ language = "enUS" })
  local saved = {}
  for _, name in ipairs(GLOBALS) do
    saved[name] = rawget(_G, name)
  end
  local anchor = FakeUI.NewFactory().CreateFrame("Button", nil, nil)
  local modifiers = {}
  local opened = {}
  rawset(_G, "Menu", {
    ModifyMenu = function(tag, callback)
      modifiers[tag] = callback
    end,
  })
  rawset(_G, "UnitPopup_OpenMenu", function(_, contextData)
    opened.context = contextData
  end)
  stubPlayer()

  local fixture = newFixture(anchor, modifiers, opened)
  fixture.reset()
  local ok, err = pcall(fn, fixture)

  for _, name in ipairs(GLOBALS) do
    rawset(_G, name, saved[name])
  end
  SeenGuild._reset()
  if not ok then
    error(err, 0)
  end
end

return GuildInviteMenu
