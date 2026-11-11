local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Identity = ns.Identity or require("WhisperMessenger.Model.Identity")
local SecretValue = ns.SecretValue or require("WhisperMessenger.Util.SecretValue")

-- Closes the game's own temporary whisper tab for a conversation. The game
-- opens one per whisper partner when whispers pop out into new tabs; such a
-- frame has isTemporary, chatType WHISPER / BN_WHISPER and chatTarget = the
-- partner (character name, or the Battle.net account name for BN).
-- Player-made chat windows (not temporary) are never touched.
local GameWhisperTab = {}

local CHAT_TYPE_BY_CHANNEL = {
  WOW = "WHISPER",
  BN = "BN_WHISPER",
}

local WOW_KEY_PREFIX = "^wow::WOW::(.+)$"

-- Lowercased, same-realm realm dropped (the game's names may carry it,
-- WhisperMessenger's keys don't). nil for anything not comparable.
local function comparable(value)
  if SecretValue.Is(value) or type(value) ~= "string" or value == "" then
    return nil
  end
  local ok, lowered = pcall(string.lower, Identity.ShortName(value))
  if ok and type(lowered) == "string" then
    return lowered
  end
  return nil
end

local function battleNetAccountName(bnetAccountID)
  local bnetApi = _G.C_BattleNet
  if bnetAccountID == nil or type(bnetApi) ~= "table" or type(bnetApi.GetAccountInfoByID) ~= "function" then
    return nil
  end
  local ok, accountInfo = pcall(bnetApi.GetAccountInfoByID, bnetAccountID)
  return ok and type(accountInfo) == "table" and accountInfo.accountName or nil
end

local function targetsFor(conversationKey, conversation)
  local targets = {}
  local function add(value)
    local target = comparable(value)
    if target then
      targets[target] = true
    end
  end
  if conversation.channel == "BN" then
    add(battleNetAccountName(conversation.bnetAccountID))
    add(conversation.battleTag)
  elseif type(conversationKey) == "string" then
    add(string.match(conversationKey, WOW_KEY_PREFIX))
  end
  return targets
end

local function isOpenWhisperTab(frame, chatType)
  if type(frame) ~= "table" or SecretValue.Is(frame.chatType) then
    return false
  end
  return frame.isTemporary == true and frame.inUse ~= false and frame.chatType == chatType
end

function GameWhisperTab.CloseFor(conversationKey, conversation)
  local frameNames = _G.CHAT_FRAMES
  -- The game's own Close for whisper tabs is PopIn: it also lets the main
  -- chat show that player's whispers again. FCF_Close is the fallback.
  local close = _G.FCF_PopInWindow
  if type(close) ~= "function" then
    close = _G.FCF_Close
  end
  if type(conversation) ~= "table" or type(frameNames) ~= "table" or type(close) ~= "function" then
    return
  end
  local chatType = CHAT_TYPE_BY_CHANNEL[conversation.channel]
  if chatType == nil then
    return
  end
  local targets = targetsFor(conversationKey, conversation)
  for _, frameName in ipairs(frameNames) do
    local frame = _G[frameName]
    if isOpenWhisperTab(frame, chatType) then
      local target = comparable(frame.chatTarget)
      if target and targets[target] then
        pcall(close, frame)
      end
    end
  end
end

-- The key of the conversation a game whisper tab belongs to, or nil. The tab's
-- chat type must match the conversation's channel, so a character tab "X"
-- never matches a Battle.net conversation whose account is called X.
function GameWhisperTab.ConversationKeyFor(frame, conversations)
  if type(frame) ~= "table" or type(conversations) ~= "table" then
    return nil
  end
  local target = comparable(frame.chatTarget)
  if target == nil then
    return nil
  end
  for conversationKey, conversation in pairs(conversations) do
    local chatType = type(conversation) == "table" and CHAT_TYPE_BY_CHANNEL[conversation.channel] or nil
    if chatType ~= nil and isOpenWhisperTab(frame, chatType) and targetsFor(conversationKey, conversation)[target] then
      return conversationKey
    end
  end
  return nil
end

ns.BootstrapWindowRuntimeGameWhisperTab = GameWhisperTab
return GameWhisperTab
