local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local AutoOpenHooks = ns.BootstrapAutoOpenHooks or require("WhisperMessenger.Core.Bootstrap.AutoOpenHooks")
local Identity = ns.Identity or require("WhisperMessenger.Model.Identity")

local AutoOpenCoordinator = {}

local function findConversationKeyByName(runtime, name)
  if not name or not runtime.store or not runtime.store.conversations then
    return nil
  end

  local lowerName = string.lower(name)
  local inputBase = string.match(name, "^([^%-]+)")
  for key, conv in pairs(runtime.store.conversations) do
    local displayName = conv.displayName or conv.contactDisplayName or ""
    if string.lower(displayName) == lowerName then
      return key
    end

    local baseName = string.match(displayName, "^([^%-]+)")
    if baseName and string.lower(baseName) == lowerName then
      return key
    end

    if inputBase and string.lower(displayName) == string.lower(inputBase) then
      return key
    end

    if conv.battleTag and string.lower(conv.battleTag) == lowerName then
      return key
    end

    if conv.gameAccountName and string.lower(conv.gameAccountName) == lowerName then
      return key
    end
  end

  return nil
end

local function buildConversationKeyFromName(runtime, identity, name)
  local contact = identity.FromWhisper(name, nil, {})
  if contact.canonicalName == "" then
    return nil
  end

  return identity.BuildConversationKey(runtime.localProfileId, contact.contactKey)
end

local function ensureConversation(runtime, conversationKey, displayName)
  if not runtime.store then
    runtime.store = {}
  end
  runtime.store.conversations = runtime.store.conversations or {}

  if runtime.store.conversations[conversationKey] then
    return
  end

  runtime.store.conversations[conversationKey] = {
    displayName = displayName,
    channel = "WOW",
    messages = {},
    unreadCount = 0,
    lastActivityAt = runtime.now(),
    conversationKey = conversationKey,
  }
end

local function focusComposer(runtime)
  local window = runtime.window
  if window and window.composer and window.composer.input and window.composer.input.SetFocus then
    window.composer.input:SetFocus()
  end
end

local function readEditBoxState(editBox, key)
  local direct = editBox[key]
  if direct ~= nil and direct ~= "" then
    return direct
  end

  if type(editBox.GetAttribute) == "function" then
    local attribute = editBox:GetAttribute(key)
    if attribute ~= nil and attribute ~= "" then
      return attribute
    end
  end

  return nil
end

local function writeEditBoxState(editBox, key, value)
  editBox[key] = value
  if type(editBox.SetAttribute) == "function" then
    pcall(editBox.SetAttribute, editBox, key, value)
  end
end

local function closeEditBox(runtime, editBox, deactivateChat)
  local typed = editBox.GetText and editBox:GetText() or ""
  if typed ~= "" and runtime.setComposerText then
    runtime.setComposerText(typed)
  end

  local stickyType = readEditBoxState(editBox, "stickyType")
  if stickyType and stickyType ~= "WHISPER" and stickyType ~= "BN_WHISPER" then
    writeEditBoxState(editBox, "chatType", stickyType)
  end

  writeEditBoxState(editBox, "tellTarget", nil)
  editBox:SetText("")

  if type(deactivateChat) == "function" then
    deactivateChat(editBox)
  elseif editBox.Hide then
    editBox:Hide()
  end
end

local function findBattleNetAccountInfo(target, bnetApi, getNumFriends)
  if not bnetApi or not bnetApi.GetFriendAccountInfo then
    return nil
  end

  local numFriends = type(getNumFriends) == "function" and getNumFriends() or 0
  for friendIndex = 1, numFriends do
    local accountInfo = bnetApi.GetFriendAccountInfo(friendIndex)
    if accountInfo then
      local characterName = accountInfo.gameAccountInfo and accountInfo.gameAccountInfo.characterName
      local battleTag = accountInfo.battleTag
      local battleTagBase = battleTag and string.match(battleTag, "^([^#]+)")
      local accountName = accountInfo.accountName
      if
        (characterName and characterName == target)
        or (battleTag and battleTag == target)
        or (battleTagBase and battleTagBase == target)
        or (accountName and accountName == target)
      then
        return accountInfo
      end
    end
  end

  return nil
end

local function ensureBattleNetConversation(runtime, identity, accountInfo)
  local bnetAccountID = accountInfo and accountInfo.bnetAccountID
  if not bnetAccountID then
    return nil
  end

  if not runtime.store then
    runtime.store = {}
  end
  runtime.store.conversations = runtime.store.conversations or {}
  local conversations = runtime.store.conversations
  for key, conversation in pairs(conversations) do
    if conversation.bnetAccountID == bnetAccountID then
      return key
    end
  end

  local contact = identity.FromBattleNet(bnetAccountID, accountInfo)
  if contact.canonicalName == "" then
    return nil
  end

  local conversationKey = identity.BuildConversationKey(runtime.localProfileId, contact.contactKey)
  conversations[conversationKey] = {
    displayName = accountInfo.battleTag or accountInfo.accountName or tostring(bnetAccountID),
    channel = "BN",
    bnetAccountID = bnetAccountID,
    battleTag = accountInfo.battleTag,
    gameAccountName = accountInfo.gameAccountInfo and accountInfo.gameAccountInfo.characterName,
    messages = {},
    unreadCount = 0,
    lastActivityAt = runtime.now(),
    conversationKey = conversationKey,
  }

  return conversationKey
end

local function installPoller(runtime, hooks, deps)
  local createFrame = deps.createFrame
  if type(createFrame) ~= "function" then
    return nil
  end

  local pollFrame = createFrame("Frame")
  pollFrame:SetScript("OnUpdate", function()
    if deps.isSuspended() then
      return
    end

    local settings = runtime.accountState and runtime.accountState.settings
    if not settings or settings.autoOpenWindow ~= true then
      return
    end

    if deps.isInCombat() then
      return
    end

    for index = 1, deps.getNumChatWindows() do
      local editBox = deps.getEditBox(index)
      if editBox and editBox:HasFocus() then
        local text = editBox.GetText and editBox:GetText() or ""
        if string.sub(text, 1, 1) == "/" then
          local command = string.lower(string.match(text, "^(/[^%s]*)") or "")
          if command ~= "/w" and command ~= "/whisper" then
            return
          end
        end

        local chatType = readEditBoxState(editBox, "chatType")
        local target = readEditBoxState(editBox, "tellTarget")
        if chatType == "BN_WHISPER" and target then
          pcall(function()
            local accountInfo = findBattleNetAccountInfo(target, deps.bnetApi, deps.getNumFriends)
            if not accountInfo then
              return
            end

            local conversationKey = ensureBattleNetConversation(runtime, deps.identity, accountInfo)
            if conversationKey then
              hooks.onOutgoingWhisper(conversationKey)
              closeEditBox(runtime, editBox, deps.deactivateChat)
            end
          end)
          return
        end

        if chatType == "WHISPER" and target and target ~= "" then
          hooks.onSendTell(target)
          closeEditBox(runtime, editBox, deps.deactivateChat)
          return
        end
      end
    end
  end)

  if deps.trace then
    deps.trace("AutoOpen: edit box poll installed")
  end

  return pollFrame
end

function AutoOpenCoordinator.Attach(options)
  options = options or {}

  local runtime = options.runtime or {}
  local accountState = options.accountState or runtime.accountState or {}
  local windowRuntime = options.windowRuntime or {}
  local autoOpenHooksModule = options.AutoOpenHooks or AutoOpenHooks
  local identity = options.Identity or Identity
  local controller = {}

  local autoOpenHooks = autoOpenHooksModule.Create({
    trace = options.trace,
    getSettings = function()
      return accountState.settings
    end,
    isInCombat = options.isInCombat or function()
      return type(_G.InCombatLockdown) == "function" and _G.InCombatLockdown()
    end,
    ensureWindow = runtime.ensureWindow,
    setWindowVisible = runtime.setWindowVisible,
    selectConversation = windowRuntime.selectConversation,
    focusComposer = function()
      focusComposer(runtime)
    end,
    findConversationKeyByName = function(name)
      return findConversationKeyByName(runtime, name)
    end,
    buildConversationKeyFromName = function(name)
      return buildConversationKeyFromName(runtime, identity, name)
    end,
    ensureConversation = function(conversationKey, displayName)
      return ensureConversation(runtime, conversationKey, displayName)
    end,
    getLastReplyKey = function()
      return runtime.lastIncomingWhisperKey
    end,
  })

  runtime.onAutoOpen = autoOpenHooks.onIncomingWhisper
  runtime.onAutoOpenOutgoing = autoOpenHooks.onOutgoingWhisper
  runtime.autoOpenHooks = autoOpenHooks

  function controller.installPoller()
    return installPoller(runtime, autoOpenHooks, {
      trace = options.trace,
      identity = identity,
      createFrame = options.CreateFrame or _G.CreateFrame,
      isSuspended = options.isSuspended or function()
        return _G._wmSuspended == true
      end,
      isInCombat = options.isInCombat or function()
        return type(_G.InCombatLockdown) == "function" and _G.InCombatLockdown()
      end,
      getNumChatWindows = options.getNumChatWindows or function()
        return _G.NUM_CHAT_WINDOWS or 10
      end,
      getEditBox = options.getEditBox or function(index)
        return _G["ChatFrame" .. index .. "EditBox"]
      end,
      bnetApi = options.bnetApi or _G.C_BattleNet,
      getNumFriends = options.BNGetNumFriends
        or (
          type(_G.BNGetNumFriends) == "function" and _G.BNGetNumFriends or function()
            return 0, 0
          end
        ),
      deactivateChat = options.ChatEdit_DeactivateChat or _G.ChatEdit_DeactivateChat,
    })
  end

  function controller.installDeferredPoller()
    local timer = options.C_Timer or _G.C_Timer
    if not runtime.autoOpenHooks or type(timer) ~= "table" or type(timer.After) ~= "function" then
      return
    end

    timer.After(0, function()
      controller.installPoller()
    end)
  end

  runtime.autoOpenCoordinator = controller

  return controller
end

ns.BootstrapAutoOpenCoordinator = AutoOpenCoordinator
return AutoOpenCoordinator
