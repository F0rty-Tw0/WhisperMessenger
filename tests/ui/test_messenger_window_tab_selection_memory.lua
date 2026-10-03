local ChannelType = require("WhisperMessenger.Model.Identity.ChannelType")
local TabSelectionMemory = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.TabSelectionMemory")

local function makeItem(channel, key, displayName)
  return { channel = channel, conversationKey = key, displayName = displayName }
end

return function()
  local contacts = {
    makeItem(ChannelType.WHISPER, "wow::WOW::Jaina", "Jaina"),
    makeItem(ChannelType.WHISPER, "wow::WOW::Thrall", "Thrall"),
    makeItem(ChannelType.PARTY, "PARTY::1", "Party"),
    makeItem(ChannelType.INSTANCE_CHAT, "INSTANCE::1", "Instance"),
  }

  local activeKey = "wow::WOW::Jaina"
  local currentContacts = contacts

  local function handleContactSelected(item)
    activeKey = item and item.conversationKey or nil
  end

  local memory = TabSelectionMemory.Create({
    getSelectedConversationKey = function()
      return activeKey
    end,
    getCurrentContacts = function()
      return currentContacts
    end,
    handleContactSelected = handleContactSelected,
    refreshSelection = function()
      activeKey = nil
    end,
  })

  memory.onTabModeSwapSelection("whispers", "groups")
  assert(activeKey == nil, "groups should clear when no remembered selection exists")

  memory.onSelect(contacts[3])
  assert(activeKey == "PARTY::1", "party should become active after group select")

  memory.onTabModeSwapSelection("groups", "whispers")
  assert(activeKey == "wow::WOW::Jaina", "whisper selection should restore on return")

  memory.onSelect(contacts[2])
  assert(activeKey == "wow::WOW::Thrall", "thrall should become active after whisper select")

  memory.onTabModeSwapSelection("whispers", "groups")
  assert(activeKey == "PARTY::1", "group selection should restore on return")

  memory.onTabModeSwapSelection("groups", "whispers")
  assert(activeKey == "wow::WOW::Thrall", "latest whisper selection should restore on return")

  -- test_channels_tab_remembers_its_own_selection
  local trade = { channel = ChannelType.CHANNEL, conversationKey = "CHANNEL::trade", displayName = "Trade", inChannelsTab = true }
  currentContacts[#currentContacts + 1] = trade
  memory.onTabModeSwapSelection("whispers", "channels")
  assert(activeKey == nil, "channels should clear when no remembered selection exists")
  memory.onSelect(trade)
  memory.onTabModeSwapSelection("channels", "groups")
  assert(activeKey == "PARTY::1", "groups keeps its own selection, not the channel chat")
  memory.onTabModeSwapSelection("groups", "channels")
  assert(activeKey == "CHANNEL::trade", "channel selection should restore on return")

  -- test_accepted_request_is_not_restored_on_the_requests_tab
  do
    -- Accepting moves the chat to Whispers; Requests then shows its empty
    -- state instead of the remembered chat.
    local stranger = makeItem(ChannelType.WHISPER, "wow::WOW::Chaos", "Chaos")
    stranger.isRequest = true
    local selected = nil
    local requestMemory = TabSelectionMemory.Create({
      getSelectedConversationKey = function()
        return selected
      end,
      getCurrentContacts = function()
        return { stranger }
      end,
      handleContactSelected = function(item)
        selected = item and item.conversationKey or nil
      end,
      refreshSelection = function()
        selected = nil
      end,
    })
    requestMemory.onSelect(stranger)
    stranger.isRequest = nil
    requestMemory.onTabModeSwapSelection("requests", "whispers")
    selected = nil
    requestMemory.onTabModeSwapSelection("whispers", "requests")
    assert(selected == nil, "Requests must not reopen a chat that moved to Whispers")

    -- The moved chat is forgotten for good, not just skipped once.
    stranger.isRequest = true
    requestMemory.onTabModeSwapSelection("requests", "whispers")
    requestMemory.onTabModeSwapSelection("whispers", "requests")
    assert(selected == nil, "Requests forgot the moved chat")
  end
end
