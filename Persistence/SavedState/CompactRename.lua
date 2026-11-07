local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local CompactRename = {}

-- Copies the saved keys of the old "phone" mode to their compact names, once at load.
-- An existing compact value wins; `false` counts as set. Nothing happens without an old key,
-- so an empty settings table stays empty (fresh-install detection reads it).
function CompactRename.Migrate(account, character)
  local settings = type(account) == "table" and account.settings
  if type(settings) == "table" and settings.phoneLayout ~= nil then
    if settings.compactLayout == nil then
      settings.compactLayout = settings.phoneLayout
    end
    settings.phoneLayout = nil
  end

  if type(character) == "table" and character.phoneWindow ~= nil then
    if type(character.phoneWindow) == "table" and character.compactWindow == nil then
      character.compactWindow = character.phoneWindow
    end
    character.phoneWindow = nil
  end
end

ns.SavedStateCompactRename = CompactRename
return CompactRename
