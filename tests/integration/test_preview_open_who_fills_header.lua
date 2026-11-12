local CompactRuntime = require("tests.helpers.compact_runtime")
local Env = require("tests.helpers.who_lookup_env")
local Availability = require("WhisperMessenger.Transport.Availability")
local RaceTags = require("WhisperMessenger.Model.Identity.RaceTags")
local SeenLevelEvents = require("WhisperMessenger.Core.SeenLevelEvents")

-- A click on the whisper preview asks /who inside the click; the quiet answer
-- fills the chat's class, race and faction and shows it Online, the same way
-- a contact row click does. The real runtime is booted with the who fakes.

local KEY = CompactRuntime.KEY

local ROW = {
  fullName = "Arthas-Area52",
  level = 60,
  classStr = "Mage",
  filename = "MAGE",
  raceStr = "Undead",
  area = "Orgrimmar",
}

local function receiveWhisper(runtime)
  local finishSlide = CompactRuntime.FinishSlide
  rawset(CompactRuntime, "FinishSlide", function() end)
  local ok, err = pcall(CompactRuntime.ReceiveWhisper, runtime)
  rawset(CompactRuntime, "FinishSlide", finishSlide)
  assert(ok, err)
end

local function clickPreview(runtime)
  local frame = runtime.icon.previewFrame
  assert(frame:IsShown(), "the preview shows the whisper")
  frame:GetScript("OnMouseUp")(frame, "LeftButton")
end

local function answerWho(env)
  env.api.GetNumWhoResults = function()
    return 1
  end
  env.api.GetWhoInfo = function()
    return ROW
  end
  local frame = SeenLevelEvents._frame
  frame:GetScript("OnEvent")(frame, "WHO_LIST_UPDATE")
end

local function contactItem(runtime, key)
  for _, row in ipairs(runtime.window.contacts.rows) do
    if row.item and row.item.conversationKey == key then
      return row.item
    end
  end
  error("no row for " .. key)
end

return function()
  local savedCreatureInfo = rawget(_G, "C_CreatureInfo")
  rawset(_G, "C_CreatureInfo", {
    GetRaceInfo = function(id)
      if id == 5 then
        return { raceName = "Undead", clientFileString = "Scourge" }
      end
      return nil
    end,
  })
  RaceTags._reset()

  -- test_preview_click_who_answer_fills_class_and_online
  Env.Case("preview who fills header", { whoToUi = false }, function(env)
    CompactRuntime.Run({ compactLayout = false, showPlayerLevels = true }, function(runtime)
      receiveWhisper(runtime)
      -- A chat whose sender came without a guid: only /who can tell Online.
      local conversation = runtime.store.conversations[KEY]
      conversation.guid = nil
      clickPreview(runtime)
      assert(#env.sent == 1, "the preview click asks /who, sent " .. #env.sent)
      assert(runtime.activeConversationKey == KEY, "the preview opened its chat")

      answerWho(env)
      runtime.refreshWindow()

      assert(conversation.className == "Mage", "class from /who, got " .. tostring(conversation.className))
      assert(conversation.raceName == "Undead", "race from /who, got " .. tostring(conversation.raceName))
      assert(conversation.factionName == "Horde", "faction from /who, got " .. tostring(conversation.factionName))
      local item = contactItem(runtime, KEY)
      local status = item.availability and item.availability.status
      assert(status == "CanWhisper", "the /who answer shows Online, got " .. tostring(status))
      -- Header line 1 is level, race and class; line 2 carries the status.
      local pane = runtime.window.conversation
      assert(string.find(pane.headerStatus.text or "", "Mage", 1, true), "header line 1 shows the class")
      local detail = pane.headerStatusDetail.text or ""
      assert(string.find(detail, "Online", 1, true), "header shows Online, got " .. tostring(detail))
    end)
  end)

  -- test_preview_click_who_answer_beats_guid_chat_offline
  Env.Case("preview who beats guid offline", { whoToUi = false }, function(env)
    CompactRuntime.Run({ compactLayout = false, showPlayerLevels = true }, function(runtime)
      receiveWhisper(runtime)
      -- The game's whisper check said Offline for a player who is online.
      local conversation = runtime.store.conversations[KEY]
      assert(conversation.guid ~= nil, "the whisper came with a guid")
      runtime.availabilityByGUID[conversation.guid] = Availability.FromStatus("Offline")
      clickPreview(runtime)
      assert(#env.sent == 1, "the preview click asks /who, sent " .. #env.sent)

      answerWho(env)
      runtime.refreshWindow()

      local item = contactItem(runtime, KEY)
      local status = item.availability and item.availability.status
      assert(status == "CanWhisper", "the /who answer shows Online, got " .. tostring(status))
      local detail = runtime.window.conversation.headerStatusDetail.text or ""
      assert(string.find(detail, "Online", 1, true), "header shows Online, got " .. tostring(detail))
      assert(string.find(detail, "Orgrimmar", 1, true), "header shows the /who zone, got " .. tostring(detail))
    end)
  end)

  rawset(_G, "C_CreatureInfo", savedCreatureInfo)
  RaceTags._reset()
  SeenLevelEvents._reset()
end
