local addonName, ns = ...
if type(ns) ~= "table" then ns = {} end

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
  if ALLIANCE_RACES[raceTag] then return "Alliance" end
  if HORDE_RACES[raceTag] then return "Horde" end
  -- Pandaren, Dracthyr, Earthen, and unknown future neutral races are ambiguous here.
  return nil
end

ns.IdentityFactions = Factions

return Factions
