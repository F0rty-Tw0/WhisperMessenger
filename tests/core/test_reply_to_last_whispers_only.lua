-- Regression: pressing Reply while a group chat is the most recently active
-- conversation (or is currently selected) must route to the last whisper, not
-- the group. Reply is a whisper-only action.

local ReplyToLast = require("WhisperMessenger.Core.SlashCommands.ReplyToLast")

return function()
  local function makeDeps(opts)
    opts = opts or {}
    local selectCalls = {}
    local tabCalls = {}
    local ensureCalls = 0
    local visibleCalls = {}
    local focusCalls = 0

    local window = {
      setTabMode = function(mode)
        table.insert(tabCalls, mode)
      end,
      composer = {
        input = {
          SetFocus = function()
            focusCalls = focusCalls + 1
          end,
        },
      },
    }

    local runtime = {
      window = window,
      autoOpenHooks = nil, -- force the fallback path; onReplyTell is covered elsewhere
      store = { conversations = opts.conversations or {} },
      lastIncomingWhisperKey = opts.lastIncomingWhisperKey,
      ensureWindow = function()
        ensureCalls = ensureCalls + 1
      end,
      setWindowVisible = function(v)
        table.insert(visibleCalls, v)
      end,
      toggle = function() end,
    }

    local windowRuntime = {
      selectConversation = function(key)
        table.insert(selectCalls, key)
      end,
    }

    return {
      runtime = runtime,
      windowRuntime = windowRuntime,
      selectCalls = selectCalls,
      tabCalls = tabCalls,
      focusCalls = function()
        return focusCalls
      end,
    }
  end

  -- A group is the most recently active conversation. Reply has no
  -- lastIncomingWhisperKey yet — it must pick the most recent *whisper*,
  -- not the group.
  do
    local conversations = {
      ["party::arthas-area52"] = { lastActivityAt = 2000, channel = "PARTY" },
      ["guild::MyGuild"] = { lastActivityAt = 1500, channel = "GUILD" },
      ["wow::WOW::jaina-proudmoore"] = { lastActivityAt = 1000, channel = "WOW" },
      ["wow::WOW::thrall-draenor"] = { lastActivityAt = 800, channel = "WOW" },
    }
    local deps = makeDeps({ conversations = conversations })
    local replyFn = ReplyToLast.Create(deps)

    replyFn()

    assert(#deps.selectCalls == 1, "expected exactly one selectConversation call, got " .. #deps.selectCalls)
    assert(
      deps.selectCalls[1] == "wow::WOW::jaina-proudmoore",
      "expected Reply to pick the most recent whisper, got: " .. tostring(deps.selectCalls[1])
    )
    assert(deps.tabCalls[1] == "whispers", "expected Reply to switch to the Whispers tab")
    assert(deps.focusCalls() >= 1, "expected Reply fallback to focus composer input for latest whisper")
  end

  -- When lastIncomingWhisperKey is set, Reply uses it AND still forces the
  -- Whispers tab — otherwise the user stays stuck on Groups.
  do
    local conversations = {
      ["party::arthas-area52"] = { lastActivityAt = 9999, channel = "PARTY" },
      ["wow::WOW::jaina-proudmoore"] = { lastActivityAt = 500, channel = "WOW" },
    }
    local deps = makeDeps({
      conversations = conversations,
      lastIncomingWhisperKey = "wow::WOW::jaina-proudmoore",
    })
    local replyFn = ReplyToLast.Create(deps)

    replyFn()

    assert(deps.selectCalls[1] == "wow::WOW::jaina-proudmoore", "expected tracked last-incoming whisper to be selected")
    assert(deps.tabCalls[1] == "whispers", "expected Whispers tab to be forced even with tracked key")
    assert(deps.focusCalls() >= 1, "expected Reply fallback to focus composer input for tracked last whisper")
  end

  -- Only groups exist, no whispers: fall through to toggle — do not select a
  -- group conversation on a reply command, and do not spam the chat frame.
  do
    local conversations = {
      ["party::arthas-area52"] = { lastActivityAt = 2000, channel = "PARTY" },
      ["guild::MyGuild"] = { lastActivityAt = 1500, channel = "GUILD" },
    }
    local deps = makeDeps({ conversations = conversations })
    local replyFn = ReplyToLast.Create(deps)

    local printed = {}
    local previousPrint = _G.print
    _G.print = function(msg)
      table.insert(printed, msg)
    end

    replyFn()

    _G.print = previousPrint

    assert(#deps.selectCalls == 0, "Reply must not select a group when no whispers exist")
    assert(#printed == 0, "Reply must not print to chat on the fallback path, got: " .. tostring(printed[1]))
    assert(deps.focusCalls() == 0, "Reply must not focus composer when no whisper target exists")
  end
end
