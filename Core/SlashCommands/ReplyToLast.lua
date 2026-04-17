local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- ReplyToLast: taint-safe /r replacement.
-- Routes through the messenger instead of Blizzard's chatEditLastTell.
--
-- Priority:
--   1. Live lastIncomingWhisperKey via onReplyTell (composer focus).
--   2. Most-recent conversation from our store (post-M+ resume,
--      fresh session, whispers received before addon loaded).
--   3. Fallback: toggle the messenger open so something happens.
--
-- In competitive content we skip onReplyTell (it bails for focus-
-- steal avoidance) and open+select directly so the user at least
-- sees the conversation context; composer stays disabled via the
-- mythic-pause notice.

local ReplyToLast = {}

function ReplyToLast.Create(deps)
  local runtime = deps.runtime
  local windowRuntime = deps.windowRuntime

  return function()
    local function scrubLeakedR()
      -- Safety-net for the R-override: on key-up after our macro focused
      -- the composer, the triggering keystroke can leak in as 'r'. One
      -- frame later, strip it if and only if the text is exactly "r" or
      -- "R" — so legitimate drafts are never touched.
      local timer = _G.C_Timer
      if type(timer) ~= "table" or type(timer.After) ~= "function" then
        return
      end
      timer.After(0, function()
        local window = runtime.window
        local input = window and window.composer and window.composer.input
        if input and input.GetText and input.SetText then
          local text = input:GetText() or ""
          if text == "r" or text == "R" then
            input:SetText("")
          end
        end
      end)
    end

    local hooks = runtime.autoOpenHooks
    if hooks and hooks.onReplyTell and hooks.onReplyTell() == true then
      scrubLeakedR()
      return
    end

    local key = runtime.lastIncomingWhisperKey
    if not key and runtime.store and runtime.store.conversations then
      local latest = -1
      for k, conv in pairs(runtime.store.conversations) do
        local activity = conv and conv.lastActivityAt or 0
        if activity > latest then
          latest = activity
          key = k
        end
      end
    end

    if key and runtime.ensureWindow and runtime.setWindowVisible then
      runtime.ensureWindow()
      runtime.setWindowVisible(true)
      if windowRuntime.selectConversation then
        windowRuntime.selectConversation(key)
      end
      scrubLeakedR()
      return
    end

    if runtime.toggle then
      runtime.toggle()
    end
    if type(_G.print) == "function" and not key then
      _G.print("|cff888888[WhisperMessenger]|r No conversations yet — opened the messenger.")
    end
  end
end

ns.SlashCommandsReplyToLast = ReplyToLast
return ReplyToLast
