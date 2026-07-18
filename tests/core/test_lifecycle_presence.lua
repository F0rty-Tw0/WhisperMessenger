local Presence = require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers.Presence")

local function makeHarness(gameAccountInfo)
  local conversation = {
    channel = "BN",
    battleTag = "Friend#1234",
    gameAccountName = "Charname-Stormrage",
  }
  local Bootstrap = {
    runtime = {
      bnetApi = {},
      store = { conversations = { ["bn::friend"] = conversation } },
    },
  }
  local deps = {
    trace = function() end,
    loadModule = function()
      return {
        ScanFriendList = function()
          return {
            ["Friend#1234"] = {
              bnetAccountID = 42,
              accountInfo = { gameAccountInfo = gameAccountInfo },
            },
          }
        end,
      }
    end,
  }
  return Bootstrap, deps, conversation
end

return function()
  -- test_bnet_friend_update_applies_real_character_name
  do
    local Bootstrap, deps, conversation = makeHarness({
      characterName = "Newchar",
      realmName = "Area52",
    })

    Presence.handleBNetFriendEvent(Bootstrap, deps)

    assert(
      conversation.gameAccountName == "Newchar-Area52",
      "real character info updates the stored name; got: " .. tostring(conversation.gameAccountName)
    )
    assert(conversation.bnetAccountID == 42, "bnetAccountID refreshes from the friend list")
  end

  -- test_bnet_friend_offline_empty_strings_keep_stored_name
  do
    -- The BNet API reports empty strings (not nil) when the friend is not
    -- in WoW; those must not clobber the stored character name.
    local Bootstrap, deps, conversation = makeHarness({
      characterName = "",
      realmName = "",
    })

    Presence.handleBNetFriendEvent(Bootstrap, deps)

    assert(
      conversation.gameAccountName == "Charname-Stormrage",
      "empty characterName must not clobber the stored name; got: " .. tostring(conversation.gameAccountName)
    )
  end

  -- test_bnet_friend_missing_realm_stores_bare_character_name
  do
    local Bootstrap, deps, conversation = makeHarness({
      characterName = "Newchar",
      realmName = "",
    })

    Presence.handleBNetFriendEvent(Bootstrap, deps)

    assert(
      conversation.gameAccountName == "Newchar",
      "empty realmName stores the bare character name; got: " .. tostring(conversation.gameAccountName)
    )
  end
end
