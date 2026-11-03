local Bootstrap = require("WhisperMessenger.Bootstrap")
local EventBridge = require("WhisperMessenger.Core.Bootstrap.EventBridge")
local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")

-- The real bootstrap: a whisper with the messenger closed pops a card, and
-- opening the messenger clears every card.

local TEXT = "meet me in dalaran"

local function boot(factory, settings)
  Bootstrap._inMythicContent = false
  Bootstrap._inEncounter = false
  Bootstrap._inCompetitiveContent = false
  return Bootstrap.Initialize(factory, {
    accountState = { schemaVersion = 1, conversations = {}, contacts = {}, pendingHydration = {}, settings = settings },
    characterState = { window = { x = 0, y = 0, width = 900, height = 560 }, icon = {} },
    localProfileId = "me",
  })
end

local function whisper(runtime)
  EventBridge.RouteLiveEvent(
    runtime,
    runtime.refreshWindow,
    "CHAT_MSG_WHISPER",
    TEXT,
    "Jaina-Proudmoore",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    1,
    "Player-1-ABC"
  )
end

-- A card is a Button right under UIParent that holds the text itself; the
-- widget's own preview (a frame inside the widget) also shows it.
local function shownCard(uiParent)
  for _, child in ipairs(uiParent.children) do
    if child.frameType == "Button" and child:IsShown() then
      for _, region in ipairs(child.children) do
        if region.frameType == "FontString" and region.text == TEXT then
          return child
        end
      end
    end
  end
  return nil
end

return function()
  local savedUIParent, savedChatInfo, savedRestricted = _G.UIParent, _G.C_ChatInfo, _G.C_RestrictedActions
  local savedCombat, savedSlash = rawget(_G, "InCombatLockdown"), _G.SlashCmdList
  rawset(_G, "InCombatLockdown", function()
    return false
  end)
  _G.C_RestrictedActions = nil
  _G.C_ChatInfo = {}
  _G.SlashCmdList = {}

  -- test_whisper_with_window_closed_pops_a_card
  do
    local factory = FakeUI.NewFactory()
    _G.UIParent = factory.CreateFrame("Frame", "UIParent", nil)
    local runtime = boot(factory, { showWhisperToasts = true })
    whisper(runtime)
    assert(shownCard(_G.UIParent) ~= nil, "a card pops for the whisper")
  end

  -- test_cards_stay_off_by_default
  do
    local factory = FakeUI.NewFactory()
    _G.UIParent = factory.CreateFrame("Frame", "UIParent", nil)
    local runtime = boot(factory, {})
    whisper(runtime)
    assert(shownCard(_G.UIParent) == nil, "no card unless the player turns cards on")
  end

  -- test_opening_the_window_clears_the_cards
  do
    local factory = FakeUI.NewFactory()
    _G.UIParent = factory.CreateFrame("Frame", "UIParent", nil)
    local runtime = boot(factory, { showWhisperToasts = true })
    whisper(runtime)
    runtime.ensureWindow()
    runtime.setWindowVisible(true)
    assert(shownCard(_G.UIParent) == nil, "opening the messenger clears the cards")
  end

  _G.UIParent, _G.C_ChatInfo, _G.C_RestrictedActions, _G.SlashCmdList = savedUIParent, savedChatInfo, savedRestricted, savedSlash
  rawset(_G, "InCombatLockdown", savedCombat)
end
