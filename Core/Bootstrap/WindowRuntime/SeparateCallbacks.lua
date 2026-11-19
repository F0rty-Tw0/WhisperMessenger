local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- The window's "Separate <Character>" callbacks: the characters folded into
-- a Battle.net chat, for the contact menu, and the split itself.
local CharacterSeparate = ns.CharacterSeparate or require("WhisperMessenger.Model.CharacterSeparate")
local CharacterMergeMap = ns.CharacterMergeMap or require("WhisperMessenger.Model.CharacterMergeMap")

local SeparateCallbacks = {}

function SeparateCallbacks.Create(runtime, refreshWindow)
  local function listMergedCharacters(bnetKey)
    if type(runtime.characterMerges) ~= "table" then
      return {}
    end
    return CharacterMergeMap.ListForBnet(runtime.characterMerges, bnetKey)
  end

  -- Only a full redraw rebuilds every contact row, so the character's row
  -- appears and the friend's row drops its preview. The open chat stays
  -- open; selecting it again would mark it read.
  local function onSeparateCharacter(bnetKey, characterKey)
    if type(runtime.characterMerges) ~= "table" then
      return
    end
    CharacterSeparate.Separate(runtime.store, runtime.characterMerges, bnetKey, characterKey)
    refreshWindow()
  end

  return { listMergedCharacters = listMergedCharacters, onSeparateCharacter = onSeparateCharacter }
end

ns.BootstrapWindowRuntimeSeparateCallbacks = SeparateCallbacks
return SeparateCallbacks
