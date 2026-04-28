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
end
