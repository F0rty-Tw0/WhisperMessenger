local ContextMenu = require("WhisperMessenger.UI.ContactsList.ContextMenu")
local ProfileLinksMenuEntry = require("WhisperMessenger.UI.ContactsList.ProfileLinksMenuEntry")
local PopupUI = require("WhisperMessenger.UI.ChatBubble.ContextMenu.ManualCopy.PopupUI")
local FlavorCompat = require("WhisperMessenger.Core.FlavorCompat")
local Localization = require("WhisperMessenger.Locale.Localization")
local FakeUI = require("tests.helpers.fake_ui")

-- Right-clicking a contact offers "Copy profile link" with one entry per
-- profile site of this game; picking one opens the copy popup with the URL.

local SUBMENU = "Copy profile link"

local function newDescription(text, callback)
  local description = { text = text, callback = callback, buttons = {} }
  function description:CreateButton(childText, childCallback)
    local child = newDescription(childText, childCallback)
    self.buttons[#self.buttons + 1] = child
    return child
  end
  return description
end

local function findButton(root, text)
  for _, button in ipairs(root.buttons) do
    if button.text == text then
      return button
    end
  end
  return nil
end

local function labels(description)
  local list = {}
  for _, button in ipairs(description.buttons) do
    list[#list + 1] = button.text
  end
  return table.concat(list, ",")
end

return function()
  Localization.Configure({ language = "enUS" })
  local anchor = FakeUI.NewFactory().CreateFrame("Button", nil, nil)
  local saved = {
    Menu = _G.Menu,
    UnitPopup_OpenMenu = _G.UnitPopup_OpenMenu,
    GetCurrentRegion = _G.GetCurrentRegion,
    GetRealmName = _G.GetRealmName,
    GetNormalizedRealmName = _G.GetNormalizedRealmName,
    projectId = FlavorCompat.projectId,
    isForever = FlavorCompat.isForever,
    show = PopupUI.ShowManualCopyDialog,
  }
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
  local region = 3
  rawset(_G, "GetCurrentRegion", function()
    return region
  end)
  rawset(_G, "GetRealmName", function()
    return "Argent Dawn"
  end)
  rawset(_G, "GetNormalizedRealmName", function()
    return "ArgentDawn"
  end)
  FlavorCompat.projectId = 1
  FlavorCompat.isForever = false
  local copied = {}
  PopupUI.ShowManualCopyDialog = function(text, options)
    copied[#copied + 1] = { text = text, options = options }
    return true
  end

  local function menuFor(item, onUpdatePrefs)
    openedContext = nil
    ContextMenu.Open(item, anchor, nil, onUpdatePrefs)
    local root = newDescription()
    local tag = item.channel == "BN" and "MENU_UNIT_BN_FRIEND" or "MENU_UNIT_FRIEND"
    modifiers[tag](anchor, root, openedContext)
    return root
  end
  local onUpdatePrefs = function() end
  local arthas = { channel = "WOW", displayName = "Arthas-Area52", conversationKey = "wow::arthas" }

  -- test_whisper_contact_lists_retail_sites
  do
    local submenu = findButton(menuFor(arthas, onUpdatePrefs), SUBMENU)
    assert(submenu ~= nil, "submenu shown for a whisper contact")
    assert(labels(submenu) == "Raider.IO,Warcraft Logs", "retail sites, got " .. labels(submenu))
  end

  -- test_own_realm_contact_also_lists_armory
  do
    local submenu = findButton(menuFor({ channel = "WOW", displayName = "Jaina", conversationKey = "wow::jaina" }, onUpdatePrefs), SUBMENU)
    assert(labels(submenu) == "Raider.IO,Warcraft Logs,Armory", "armory for own realm, got " .. labels(submenu))
  end

  -- test_picking_a_site_opens_copy_popup_with_url
  do
    local submenu = findButton(menuFor(arthas, onUpdatePrefs), SUBMENU)
    copied = {}
    findButton(submenu, "Raider.IO").callback()
    assert(#copied == 1, "copy popup opened once")
    assert(copied[1].text == "https://raider.io/characters/eu/area52/Arthas", "url copied, got " .. tostring(copied[1].text))
    assert(copied[1].options.prompt == "Press Ctrl+C to copy the link.", "link prompt")
  end

  -- test_sender_without_callbacks_still_gets_submenu
  do
    assert(findButton(menuFor(arthas, nil), SUBMENU) ~= nil, "a group sender's menu has the submenu")
  end

  -- test_forever_hides_submenu
  do
    FlavorCompat.isForever = true
    assert(findButton(menuFor(arthas, onUpdatePrefs), SUBMENU) == nil, "no submenu on WoW: Forever")
    FlavorCompat.isForever = false
  end

  -- test_classic_era_season_picks_warcraftlogs_site
  do
    local savedSeasons = _G.C_Seasons
    rawset(_G, "C_Seasons", {
      GetActiveSeason = function()
        return 2 -- Enum.SeasonID.SeasonOfDiscovery
      end,
    })
    FlavorCompat.projectId = 2
    local submenu = findButton(menuFor(arthas, onUpdatePrefs), SUBMENU)
    FlavorCompat.projectId = 1
    rawset(_G, "C_Seasons", savedSeasons)
    copied = {}
    findButton(submenu, "Warcraft Logs").callback()
    local expected = "https://sod.warcraftlogs.com/character/eu/area52/arthas"
    assert(copied[1].text == expected, "season of discovery site, got " .. tostring(copied[1].text))
  end

  -- test_china_region_hides_submenu
  do
    region = 5
    assert(findButton(menuFor(arthas, onUpdatePrefs), SUBMENU) == nil, "no submenu in China")
    region = 3
  end

  -- test_battlenet_friend_without_character_hides_submenu
  do
    local friend = { channel = "BN", displayName = "Friend#1234", battleTag = "Friend#1234", bnetAccountID = 7 }
    assert(findButton(menuFor(friend, onUpdatePrefs), SUBMENU) == nil, "no character, no submenu")
  end

  -- test_battlenet_friend_playing_this_game_gets_submenu
  do
    local savedBattleNet = _G.C_BattleNet
    local gameAccountInfo = {
      isOnline = true,
      clientProgram = "WoW",
      wowProjectID = 1,
      regionID = 3,
      characterName = "Thrall",
      realmName = "Area 52",
    }
    rawset(_G, "C_BattleNet", {
      GetAccountInfoByID = function()
        return { bnetAccountID = 7, battleTag = "Friend#1234", isOnline = true, gameAccountInfo = gameAccountInfo }
      end,
    })
    local friend = { channel = "BN", displayName = "Friend#1234", battleTag = "Friend#1234", bnetAccountID = 7, gameAccountName = "Garrosh-Kazzak" }
    local submenu = findButton(menuFor(friend, onUpdatePrefs), SUBMENU)
    rawset(_G, "C_BattleNet", savedBattleNet)
    assert(
      submenu ~= nil and labels(submenu) == "Raider.IO,Warcraft Logs,Armory",
      "live character sites, got " .. labels(submenu or { buttons = {} })
    )
    copied = {}
    findButton(submenu, "Armory").callback()
    local expected = "https://worldofwarcraft.blizzard.com/en-us/character/eu/area-52/thrall"
    assert(copied[1].text == expected, "live character's armory, got " .. tostring(copied[1].text))
  end

  -- test_links_never_throw
  do
    -- Stands in for a secret value: any read raises, as 12.0 secrets do.
    local raising = setmetatable({ channel = "WOW" }, {
      __index = function()
        error("secret string value tainted by 'WhisperMessenger'")
      end,
    })
    local ok, links = pcall(ProfileLinksMenuEntry.Links, raising)
    assert(ok, "Links raised: " .. tostring(links))
    assert(#links == 0, "no links when the contact can't be read")
  end

  _G.Menu = saved.Menu
  rawset(_G, "UnitPopup_OpenMenu", saved.UnitPopup_OpenMenu)
  rawset(_G, "GetCurrentRegion", saved.GetCurrentRegion)
  rawset(_G, "GetRealmName", saved.GetRealmName)
  rawset(_G, "GetNormalizedRealmName", saved.GetNormalizedRealmName)
  FlavorCompat.projectId = saved.projectId
  FlavorCompat.isForever = saved.isForever
  PopupUI.ShowManualCopyDialog = saved.show
end
