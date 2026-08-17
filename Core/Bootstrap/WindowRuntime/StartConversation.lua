local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Identity = ns.Identity or require("WhisperMessenger.Model.Identity")
local Store = ns.ConversationStore or require("WhisperMessenger.Model.ConversationStore")

local StartConversation = {}

local function normalizePlayerName(playerName)
  if type(playerName) ~= "string" then
    return nil
  end

  local trimmed = string.match(playerName, "^%s*(.-)%s*$")
  if trimmed == "" then
    return nil
  end

  return trimmed
end

local function findExistingConversationKeyByName(runtime, playerName)
  return Identity.ResolveWhisperConversation(runtime, playerName, "WOW")
end

local function ensureWhisperConversation(runtime, conversationKey, displayName)
  runtime.store = runtime.store or {}

  local now = 0
  if type(runtime.now) == "function" then
    now = runtime.now()
  elseif type(_G.time) == "function" then
    now = _G.time()
  end

  return Store.EnsureConversation(runtime.store, conversationKey, {
    channel = "WOW",
    displayName = displayName,
    lastActivityAt = now,
  })
end

local function focusComposerInput(window, timer)
  if not (window and window.composer and window.composer.input and window.composer.input.SetFocus) then
    return
  end

  local input = window.composer.input
  input:SetFocus()

  -- Reissue on the next frame: OnShow / refresh / strata churn can steal
  -- focus away between this synchronous SetFocus and the first rendered
  -- frame. Reissuing once the layout settles keeps the input focused.
  if type(timer) == "table" and type(timer.After) == "function" then
    timer.After(0, function()
      if input and input.SetFocus then
        input:SetFocus()
      end
    end)
  end
end

function StartConversation.Create(options)
  options = options or {}

  local runtime = options.runtime
  local identity = options.identity or Identity
  local getWindow = options.getWindow or function()
    return nil
  end
  local selectConversation = options.selectConversation or function() end
  local timer = options.timer

  local function startConversation(playerName)
    local normalizedName = normalizePlayerName(playerName)
    if normalizedName == nil then
      return false
    end

    local conversationKey = findExistingConversationKeyByName(runtime, normalizedName)
    if conversationKey == nil then
      local who = identity.FromWhisper(normalizedName, nil, {})
      if who.canonicalName == "" then
        return false
      end

      conversationKey = identity.BuildConversationKey(runtime.localProfileId, who.contactKey)
      if type(conversationKey) ~= "string" or conversationKey == "" then
        return false
      end

      ensureWhisperConversation(runtime, conversationKey, normalizedName)
    end

    -- StartConversation always targets a whisper contact; make sure the
    -- Whispers tab is active so the new/existing conversation is visible.
    local window = getWindow()
    if window and type(window.setTabMode) == "function" then
      window.setTabMode("whispers")
    end
    selectConversation(conversationKey)
    focusComposerInput(window, timer or _G.C_Timer)
    return true
  end

  return {
    startConversation = startConversation,
    normalizePlayerName = normalizePlayerName,
    findExistingConversationKeyByName = function(playerName)
      return findExistingConversationKeyByName(runtime, playerName)
    end,
    ensureWhisperConversation = function(conversationKey, displayName)
      return ensureWhisperConversation(runtime, conversationKey, displayName)
    end,
  }
end

ns.BootstrapWindowRuntimeStartConversation = StartConversation

return StartConversation
