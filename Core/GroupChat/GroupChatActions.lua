local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local GroupChats = ns.GroupChats or require("WhisperMessenger.Model.GroupChats")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local ChatPrint = ns.ChatPrint or require("WhisperMessenger.Util.ChatPrint")

-- What the player does with group chats from the window, the contact menu
-- and "/wmsg group": each action runs on the service, reports a refusal in
-- the chat frame and redraws or opens the window.
local GroupChatActions = {}

local function groupIdOf(item)
  return type(item) == "table" and GroupChats.IdFromConversationKey(item.conversationKey) or nil
end

-- deps: runtime, service (GroupChatService), windowRuntime
-- (selectConversation), print (defaults to ChatPrint.Print).
function GroupChatActions.Create(deps)
  local runtime = deps.runtime or {}
  local service = deps.service
  local windowRuntime = deps.windowRuntime or {}
  local print = deps.print or ChatPrint.Print

  local actions = {}

  local function refresh(conversationKey)
    if type(runtime.refreshWindow) == "function" then
      runtime.refreshWindow(conversationKey)
    end
  end

  local function report(reason)
    if type(reason) == "string" and reason ~= "" then
      print(reason)
    end
  end

  -- Shows the window on the Groups tab with the chat selected.
  function actions.Open(conversationKey)
    if type(runtime.ensureWindow) == "function" then
      runtime.ensureWindow()
    end
    if type(runtime.setWindowVisible) == "function" then
      runtime.setWindowVisible(true)
    end
    local window = runtime.window
    if window and type(window.setTabMode) == "function" then
      window.setTabMode("groups")
    end
    if type(windowRuntime.selectConversation) == "function" then
      windowRuntime.selectConversation(conversationKey)
    else
      refresh(conversationKey)
    end
  end

  function actions.CreateAndOpen(namesText)
    local conversationKey, reason = service.Create(namesText)
    if conversationKey == nil then
      report(reason)
      return false
    end
    actions.Open(conversationKey)
    return true
  end

  function actions.AddMembers(item, namesText)
    local count, reason = service.AddMembers(groupIdOf(item), namesText)
    if count == nil then
      report(reason)
      return false
    end
    refresh(item.conversationKey)
    return true
  end

  function actions.Rename(item, name)
    if not service.Rename(groupIdOf(item), name) then
      return false
    end
    refresh(item.conversationKey)
    return true
  end

  function actions.Leave(item)
    if not service.Leave(groupIdOf(item)) then
      return false
    end
    refresh(item.conversationKey)
    return true
  end

  function actions.CanManage(item)
    local group = GroupChats.Find(service.registry, groupIdOf(item))
    return group ~= nil and group.left ~= true
  end

  -- "/wmsg group Anna, Bela-Kazzak"
  function actions.SlashCommand(rest)
    if type(rest) ~= "string" or string.match(rest, "^%s*$") then
      report(Localization.Text("To start a group chat: /wmsg group Name, Name-Realm"))
      return false
    end
    return actions.CreateAndOpen(rest)
  end

  return actions
end

ns.GroupChatActions = GroupChatActions
return GroupChatActions
