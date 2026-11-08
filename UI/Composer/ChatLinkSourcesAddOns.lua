local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Util = ns.ComposerChatLinkHookUtil or require("WhisperMessenger.UI.Composer.ChatLinkHookUtil")

-- Chat-link sources that live in Blizzard addons loaded later (some only on
-- demand). Each group hooks once its addon has loaded; see ChatLinkSources for
-- why these post-hooks exist and what they cannot stop.
local ChatLinkSourcesAddOns = {}

local function callApi(namespaceName, functionName, ...)
  local namespace = _G[namespaceName]
  if type(namespace) ~= "table" or type(namespace[functionName]) ~= "function" then
    return nil
  end
  return namespace[functionName](...)
end

local function achievementLink(achievementID)
  local getLink = _G.GetAchievementLink
  if type(getLink) ~= "function" then
    return nil
  end
  return getLink(achievementID)
end

-- Classic passes (self, ignoreModifiers); Cata and Mists pass
-- (self, button, down, ignoreModifiers). Retail's achievement list inserts
-- without checking for a Blizzard chat box, so the InsertLink hook covers it.
local function hookAchievements(insert)
  Util.HookGlobal("AchievementButton_OnClick", function(button, second, _down, fourth)
    if type(button) ~= "table" or button.id == nil or second == true or fourth == true then
      return
    end
    if Util.IsChatLinkClick() then
      insert(achievementLink(button.id))
    end
  end)
end

-- Section headers and boss buttons carry their link in `link`. The journal
-- binds these handlers by name as it creates buttons, which it does while the
-- player browses, after this hook is in place.
local function hookEncounterJournal(insert)
  local function onClick(button)
    if type(button) == "table" and Util.IsChatLinkClick() then
      insert(button.link)
    end
  end
  Util.HookGlobal("EncounterJournal_OnClick", onClick)
  Util.HookGlobal("EncounterJournalBossButton_OnClick", onClick)
end

-- Glyph sockets (Wrath, Cata, Mists).
local function hookGlyphs(insert)
  Util.HookGlobal("GlyphFrameGlyph_OnClick", function(glyph)
    if type(glyph) ~= "table" or glyph.glyphID == nil or type(glyph.GetID) ~= "function" then
      return
    end
    if Util.IsChatLinkClick() then
      insert(callApi("C_GlyphInfo", "GetGlyphLink", glyph:GetID(), glyph.glyphID))
    end
  end)
end

-- Retail objective tracker headers. Each tracker is one named frame, so its
-- own OnBlockHeaderClick can be hooked. A negative recipe id marks a recraft.
local TRACKER_LINKS = {
  AchievementObjectiveTracker = function(block)
    return achievementLink(block.id)
  end,
  ProfessionsRecipeTracker = function(block)
    return callApi("C_TradeSkillUI", "GetRecipeLink", math.abs(block.id))
  end,
  MonthlyActivitiesObjectiveTracker = function(block)
    return callApi("C_PerksActivities", "GetPerksActivityChatLink", block.id)
  end,
  InitiativeTasksObjectiveTracker = function(block)
    return callApi("C_NeighborhoodInitiative", "GetInitiativeTaskChatLink", block.id)
  end,
}

local function hookObjectiveTracker(insert)
  for frameName, linkFor in pairs(TRACKER_LINKS) do
    Util.HookMethod(_G[frameName], "OnBlockHeaderClick", function(_tracker, block)
      if type(block) == "table" and type(block.id) == "number" and Util.IsChatLinkClick() then
        insert(linkFor(block))
      end
    end)
  end
end

function ChatLinkSourcesAddOns.Register(insert)
  Util.OnAddOnLoaded("Blizzard_AchievementUI", function()
    hookAchievements(insert)
  end)
  Util.OnAddOnLoaded("Blizzard_EncounterJournal", function()
    hookEncounterJournal(insert)
  end)
  Util.OnAddOnLoaded("Blizzard_GlyphUI", function()
    hookGlyphs(insert)
  end)
  Util.OnAddOnLoaded("Blizzard_ObjectiveTracker", function()
    hookObjectiveTracker(insert)
  end)
end

ns.ComposerChatLinkSourcesAddOns = ChatLinkSourcesAddOns
return ChatLinkSourcesAddOns
