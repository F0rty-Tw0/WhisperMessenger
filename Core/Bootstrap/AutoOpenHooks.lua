local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local AutoOpenHooks = {}

function AutoOpenHooks.Create(deps)
  local hooks = {}

  local function shouldRouteToMessenger()
    -- Explicit whisper intent can route through the messenger, but combat still
    -- blocks a cold-open unless the window is already visible so the user does
    -- not get stranded mid-conversation.
    local isVisible = deps.isWindowVisible and deps.isWindowVisible() == true

    if deps.isCompetitive and deps.isCompetitive() and not isVisible then
      return false
    end

    if deps.isInCombat and deps.isInCombat() then
      if isVisible then
        return true
      end
      return false
    end
    return true
  end

  local function shouldRouteOutgoingToMessenger()
    if not shouldRouteToMessenger() then
      return false
    end

    local settings = deps.getSettings and deps.getSettings() or {}
    local isVisible = deps.isWindowVisible and deps.isWindowVisible() == true
    if settings.autoOpenOutgoing ~= true and not isVisible then
      return false
    end

    return true
  end

  local function openAndSelect(conversationKey, forceFocus)
    deps.ensureWindow()
    deps.setWindowVisible(true)
    -- A whisper the user started (send-tell, reply, outgoing) must land on
    -- screen, so close an addon panel or the options pane covering the chat.
    -- An incoming whisper leaves them: it must not pull the user off a panel.
    if forceFocus and deps.uncoverChat then
      deps.uncoverChat()
    end
    -- Every openAndSelect caller targets a whisper conversation (reply,
    -- send-tell, outgoing, incoming). When the messenger is currently on
    -- the Groups tab, a whisper would be invisible in the contact list,
    -- so force-switch to the Whispers tab first. Per-tab selection memory
    -- handles saving the group selection and will restore it on the next
    -- tab switch back.
    if deps.setTabMode then
      deps.setTabMode("whispers")
    end
    deps.selectConversation(conversationKey)
    if forceFocus then
      deps.focusComposer()
    end
  end

  function hooks.onIncomingWhisper(conversationKey)
    if not conversationKey then
      return
    end
    -- When the window is already open and the user is viewing a conversation,
    -- don't steal focus by switching to the new whisper's conversation.
    local isVisible = deps.isWindowVisible and deps.isWindowVisible()
    local activeKey = deps.getActiveConversationKey and deps.getActiveConversationKey()
    if isVisible and activeKey then
      return
    end
    openAndSelect(conversationKey, false)
  end

  function hooks.onReplyTell()
    if not shouldRouteToMessenger() then
      return false
    end
    -- Use the last incoming whisper key tracked by runtime
    local conversationKey = deps.getLastReplyKey and deps.getLastReplyKey()
    if not conversationKey then
      return false
    end
    openAndSelect(conversationKey, true)
    return true
  end

  local function sendTellKey(playerName)
    local conversationKey = deps.findConversationKeyByName(playerName)
    if not conversationKey and deps.buildConversationKeyFromName then
      conversationKey = deps.buildConversationKeyFromName(playerName)
    end
    return conversationKey
  end

  -- inHardwareEvent: the caller runs inside the player's click or key press,
  -- so the quiet /who may go out, and it goes before the selection changes.
  function hooks.onSendTell(playerName, inHardwareEvent)
    if not shouldRouteOutgoingToMessenger() then
      -- The game's chat keeps this whisper: the player is replying there, so
      -- an existing unread thread counts as read. Nothing is created.
      if playerName and deps.markRead then
        deps.markRead(deps.findConversationKeyByName(playerName))
      end
      return false
    end
    if not playerName then
      return false
    end
    local conversationKey = sendTellKey(playerName)
    if not conversationKey then
      return false
    end
    -- Ensure a conversation exists so the contact list shows the target
    if deps.ensureConversation then
      deps.ensureConversation(conversationKey, playerName)
    end
    if inHardwareEvent == true and deps.askWho then
      deps.askWho(conversationKey)
    end
    openAndSelect(conversationKey, true)
    return true
  end

  -- The game opens this whisper's chat a frame after the click, outside the
  -- click itself, so the quiet /who goes out now, before the chat exists.
  function hooks.askWhoForTell(playerName)
    if not playerName or not deps.askWhoForName or not shouldRouteOutgoingToMessenger() then
      return
    end
    local conversationKey = sendTellKey(playerName)
    if conversationKey then
      deps.askWhoForName(playerName, conversationKey)
    end
  end

  function hooks.onOutgoingWhisper(conversationKey)
    if not shouldRouteOutgoingToMessenger() then
      if deps.markRead then
        deps.markRead(conversationKey)
      end
      return false
    end
    if not conversationKey then
      return false
    end
    openAndSelect(conversationKey, true)
    return true
  end

  return hooks
end

ns.BootstrapAutoOpenHooks = AutoOpenHooks
return AutoOpenHooks
