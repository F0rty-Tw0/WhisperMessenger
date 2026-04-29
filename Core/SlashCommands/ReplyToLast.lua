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

local function isWhisperConversation(conv)
  if type(conv) ~= "table" then
    return false
  end
  local channel = conv.channel
  -- Legacy conversations predate the channel field; assume whisper so old
  -- stored history remains reply-reachable.
  if channel == nil then
    return true
  end
  return channel == "WHISPER" or channel == "BN_WHISPER"
end

function ReplyToLast.Create(deps)
  local runtime = deps.runtime
  local windowRuntime = deps.windowRuntime

  local function focusComposerInput()
    local window = runtime.window
    local input = window and window.composer and window.composer.input
    if not (input and input.SetFocus) then
      return
    end

    input:SetFocus()

    local timer = _G.C_Timer
    if type(timer) == "table" and type(timer.After) == "function" then
      timer.After(0, function()
        if input and input.SetFocus then
          input:SetFocus()
        end
      end)
    end
  end

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
      -- Reply is a whisper-only action. Filter out group conversations so a
      -- recently-chatty party/guild doesn't hijack the reply target when the
      -- user hasn't received a whisper yet this session.
      local latest = -1
      for k, conv in pairs(runtime.store.conversations) do
        if isWhisperConversation(conv) then
          local activity = conv and conv.lastActivityAt or 0
          if activity > latest then
            latest = activity
            key = k
          end
        end
      end
    end

    if key and runtime.ensureWindow and runtime.setWindowVisible then
      runtime.ensureWindow()
      runtime.setWindowVisible(true)
      -- Force the Whispers tab so the target conversation is actually
      -- visible when the user was sitting on Groups.
      local window = runtime.window
      if window and type(window.setTabMode) == "function" then
        window.setTabMode("whispers")
      end
      if windowRuntime.selectConversation then
        windowRuntime.selectConversation(key)
      end
      focusComposerInput()
      scrubLeakedR()
      return
    end

    if runtime.toggle then
      runtime.toggle()
    end
  end
end

ns.SlashCommandsReplyToLast = ReplyToLast
return ReplyToLast
