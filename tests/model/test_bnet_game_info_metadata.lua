local ContactEnricher = require("WhisperMessenger.Model.ContactEnricher")
local PresenceCache = require("WhisperMessenger.Model.PresenceCache")

local function makeRuntime(overrides)
  local r = {
    availabilityByGUID = {},
    sendStatusByConversation = {},
    activeConversationKey = nil,
    bnetApi = {},
    store = { conversations = {} },
  }
  if overrides then
    for k, v in pairs(overrides) do
      r[k] = v
    end
  end
  return r
end

return function()
  PresenceCache._reset()
  PresenceCache._setCache({})

  -- BuildWindowSelectionState: offline friend keeps stored class and zone (characterName == nil)
  do
    local runtime = makeRuntime({
      activeConversationKey = "bnet::BN::1",
      bnetApi = {
        GetAccountInfoByID = function(_id, _guid)
          return {
            isOnline = false,
            gameAccountInfo = {
              isOnline = false,
              characterName = nil,
              className = "Priest",
              areaName = "Orgrimmar",
              playerGuid = "Player-1-2",
            },
          }
        end,
      },
      playerInfoByGUID = function(_guid)
        return "Priest", "PRIEST", "Troll", "Troll"
      end,
      store = {
        conversations = {
          ["bnet::BN::1"] = {
            channel = "BN",
            bnetAccountID = 1,
            guid = "Player-1-2",
            className = "Mage",
            classTag = "MAGE",
          },
        },
      },
    })
    local contacts = {
      {
        conversationKey = "bnet::BN::1",
        channel = "BN",
        bnetAccountID = 1,
        guid = "Player-1-2",
        className = "Mage",
        classTag = "MAGE",
      },
    }
    local result = ContactEnricher.BuildWindowSelectionState(runtime, contacts, nil)
    local selected = result.selectedContact
    assert(selected ~= nil, "selectedContact should exist")
    assert(selected.className == "Mage", "offline friend keeps stored className, got: " .. tostring(selected.className))
    assert(selected.classTag == "MAGE", "offline friend keeps stored classTag, got: " .. tostring(selected.classTag))
    assert(selected.areaName == nil, "offline friend should not get stale areaName, got: " .. tostring(selected.areaName))
    assert(selected.characterName == nil, "offline friend should not get stale characterName, got: " .. tostring(selected.characterName))
    assert(result.status.status == "Offline", "offline friend status should be Offline, got: " .. tostring(result.status.status))
  end

  -- BuildWindowSelectionState: offline friend keeps stored class and zone (characterName == "")
  do
    local runtime = makeRuntime({
      activeConversationKey = "bnet::BN::1b",
      bnetApi = {
        GetAccountInfoByID = function(_id, _guid)
          return {
            isOnline = false,
            gameAccountInfo = {
              isOnline = false,
              characterName = "",
              className = "Priest",
              areaName = "Orgrimmar",
              playerGuid = "Player-1-2",
            },
          }
        end,
      },
      playerInfoByGUID = function(_guid)
        return "Priest", "PRIEST", "Troll", "Troll"
      end,
      store = {
        conversations = {
          ["bnet::BN::1b"] = {
            channel = "BN",
            bnetAccountID = 1,
            guid = "Player-1-2",
            className = "Mage",
            classTag = "MAGE",
          },
        },
      },
    })
    local contacts = {
      {
        conversationKey = "bnet::BN::1b",
        channel = "BN",
        bnetAccountID = 1,
        guid = "Player-1-2",
        className = "Mage",
        classTag = "MAGE",
      },
    }
    local result = ContactEnricher.BuildWindowSelectionState(runtime, contacts, nil)
    local selected = result.selectedContact
    assert(selected ~= nil, "selectedContact should exist")
    assert(selected.className == "Mage", "offline (empty characterName) friend keeps stored className, got: " .. tostring(selected.className))
    assert(selected.classTag == "MAGE", "offline (empty characterName) friend keeps stored classTag, got: " .. tostring(selected.classTag))
    assert(selected.areaName == nil, "offline (empty characterName) friend should not get stale areaName, got: " .. tostring(selected.areaName))
    assert(
      selected.characterName == nil,
      "offline (empty characterName) friend should not get stale characterName, got: " .. tostring(selected.characterName)
    )
  end

  -- BuildWindowSelectionState: online friend on a different character updates className and classTag together
  do
    local runtime = makeRuntime({
      activeConversationKey = "bnet::BN::2",
      bnetApi = {
        GetAccountInfoByID = function(_id, _guid)
          return {
            isOnline = true,
            gameAccountInfo = {
              isOnline = true,
              characterName = "Newchar",
              realmName = "Area52",
              className = "Priest",
              playerGuid = "Player-1-2",
            },
          }
        end,
      },
      playerInfoByGUID = function(_guid)
        return "Priest", "PRIEST"
      end,
      store = {
        conversations = {
          ["bnet::BN::2"] = {
            channel = "BN",
            bnetAccountID = 2,
            guid = "Player-1-2",
            className = "Mage",
            classTag = "MAGE",
          },
        },
      },
    })
    local contacts = {
      {
        conversationKey = "bnet::BN::2",
        channel = "BN",
        bnetAccountID = 2,
        guid = "Player-1-2",
        className = "Mage",
        classTag = "MAGE",
      },
    }
    local result = ContactEnricher.BuildWindowSelectionState(runtime, contacts, nil)
    local selected = result.selectedContact
    assert(selected ~= nil, "selectedContact should exist")
    assert(selected.className == "Priest", "online friend updates className, got: " .. tostring(selected.className))
    assert(selected.classTag == "PRIEST", "online friend updates classTag alongside className, got: " .. tostring(selected.classTag))
    assert(selected.characterName == "Newchar", "online friend updates characterName, got: " .. tostring(selected.characterName))
    assert(selected.realm == "Area52", "online friend updates realm, got: " .. tostring(selected.realm))
  end

  -- BuildWindowSelectionState: online friend but classTag unresolvable leaves BOTH className and classTag untouched
  do
    local runtime = makeRuntime({
      activeConversationKey = "bnet::BN::3",
      bnetApi = {
        GetAccountInfoByID = function(_id, _guid)
          return {
            isOnline = true,
            gameAccountInfo = {
              isOnline = true,
              characterName = "Newchar",
              realmName = "Area52",
              className = "Priest",
              factionName = "Horde",
              areaName = "Orgrimmar",
              playerGuid = "Player-1-2",
            },
          }
        end,
      },
      playerInfoByGUID = function(_guid)
        return nil
      end,
      store = {
        conversations = {
          ["bnet::BN::3"] = {
            channel = "BN",
            bnetAccountID = 3,
            guid = "Player-1-2",
            className = "Mage",
            classTag = "MAGE",
          },
        },
      },
    })
    local contacts = {
      {
        conversationKey = "bnet::BN::3",
        channel = "BN",
        bnetAccountID = 3,
        guid = "Player-1-2",
        className = "Mage",
        classTag = "MAGE",
      },
    }
    local result = ContactEnricher.BuildWindowSelectionState(runtime, contacts, nil)
    local selected = result.selectedContact
    assert(selected ~= nil, "selectedContact should exist")
    assert(selected.className == "Mage", "unresolvable classTag leaves className untouched, got: " .. tostring(selected.className))
    assert(selected.classTag == "MAGE", "unresolvable classTag leaves classTag untouched, got: " .. tostring(selected.classTag))
    assert(selected.factionName == "Horde", "factionName still applies when classTag unresolvable, got: " .. tostring(selected.factionName))
    assert(selected.areaName == "Orgrimmar", "areaName still applies when classTag unresolvable, got: " .. tostring(selected.areaName))
  end

  -- EnrichContactsAvailability (row path): offline friend keeps stored class and zone
  do
    local runtime = makeRuntime({
      bnetApi = {
        GetAccountInfoByID = function(_id, _guid)
          return {
            isOnline = false,
            gameAccountInfo = {
              isOnline = false,
              characterName = nil,
              className = "Priest",
              areaName = "Orgrimmar",
              playerGuid = "Player-1-2",
            },
          }
        end,
      },
      playerInfoByGUID = function(_guid)
        return "Priest", "PRIEST", "Troll", "Troll"
      end,
    })
    local contacts = {
      {
        channel = "BN",
        bnetAccountID = 5,
        guid = "Player-1-2",
        className = "Mage",
        classTag = "MAGE",
      },
    }
    ContactEnricher.EnrichContactsAvailability(contacts, runtime)
    assert(contacts[1].className == "Mage", "row: offline friend keeps stored className, got: " .. tostring(contacts[1].className))
    assert(contacts[1].classTag == "MAGE", "row: offline friend keeps stored classTag, got: " .. tostring(contacts[1].classTag))
    assert(contacts[1].areaName == nil, "row: offline friend should not get stale areaName, got: " .. tostring(contacts[1].areaName))
    assert(
      contacts[1].availability.status == "Offline",
      "row: offline friend availability should be Offline, got: " .. tostring(contacts[1].availability.status)
    )
  end
end
