local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ContactsTabFilter = ns.ContactsTabFilter or require("WhisperMessenger.UI.ContactsList.ContactsTabFilter")

-- Keeps the pane's selection on the active tab. A chat that just stopped
-- being a message request (reply, reaction, Accept) is followed to Whispers;
-- any other off-tab selection is dropped.
local RequestFollow = {}

function RequestFollow.Create(getWindow, selectConversation)
  -- Keys that were message requests at the last refresh. Only a chat that
  -- just stopped being one follows to Whispers; a stale whisper selection
  -- never pulls the player off Requests.
  local requestKeys = {}
  local follow = {}

  -- Records this refresh's request keys and returns the previous ones.
  function follow.takeRequestKeys(contacts)
    local previous = requestKeys
    requestKeys = {}
    for _, item in ipairs(contacts) do
      if item.isRequest == true then
        requestKeys[item.conversationKey] = true
      end
    end
    return previous
  end

  -- Replying accepts a request, so the chat leaves the Requests tab: follow
  -- it to Whispers and keep it open, like Accept does.
  ---@param window table|nil
  local function followToWhispers(window, conversationKey)
    if selectConversation == nil or window == nil or type(window.setTabMode) ~= "function" then
      return nil
    end
    window.setTabMode("whispers")
    if window.getTabMode() ~= "whispers" then
      return nil
    end
    return selectConversation(conversationKey)
  end

  -- Guard against a stale `activeConversationKey` bleeding into the pane
  -- when it doesn't belong to the current tab. Per-tab memory clears the
  -- pane at the moment of swap, but the persistent key isn't reset — so a
  -- later refresh (incoming whisper, availability tick) would re-surface
  -- the off-tab conversation. Compare the selection's tab (whispers, groups
  -- or requests) with the active one and drop it on mismatch.
  -- Returns the state to show, plus true when the selection was followed to
  -- Whispers (that state then comes from selectConversation).
  function follow.reconcile(nextState, previousRequestKeys)
    local window = getWindow()
    local tabMode = window and type(window.getTabMode) == "function" and window.getTabMode() or nil
    local selectedMode = tabMode and nextState and nextState.selectedContact and ContactsTabFilter.ModeOf(nextState.selectedContact)
    if not selectedMode or selectedMode == tabMode then
      return nextState, false
    end
    local selectedKey = nextState.selectedContact.conversationKey
    if tabMode == "requests" and selectedMode == "whispers" and previousRequestKeys[selectedKey] then
      local followed = followToWhispers(window, selectedKey)
      if followed then
        return followed, true
      end
    end
    return { contacts = nextState.contacts }, false
  end

  return follow
end

ns.BootstrapWindowCoordinatorRequestFollow = RequestFollow
return RequestFollow
