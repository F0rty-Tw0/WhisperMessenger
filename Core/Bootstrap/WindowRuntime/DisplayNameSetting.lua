local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- Pushes the settings that change how sender names look into DisplayName.
local DisplayNameSetting = {}

-- Returns true when key is a display name setting and was applied.
function DisplayNameSetting.Apply(displayName, key, value)
  if not (displayName and displayName.Configure) then
    return false
  end
  if key == "hideBattleTagNumbers" then
    displayName.Configure({ hideBattleTagNumbers = value ~= false })
    return true
  end
  if key == "classColorSenderNames" then
    displayName.Configure({ classColorSenderNames = value ~= false })
    return true
  end
  if key == "showPlayerLevels" then
    displayName.Configure({ showPlayerLevels = value == true })
    return true
  end
  return false
end

ns.BootstrapWindowRuntimeDisplayNameSetting = DisplayNameSetting
return DisplayNameSetting
