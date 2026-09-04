local Presence = require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers.Presence")

local function makeDeps(friendMap)
  return {
    loadModule = function(modulePath)
      if string.find(modulePath, "BNetResolver", 1, true) then
        return {
          ScanFriendList = function()
            return friendMap
          end,
        }
      end
      return require(modulePath)
    end,
  }
end

local function makeHarness(gameAccountInfo, playerInfoByGUID)
  local conversation = {
    channel = "BN",
    battleTag = "Friend#1234",
    className = "Mage",
    classTag = "MAGE",
  }
  local Bootstrap = {
    runtime = {
      bnetApi = {},
      store = { conversations = { ["bn::friend"] = conversation } },
      playerInfoByGUID = playerInfoByGUID,
    },
  }
  local deps = makeDeps({
    ["Friend#1234"] = {
      bnetAccountID = 42,
      accountInfo = { battleTag = "Friend#1234", gameAccountInfo = gameAccountInfo },
    },
  })
  return Bootstrap, deps, conversation
end

return function()
  -- Force the synchronous fallback path: without C_Timer the debounce runs
  -- the scan immediately, which the assertions below rely on.
  local savedCTimer = rawget(_G, "C_Timer")
  rawset(_G, "C_Timer", nil)

  -- friend in WoW persists className and classTag together
  do
    local Bootstrap, deps, conversation = makeHarness({
      characterName = "Newchar",
      realmName = "Area52",
      className = "Priest",
      playerGuid = "Player-1-2",
    }, function(_guid)
      return "Priest", "PRIEST"
    end)

    Presence.handleBNetFriendEvent(Bootstrap, deps)

    assert(conversation.className == "Priest", "class updates when friend is in WoW, got: " .. tostring(conversation.className))
    assert(conversation.classTag == "PRIEST", "classTag updates alongside className, got: " .. tostring(conversation.classTag))
  end

  -- friend not in WoW (empty characterName) keeps stored class pair
  do
    local Bootstrap, deps, conversation = makeHarness({
      characterName = "",
      className = "Priest",
      playerGuid = "Player-1-2",
    }, function(_guid)
      return "Priest", "PRIEST"
    end)

    Presence.handleBNetFriendEvent(Bootstrap, deps)

    assert(conversation.className == "Mage", "offline friend must not clobber stored className, got: " .. tostring(conversation.className))
    assert(conversation.classTag == "MAGE", "offline friend must not clobber stored classTag, got: " .. tostring(conversation.classTag))
  end

  -- friend in WoW but classTag unresolvable leaves the pair untouched
  do
    local Bootstrap, deps, conversation = makeHarness({
      characterName = "Newchar",
      className = "Priest",
      playerGuid = "Player-1-2",
    }, nil)

    Presence.handleBNetFriendEvent(Bootstrap, deps)

    assert(conversation.className == "Mage", "unresolvable classTag leaves className untouched, got: " .. tostring(conversation.className))
    assert(conversation.classTag == "MAGE", "unresolvable classTag leaves classTag untouched, got: " .. tostring(conversation.classTag))
  end

  rawset(_G, "C_Timer", savedCTimer)
end
