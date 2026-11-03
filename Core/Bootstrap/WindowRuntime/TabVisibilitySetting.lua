local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ConversationSnapshot = ns.ConversationSnapshot or require("WhisperMessenger.Model.ConversationSnapshot")

-- Settings that show or hide a contacts tab. Turning a tab off while it is
-- open falls back to the whispers tab.
local TabVisibilitySetting = {}

local function leaveTab(window, tabMode)
  if window and window.getTabMode and window.getTabMode() == tabMode and window.setTabMode then
    window.setTabMode("whispers")
  end
end

local function refreshToggles(window)
  if window and window.refreshTabToggleVisibility then
    window.refreshTabToggleVisibility()
  end
end

local function refreshWindow(runtime)
  if runtime.refreshWindow then
    runtime.refreshWindow()
  end
end

-- Applies key when it is a tab visibility setting; other keys are ignored.
function TabVisibilitySetting.Apply(runtime, accountSettings, key, value)
  local window = runtime.window
  if key == "showGroupChats" then
    if value == false then
      leaveTab(window, "groups")
    end
    refreshToggles(window)
    refreshWindow(runtime)
  elseif key == "requestsInbox" then
    if value ~= true then
      leaveTab(window, "requests")
    end
    refreshToggles(window)
    refreshWindow(runtime)
  elseif key == "enabledChannels" then
    if not ConversationSnapshot.HasChannelsTab(accountSettings) then
      leaveTab(window, "channels")
    end
    refreshToggles(window)
  end
end

ns.BootstrapWindowRuntimeTabVisibilitySetting = TabVisibilitySetting

return TabVisibilitySetting
