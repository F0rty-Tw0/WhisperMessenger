-- Tests that dungeon/competitive chat-log messages and related notices
-- are routed through Localization and produce Russian strings in ruRU mode.
local Localization = require("WhisperMessenger.Locale.Localization")

-- Stubs shared across sub-tests
local function makeRuntime()
  return {
    messagingNotice = nil,
    accountState = { settings = {} },
    syncReplyKey = nil,
    suspend = nil,
    resume = nil,
  }
end

return function()
  -- ── test_competitive_notice_localizes ────────────────────────────────────
  do
    Localization.Configure({ language = "ruRU" })

    local Common = require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers.Common")
    local runtime = makeRuntime()
    local Bootstrap = {
      _inEncounter = true,
      _inCompetitiveContent = false,
      _inMythicContent = false,
      runtime = runtime,
      onCompetitiveStateChanged = nil,
    }

    Common.notifyCompetitiveState(Bootstrap)

    assert(type(runtime.messagingNotice) == "string" and runtime.messagingNotice ~= "", "messagingNotice should be a non-empty string")
    assert(
      string.find(runtime.messagingNotice, "соревновательном", 1, true),
      "competitive notice should be in Russian, got: " .. tostring(runtime.messagingNotice)
    )

    Localization.Configure({ language = "enUS" })
  end

  -- ── test_mythic_suspend_print_localizes ──────────────────────────────────
  do
    Localization.Configure({ language = "ruRU" })

    local MythicSuspendController = require("WhisperMessenger.Core.Bootstrap.MythicSuspendController")
    local printed = {}
    local runtime = makeRuntime()
    local Bootstrap = {}

    MythicSuspendController.Attach(runtime, {
      Bootstrap = Bootstrap,
      print = function(msg)
        table.insert(printed, msg)
      end,
      getEventBridge = function()
        return nil
      end,
      mythicPauseNotice = nil,
    })

    runtime.suspend()

    assert(#printed >= 1, "suspend should print at least one message")
    assert(
      string.find(printed[1], "мифическ", 1, true) or string.find(printed[1], "Приостановлено", 1, true),
      "suspend print should be in Russian, got: " .. tostring(printed[1])
    )
    assert(
      string.find(runtime.messagingNotice, "мифическ", 1, true),
      "messagingNotice should be in Russian after suspend, got: " .. tostring(runtime.messagingNotice)
    )

    Localization.Configure({ language = "enUS" })
  end

  -- ── test_mythic_resume_print_localizes ───────────────────────────────────
  do
    Localization.Configure({ language = "ruRU" })

    local MythicSuspendController = require("WhisperMessenger.Core.Bootstrap.MythicSuspendController")
    local printed = {}
    local runtime = makeRuntime()
    local Bootstrap = {}

    MythicSuspendController.Attach(runtime, {
      Bootstrap = Bootstrap,
      print = function(msg)
        table.insert(printed, msg)
      end,
      getEventBridge = function()
        return nil
      end,
    })

    runtime.resume()

    assert(#printed >= 1, "resume should print at least one message")
    assert(string.find(printed[1], "Возобновлено", 1, true), "resume print should be in Russian, got: " .. tostring(printed[1]))

    Localization.Configure({ language = "enUS" })
  end

  -- ── test_left_group_messages_localize ────────────────────────────────────
  do
    Localization.Configure({ language = "ruRU" })

    local GroupMembership = require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers.GroupMembership")

    -- exercise appendLeftMessage via handleGroupRosterUpdate with a fake state
    -- that simulates leaving PARTY
    local profileId = "jaina-proudmoore"
    local conv = { messages = {}, leftGroup = nil }
    local accountState = {
      conversations = { ["party::" .. profileId] = conv },
      settings = {},
    }

    rawset(_G, "IsInGroup", function(_cat)
      return false
    end)
    rawset(_G, "IsInRaid", function()
      return false
    end)
    rawset(_G, "LE_PARTY_CATEGORY_HOME", 1)
    rawset(_G, "LE_PARTY_CATEGORY_INSTANCE", 2)
    rawset(_G, "time", function()
      return 0
    end)

    local Bootstrap = {
      runtime = {
        accountState = accountState,
        localProfileId = profileId,
        refreshWindow = function() end,
      },
    }

    GroupMembership.handleGroupRosterUpdate(Bootstrap, {
      trace = function() end,
    })

    local found = false
    for _, msg in ipairs(conv.messages or {}) do
      if msg.kind == "system" and string.find(msg.text, "Покинул", 1, true) then
        found = true
        break
      end
    end
    assert(found, "left-group system message should be in Russian")

    Localization.Configure({ language = "enUS" })
  end
end
