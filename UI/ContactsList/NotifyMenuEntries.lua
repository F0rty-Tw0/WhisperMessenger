local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local OnlineWatch = ns.OnlineWatch or require("WhisperMessenger.Model.OnlineWatch")
local ZoneWatch = ns.ZoneWatch or require("WhisperMessenger.Model.ZoneWatch")

-- "Notify when online" and "Notify when they change zone" in the whisper-row
-- menu: checkboxes (plain buttons on clients without one), each shown only
-- where WoW reports what it watches.
local NotifyMenuEntries = {}

local function addCheckbox(rootDescription, label, initial, onToggle)
  -- item is a snapshot that the save doesn't update, and the menu stays open
  -- after a checkbox click, so track the ticked state here.
  local enabled = initial
  local function toggle()
    enabled = not enabled
    onToggle(enabled)
  end
  if type(rootDescription.CreateCheckbox) == "function" then
    rootDescription:CreateCheckbox(label, function()
      return enabled
    end, toggle)
  else
    rootDescription:CreateButton(label, toggle)
  end
end

function NotifyMenuEntries.Add(rootDescription, item, onUpdatePrefs)
  if OnlineWatch.CanWatch(item, _G.C_FriendList) then
    addCheckbox(rootDescription, Localization.Text("Notify when online"), item.notifyOnline == true, function(enabled)
      onUpdatePrefs(item, { notifyOnline = enabled })
    end)
  end
  if ZoneWatch.CanWatch(item) then
    addCheckbox(rootDescription, Localization.Text("Notify when they change zone"), item.notifyZone == true, function(enabled)
      onUpdatePrefs(item, { notifyZone = enabled })
    end)
  end
end

ns.ContactsListNotifyMenuEntries = NotifyMenuEntries
return NotifyMenuEntries
