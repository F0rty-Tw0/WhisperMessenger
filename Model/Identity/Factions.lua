local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local Factions = {}

local ALLIANCE_RACES = {
  Human = true,
  Dwarf = true,
  NightElf = true,
  Gnome = true,
  Draenei = true,
  Worgen = true,
  VoidElf = true,
  LightforgedDraenei = true,
  DarkIronDwarf = true,
  KulTiran = true,
  Mechagnome = true,
}

local HORDE_RACES = {
  Orc = true,
  Scourge = true,
  Tauren = true,
  Troll = true,
  BloodElf = true,
  Goblin = true,
  Nightborne = true,
  HighmountainTauren = true,
  MagharOrc = true,
  ZandalariTroll = true,
  Vulpera = true,
}

function Factions.InferFaction(raceTag)
  if raceTag == nil then
    return nil
  end
  -- raceTag may be a WoW secret/tainted string during mythic lockdown;
  -- using it as a table index throws "table index is secret". Guard with pcall.
  local ok, isAlliance = pcall(function()
    return ALLIANCE_RACES[raceTag]
  end)
  if ok and isAlliance then
    return Localization.Text("Alliance")
  end
  local ok2, isHorde = pcall(function()
    return HORDE_RACES[raceTag]
  end)
  if ok2 and isHorde then
    return Localization.Text("Horde")
  end
  -- Pandaren, Dracthyr, Earthen, unknown future neutral races, or tainted values.
  return nil
end

ns.IdentityFactions = Factions

return Factions
