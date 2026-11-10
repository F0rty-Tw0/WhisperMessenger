-- Chat-link sources inside Blizzard addons that load later. Each group hooks
-- once its addon has loaded and inserts the link the click handler would have
-- put in Blizzard's own chat box.
local ChatLinkSourcesEnv = require("tests.helpers.chat_link_sources_env")

local MODULE = "WhisperMessenger.UI.Composer.ChatLinkSourcesAddOns"
local GLOBALS = {
  "AchievementButton_OnClick",
  "GetAchievementLink",
  "EncounterJournal_OnClick",
  "EncounterJournalBossButton_OnClick",
  "GlyphFrameGlyph_OnClick",
  "C_GlyphInfo",
  "AchievementObjectiveTracker",
  "ProfessionsRecipeTracker",
  "MonthlyActivitiesObjectiveTracker",
  "InitiativeTasksObjectiveTracker",
  "C_TradeSkillUI",
  "C_PerksActivities",
  "C_NeighborhoodInitiative",
  "ProfessionsFrame",
}

local function withEnv(setup, body)
  ChatLinkSourcesEnv.With(MODULE, GLOBALS, setup, body)
end

local function installAchievementLink()
  rawset(_G, "GetAchievementLink", function(id)
    return "|Hachievement:" .. id .. "|h[Level 10]|h"
  end)
end

-- Watched, so a write into the tracker frame fails the test.
local function tracker(name)
  return _G[name]
end

local function installTracker(env, name)
  rawset(
    _G,
    name,
    env.Watch(name, {
      OnBlockHeaderClick = function(_self, _block, _mouseButton) end,
    })
  )
end

return function()
  -- test_achievement_click_inserts_link_once_ui_loads
  withEnv(function(env)
    env.DeferAddOns()
    installAchievementLink()
  end, function(env)
    local callback = env.pendingAddOns.Blizzard_AchievementUI
    assert(callback ~= nil, "achievement hook should wait for Blizzard_AchievementUI")
    rawset(_G, "AchievementButton_OnClick", function(_button, _second, _down, _fourth) end)
    callback()
    _G.AchievementButton_OnClick({ id = 6 }, "LeftButton", false)
    assert(env.inserts[1] == "|Hachievement:6|h[Level 10]|h", "expected the achievement link, got: " .. tostring(env.inserts[1]))
  end)

  -- test_achievement_click_skips_ignore_modifiers
  -- (Classic passes ignoreModifiers second, Cata and Mists fourth)
  withEnv(function()
    rawset(_G, "AchievementButton_OnClick", function(_button, _second, _down, _fourth) end)
    installAchievementLink()
  end, function(env)
    _G.AchievementButton_OnClick({ id = 6 }, true)
    _G.AchievementButton_OnClick({ id = 6 }, nil, nil, true)
    assert(#env.inserts == 0, "ignoreModifiers clicks must not insert, got " .. #env.inserts)
  end)

  -- test_achievement_plain_click_inserts_nothing
  withEnv(function()
    rawset(_G, "AchievementButton_OnClick", function(_button, _second, _down, _fourth) end)
    installAchievementLink()
  end, function(env)
    env.chatLink = false
    _G.AchievementButton_OnClick({ id = 6 }, "LeftButton", false)
    assert(#env.inserts == 0, "a plain click must not insert, got " .. #env.inserts)
  end)

  -- test_encounter_journal_clicks_insert_button_link_once_journal_loads
  withEnv(function(env)
    env.DeferAddOns()
  end, function(env)
    rawset(_G, "EncounterJournal_OnClick", function(_self) end)
    rawset(_G, "EncounterJournalBossButton_OnClick", function(_self) end)
    env.pendingAddOns.Blizzard_EncounterJournal()
    _G.EncounterJournalBossButton_OnClick({ link = "|Hjournal:1:2522:16|h[Ragnaros]|h" })
    _G.EncounterJournal_OnClick({ link = "|Hjournal:2:4885:16|h[Molten Core]|h" })
    env.chatLink = false
    _G.EncounterJournal_OnClick({ link = "|Hjournal:2:1:16|h[x]|h" })
    assert(#env.inserts == 2, "expected two journal links, got " .. #env.inserts)
    assert(env.inserts[1] == "|Hjournal:1:2522:16|h[Ragnaros]|h", "expected the boss link, got: " .. tostring(env.inserts[1]))
  end)

  -- test_glyph_click_inserts_glyph_link
  withEnv(function()
    rawset(_G, "GlyphFrameGlyph_OnClick", function(_self, _button, _down) end)
    rawset(_G, "C_GlyphInfo", {
      GetGlyphLink = function(slot, glyphID)
        return "|Hglyph:" .. slot .. ":" .. glyphID .. "|h[Glyph of Fireball]|h"
      end,
    })
  end, function(env)
    local glyph = {
      glyphID = 42,
      GetID = function()
        return 3
      end,
    }
    _G.GlyphFrameGlyph_OnClick(glyph, "LeftButton", false)
    _G.GlyphFrameGlyph_OnClick({
      GetID = function()
        return 4
      end,
    }, "LeftButton", false)
    assert(
      #env.inserts == 1 and env.inserts[1] == "|Hglyph:3:42|h[Glyph of Fireball]|h",
      "expected one glyph link, got: " .. tostring(env.inserts[1])
    )
  end)

  -- test_glyph_plain_click_inserts_nothing
  withEnv(function()
    rawset(_G, "GlyphFrameGlyph_OnClick", function(_self, _button, _down) end)
    rawset(_G, "C_GlyphInfo", {
      GetGlyphLink = function(slot, glyphID)
        return "|Hglyph:" .. slot .. ":" .. glyphID .. "|h[Glyph of Fireball]|h"
      end,
    })
  end, function(env)
    env.chatLink = false
    _G.GlyphFrameGlyph_OnClick({
      glyphID = 42,
      GetID = function()
        return 3
      end,
    }, "LeftButton", false)
    assert(#env.inserts == 0, "a plain click must not insert, got " .. #env.inserts)
  end)

  -- test_objective_tracker_headers_insert_their_links
  withEnv(function(env)
    installAchievementLink()
    installTracker(env, "AchievementObjectiveTracker")
    installTracker(env, "ProfessionsRecipeTracker")
    rawset(_G, "C_TradeSkillUI", {
      GetRecipeLink = function(recipeID)
        return "|Henchant:" .. recipeID .. "|h[Recipe]|h"
      end,
    })
  end, function(env)
    tracker("AchievementObjectiveTracker"):OnBlockHeaderClick({ id = 6 }, "LeftButton")
    tracker("ProfessionsRecipeTracker"):OnBlockHeaderClick({ id = -77 }, "LeftButton")
    assert(env.inserts[1] == "|Hachievement:6|h[Level 10]|h", "expected the tracked achievement, got: " .. tostring(env.inserts[1]))
    assert(env.inserts[2] == "|Henchant:77|h[Recipe]|h", "expected the recraft recipe link, got: " .. tostring(env.inserts[2]))
  end)

  -- test_objective_tracker_plain_click_inserts_nothing
  withEnv(function(env)
    installTracker(env, "MonthlyActivitiesObjectiveTracker")
    rawset(_G, "C_PerksActivities", {
      GetPerksActivityChatLink = function(id)
        return "|HperksActivity:" .. id .. "|h[Kill]|h"
      end,
    })
  end, function(env)
    env.chatLink = false
    tracker("MonthlyActivitiesObjectiveTracker"):OnBlockHeaderClick({ id = 5 }, "LeftButton")
    assert(#env.inserts == 0, "a plain click must not insert, got " .. #env.inserts)
  end)

  -- test_objective_tracker_header_without_numeric_id_inserts_nothing
  -- (the recipe link needs math.abs(id), which throws on anything else)
  withEnv(function(env)
    installTracker(env, "ProfessionsRecipeTracker")
    rawset(_G, "C_TradeSkillUI", {
      GetRecipeLink = function(recipeID)
        return "|Henchant:" .. recipeID .. "|h[Recipe]|h"
      end,
    })
  end, function(env)
    tracker("ProfessionsRecipeTracker"):OnBlockHeaderClick({}, "LeftButton")
    tracker("ProfessionsRecipeTracker"):OnBlockHeaderClick({ id = "77" }, "LeftButton")
    assert(#env.inserts == 0, "a header without a numeric id must not insert, got " .. #env.inserts)
  end)

  -- test_profession_link_button_click_inserts_trade_link_once_professions_loads
  -- (Blizzard inserts only into an open Blizzard chat box and the button needs
  -- no modifier, so a plain click must insert)
  withEnv(function(env)
    env.DeferAddOns()
    rawset(_G, "C_TradeSkillUI", {
      GetTradeSkillListLink = function()
        return "|Htrade:Player-1-0001:164:164|h[Blacksmithing]|h"
      end,
    })
  end, function(env)
    local callback = env.pendingAddOns.Blizzard_Professions
    assert(callback ~= nil, "the Link button hook should wait for Blizzard_Professions")
    local onClick
    rawset(_G, "ProfessionsFrame", {
      CraftingPage = {
        LinkButton = {
          HookScript = function(_button, script, handler)
            assert(script == "OnClick", "expected an OnClick hook, got " .. tostring(script))
            onClick = handler
          end,
        },
      },
    })
    callback()
    assert(onClick ~= nil, "the Link button should be hooked once Professions loads")
    env.chatLink = false
    onClick()
    assert(env.inserts[1] == "|Htrade:Player-1-0001:164:164|h[Blacksmithing]|h", "expected the trade link, got: " .. tostring(env.inserts[1]))
  end)

  -- test_profession_link_button_missing_parts_hook_nothing
  withEnv(function(env)
    env.DeferAddOns()
    rawset(_G, "ProfessionsFrame", { CraftingPage = {} })
  end, function(env)
    env.pendingAddOns.Blizzard_Professions()
    assert(#env.inserts == 0, "no Link button means nothing to hook or insert")
  end)

  -- test_missing_addon_handlers_register_nothing
  withEnv(function() end, function(env)
    for _, name in ipairs({ "EncounterJournal_OnClick", "InitiativeTasksObjectiveTracker" }) do
      assert(_G[name] == nil, name .. " is missing and must stay missing")
    end
    assert(#env.inserts == 0, "nothing inserts without handlers")
  end)

  -- test_registering_every_addon_hook_assigns_no_global
  -- (the env fails on any global assignment or tracker field write; every
  -- hook target exists here)
  withEnv(function(env)
    env.DeferAddOns()
    for _, name in ipairs({ "AchievementButton_OnClick", "EncounterJournal_OnClick", "EncounterJournalBossButton_OnClick", "GlyphFrameGlyph_OnClick" }) do
      rawset(_G, name, function() end)
    end
    for _, name in ipairs({
      "AchievementObjectiveTracker",
      "ProfessionsRecipeTracker",
      "MonthlyActivitiesObjectiveTracker",
      "InitiativeTasksObjectiveTracker",
    }) do
      installTracker(env, name)
    end
  end, function(env)
    local loaded = 0
    for _, callback in pairs(env.pendingAddOns) do
      callback()
      loaded = loaded + 1
    end
    assert(loaded == 5, "expected five addon load callbacks, got " .. loaded)
    assert(#env.writes == 0, "addon hooks assigned " .. table.concat(env.writes, ", "))
  end)
end
