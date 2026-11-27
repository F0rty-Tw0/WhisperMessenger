local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Store = ns.ConversationStore or require("WhisperMessenger.Model.ConversationStore")
local ChannelMessageStore = ns.ChannelMessageStore or require("WhisperMessenger.Model.ChannelMessageStore")

local Logout = {}

-- "Clear on logout" leaves no chat history in the saved variables.
function Logout.handlePlayerLogout(Bootstrap)
  local runtime = Bootstrap.runtime
  local settings = runtime and runtime.accountState and runtime.accountState.settings
  if not (settings and settings.clearOnLogout) then
    return true
  end

  -- The removal hook clears a selection together with its chat; a saved
  -- selection can also name a chat that expired while offline.
  runtime.activeConversationKey = nil
  if runtime.characterState then
    runtime.characterState.activeConversationKey = nil
  end
  -- Channel lines kept to show above a new whisper are saved history too.
  if runtime.channelMessageStore then
    ChannelMessageStore.Clear(runtime.channelMessageStore)
  end
  -- The hook runs session cleanup per chat. If any of it fails, the chats
  -- must still not reach the saved variables, so drop what is left.
  pcall(Store.RemoveAll, runtime.store)
  local conversations = runtime.store.conversations
  for key in pairs(conversations) do
    conversations[key] = nil
  end
  return true
end

ns.BootstrapLifecycleHandlersLogout = Logout
return Logout
