local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- One pending reply target per conversation, like drafts: switching
-- conversations swaps it, it never follows the player to another contact.
-- Session-only; a /reload drops it.
local ReplyState = {}

-- getKey(): the open conversation key. onChanged(replyTo | nil) redraws.
function ReplyState.Create(getKey, onChanged)
  local targets = {}
  local state = {}

  function state.current()
    local key = getKey()
    return key ~= nil and targets[key] or nil
  end

  function state.sync()
    if type(onChanged) == "function" then
      onChanged(state.current())
    end
  end

  function state.set(key, replyTo)
    if key == nil then
      return
    end
    targets[key] = replyTo
    if key == getKey() then
      state.sync()
    end
  end

  function state.clear()
    local key = getKey()
    if key ~= nil and targets[key] ~= nil then
      targets[key] = nil
      state.sync()
    end
  end

  return state
end

ns.ComposerReplyState = ReplyState
return ReplyState
