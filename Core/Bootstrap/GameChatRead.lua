local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- stylua: ignore start
local Store = ns.ConversationStore or require("WhisperMessenger.Model.ConversationStore")
local GameWhisperTab = ns.BootstrapWindowRuntimeGameWhisperTab or require("WhisperMessenger.Core.Bootstrap.WindowRuntime.GameWhisperTab")
-- stylua: ignore end

-- A whisper dealt with in the game's own chat stops showing as unread here.
-- Everything is a post-hook or a read of the store: nothing is created, and
-- nothing runs inside the game's secure click path.
local GameChatRead = {}

local LEFT_BUTTON = "LeftButton"

local function hasUnread(conversation)
  return (conversation.unreadCount or 0) > 0 or conversation.hasUnreadMention == true
end

-- Marks an existing, unread conversation read and redraws. Returns whether it
-- changed anything; an unknown key never creates a conversation.
function GameChatRead.Mark(runtime, conversationKey)
  local conversation = Store.Find(runtime and runtime.store, conversationKey)
  if conversation == nil or not hasUnread(conversation) then
    return false
  end
  Store.MarkRead(runtime.store, conversationKey)
  if type(runtime.refreshWindow) == "function" then
    runtime.refreshWindow()
  end
  return true
end

local function chatFrameOf(tab)
  local ok, id = pcall(function()
    return tab:GetID()
  end)
  if not ok or id == nil then
    return nil
  end
  return _G["ChatFrame" .. tostring(id)]
end

local function isCompetitive(runtime)
  return type(runtime.isCompetitiveContent) == "function" and runtime.isCompetitiveContent() == true
end

-- With whispers hidden from game chat, a game whisper tab left open (from
-- content where WM lets whispers through) does not show newer whispers, so
-- clicking it is not reading them.
local function hidesWhispersFromGameChat(runtime)
  local settings = runtime.accountState and runtime.accountState.settings
  return type(settings) == "table" and settings.hideFromDefaultChat == true
end

-- Post-hooks the game's chat tab click: a left-click on a whisper tab means
-- the player is reading that partner's whispers there.
function GameChatRead.InstallTabHook(runtime, isSuspended)
  if type(_G.FCF_Tab_OnClick) ~= "function" or type(_G.hooksecurefunc) ~= "function" then
    return false
  end
  local function onTabClick(tab, button)
    if isSuspended() or isCompetitive(runtime) or hidesWhispersFromGameChat(runtime) then
      return
    end
    if button ~= nil and button ~= LEFT_BUTTON then
      return
    end
    local conversations = runtime.store and runtime.store.conversations
    GameChatRead.Mark(runtime, GameWhisperTab.ConversationKeyFor(chatFrameOf(tab), conversations))
  end
  return pcall(_G.hooksecurefunc, "FCF_Tab_OnClick", onTabClick)
end

ns.BootstrapGameChatRead = GameChatRead
return GameChatRead
