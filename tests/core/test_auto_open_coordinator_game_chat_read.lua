local AutoOpenCoordinator = require("WhisperMessenger.Core.Bootstrap.AutoOpenCoordinator")

-- Wires the game-chat "read" signals: the hooks' markRead dep and the game
-- whisper tab hook that installPoller adds.
return function()
  local SAVED = { "hooksecurefunc", "FCF_Tab_OnClick", "ChatFrame3" }
  local saved = {}
  for _, key in ipairs(SAVED) do
    saved[key] = rawget(_G, key)
  end

  local function attach(isSuspended)
    local hookedFns = {}
    rawset(_G, "hooksecurefunc", function(name, fn)
      hookedFns[name] = fn
    end)
    rawset(_G, "FCF_Tab_OnClick", function() end)
    rawset(_G, "ChatFrame3", { isTemporary = true, chatType = "WHISPER", chatTarget = "Thrall" })
    local hookDeps
    local runtime = {
      store = { conversations = { ["wow::WOW::thrall"] = { channel = "WOW", unreadCount = 2 } } },
      refreshWindow = function() end,
    }
    local controller = AutoOpenCoordinator.Attach({
      runtime = runtime,
      accountState = {},
      windowRuntime = {},
      isSuspended = isSuspended,
      getNumChatWindows = function()
        return 0
      end,
      AutoOpenHooks = {
        Create = function(deps)
          hookDeps = deps
          return {}
        end,
      },
    })
    controller.installPoller()
    return runtime, hookDeps, hookedFns
  end

  -- test_mark_read_dep_clears_existing_unread_conversation
  do
    local runtime, hookDeps = attach()
    hookDeps.markRead("wow::WOW::thrall")
    assert(runtime.store.conversations["wow::WOW::thrall"].unreadCount == 0, "markRead dep marks the conversation read")
  end

  -- test_install_poller_hooks_the_game_tab_click
  do
    local runtime, _, hookedFns = attach()
    assert(type(hookedFns.FCF_Tab_OnClick) == "function", "installPoller post-hooks FCF_Tab_OnClick")
    hookedFns.FCF_Tab_OnClick({
      GetID = function()
        return 3
      end,
    }, "LeftButton")
    assert(runtime.store.conversations["wow::WOW::thrall"].unreadCount == 0, "a tab click reaches the store")
  end

  -- test_tab_hook_follows_the_suspended_switch
  do
    local runtime, _, hookedFns = attach(function()
      return true
    end)
    hookedFns.FCF_Tab_OnClick({
      GetID = function()
        return 3
      end,
    }, "LeftButton")
    assert(runtime.store.conversations["wow::WOW::thrall"].unreadCount == 2, "the same suspended switch gates the tab hook")
  end

  for _, key in ipairs(SAVED) do
    rawset(_G, key, saved[key])
  end
end
