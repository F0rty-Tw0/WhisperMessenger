local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- Shared helpers for the chat-link source hooks. They only ever post-hook
-- through hooksecurefunc and skip anything the running flavor does not have.
local ChatLinkHookUtil = {}

function ChatLinkHookUtil.IsChatLinkClick()
  local isModifiedClick = _G.IsModifiedClick
  return type(isModifiedClick) == "function" and isModifiedClick("CHATLINK") == true
end

function ChatLinkHookUtil.HookGlobal(functionName, handler)
  if type(_G[functionName]) ~= "function" then
    return false
  end
  local ok = pcall(_G.hooksecurefunc, functionName, handler)
  return ok
end

-- Hooks a method on one table (a single named frame). A method copied onto
-- many frames through a mixin cannot be reached this way.
function ChatLinkHookUtil.HookMethod(target, methodName, handler)
  if type(target) ~= "table" or type(target[methodName]) ~= "function" then
    return false
  end
  local ok = pcall(_G.hooksecurefunc, target, methodName, handler)
  return ok
end

-- Runs callback once the named Blizzard addon has loaded (at once when it
-- already has). Every flavor has EventUtil.ContinueOnAddOnLoaded; without it
-- the callback runs at once and the hooks skip whatever is missing. Hooks are
-- registered while our composer is built, so a throw here (an addon the flavor
-- does not have, a hook that trips) is contained: that group just goes unhooked.
-- EventUtil may run the callback later from its own event handler, so the
-- callback carries its own pcall.
function ChatLinkHookUtil.OnAddOnLoaded(blizzardAddOn, callback)
  local eventUtil = _G.EventUtil
  if type(eventUtil) == "table" and type(eventUtil.ContinueOnAddOnLoaded) == "function" then
    pcall(eventUtil.ContinueOnAddOnLoaded, blizzardAddOn, function()
      pcall(callback)
    end)
    return
  end
  pcall(callback)
end

ns.ComposerChatLinkHookUtil = ChatLinkHookUtil
return ChatLinkHookUtil
