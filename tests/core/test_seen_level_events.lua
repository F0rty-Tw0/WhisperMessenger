require("tests.helpers.fake_ui")
local SeenLevel = require("WhisperMessenger.Model.SeenLevel")
local SeenLevelEvents = require("WhisperMessenger.Core.SeenLevelEvents")

local STUBBED =
  { "UnitIsPlayer", "UnitGUID", "UnitLevel", "UnitFullName", "IsInRaid", "GetNumGroupMembers", "Ambiguate", "_wmSuspended", "UNKNOWNOBJECT" }

local function fire(event, ...)
  local frame = SeenLevelEvents._frame
  frame:GetScript("OnEvent")(frame, event, ...)
end

-- One player per unit token: units[unit] = { guid, level, name, realm }.
local function stubUnits(units, calls)
  rawset(_G, "UnitIsPlayer", function(unit)
    calls.UnitIsPlayer = (calls.UnitIsPlayer or 0) + 1
    return units[unit] ~= nil and units[unit].player ~= false
  end)
  rawset(_G, "UnitGUID", function(unit)
    calls.UnitGUID = (calls.UnitGUID or 0) + 1
    return units[unit] and units[unit].guid
  end)
  rawset(_G, "UnitLevel", function(unit)
    calls.UnitLevel = (calls.UnitLevel or 0) + 1
    return units[unit] and units[unit].level
  end)
  rawset(_G, "UnitFullName", function(unit)
    calls.UnitFullName = (calls.UnitFullName or 0) + 1
    local u = units[unit]
    if u == nil then
      return nil
    end
    return u.name, u.realm
  end)
end

local function makeRuntime()
  return {
    localProfileId = "me",
    store = { conversations = {} },
    friendListApi = {},
    scheduleIncomingRefresh = function() end,
  }
end

return function()
  local saved = {}
  for _, name in ipairs(STUBBED) do
    saved[name] = _G[name]
  end
  local function reset()
    for _, name in ipairs(STUBBED) do
      rawset(_G, name, nil)
    end
    SeenLevelEvents._reset()
    SeenLevel._reset()
  end

  local FIRSTMOON = { guid = "G1", level = 75, name = "Firstmoon" }

  -- test_set_enabled_true_registers_every_unit_event
  do
    reset()
    SeenLevelEvents.Init(makeRuntime())
    SeenLevelEvents.SetEnabled(true)
    for _, event in ipairs(SeenLevelEvents.UNIT_EVENTS) do
      assert(SeenLevelEvents._frame:IsEventRegistered(event), event .. " should be registered")
    end
    assert(SeenLevelEvents.IsEnabled() == true, "IsEnabled should be true")
  end

  -- test_set_enabled_false_unregisters_every_event
  do
    reset()
    SeenLevelEvents.Init(makeRuntime())
    SeenLevelEvents.SetEnabled(true)
    SeenLevelEvents.SetEnabled(false)
    for _, event in ipairs(SeenLevelEvents.UNIT_EVENTS) do
      assert(not SeenLevelEvents._frame:IsEventRegistered(event), event .. " should be unregistered")
    end
    assert(SeenLevelEvents.IsEnabled() == false, "IsEnabled should be false")
  end

  -- test_set_enabled_true_registers_nothing_while_suspended
  do
    reset()
    rawset(_G, "_wmSuspended", true)
    SeenLevelEvents.Init(makeRuntime())
    SeenLevelEvents.SetEnabled(true)
    for _, event in ipairs(SeenLevelEvents.UNIT_EVENTS) do
      assert(not SeenLevelEvents._frame:IsEventRegistered(event), event .. " should stay unregistered")
    end
  end

  -- test_set_enabled_true_registers_during_mythic_lockdown_without_suspend
  do
    reset()
    local runtime = makeRuntime()
    runtime.isMythicLockdown = function()
      return true
    end
    SeenLevelEvents.Init(runtime)
    SeenLevelEvents.SetEnabled(true)
    assert(SeenLevelEvents._frame:IsEventRegistered("PLAYER_TARGET_CHANGED"), "lockdown alone should not block registration")
  end

  -- test_init_reuses_frame_and_rebinds_runtime
  do
    reset()
    SeenLevelEvents.Init(makeRuntime())
    local frame = SeenLevelEvents._frame
    SeenLevelEvents.Init(makeRuntime())
    assert(SeenLevelEvents._frame == frame, "Init should reuse the frame")
  end

  -- test_target_player_records_level
  do
    reset()
    stubUnits({ target = FIRSTMOON }, {})
    SeenLevelEvents.Init(makeRuntime())
    fire("PLAYER_TARGET_CHANGED")
    assert(SeenLevel.Get("G1") == 75, "target level should be recorded")
  end

  -- test_mouseover_player_records_level
  do
    reset()
    stubUnits({ mouseover = FIRSTMOON }, {})
    SeenLevelEvents.Init(makeRuntime())
    fire("UPDATE_MOUSEOVER_UNIT")
    assert(SeenLevel.Get("G1") == 75, "mouseover level should be recorded")
  end

  -- test_non_player_unit_records_nothing
  do
    reset()
    stubUnits({ target = { guid = "NPC1", level = 70, name = "Guard", player = false } }, {})
    SeenLevelEvents.Init(makeRuntime())
    fire("PLAYER_TARGET_CHANGED")
    assert(SeenLevel.Get("NPC1", "Guard") == nil, "npc should not be recorded")
  end

  -- test_skull_level_records_nothing
  do
    reset()
    stubUnits({ target = { guid = "G2", level = -1, name = "Boss" } }, {})
    SeenLevelEvents.Init(makeRuntime())
    fire("PLAYER_TARGET_CHANGED")
    assert(SeenLevel.Get("G2", "Boss") == nil, "skull level should not be recorded")
  end

  -- test_repeat_sighting_skips_name_lookup
  do
    reset()
    local calls = {}
    stubUnits({ target = FIRSTMOON }, calls)
    SeenLevelEvents.Init(makeRuntime())
    fire("PLAYER_TARGET_CHANGED")
    fire("PLAYER_TARGET_CHANGED")
    assert(calls.UnitFullName == 1, "second identical sighting should not read the name")
  end

  -- test_competitive_content_calls_no_unit_api
  do
    reset()
    local calls = {}
    stubUnits({ target = FIRSTMOON }, calls)
    local runtime = makeRuntime()
    runtime.isCompetitiveContent = function()
      return true
    end
    SeenLevelEvents.Init(runtime)
    fire("PLAYER_TARGET_CHANGED")
    assert(next(calls) == nil, "no unit API should run in competitive content")
  end

  -- test_mythic_lockdown_calls_no_unit_api
  do
    reset()
    local calls = {}
    stubUnits({ target = FIRSTMOON }, calls)
    local runtime = makeRuntime()
    runtime.isMythicLockdown = function()
      return true
    end
    SeenLevelEvents.Init(runtime)
    fire("PLAYER_TARGET_CHANGED")
    assert(next(calls) == nil, "no unit API should run in mythic lockdown")
  end

  -- test_nameplate_added_records_that_unit
  do
    reset()
    stubUnits({ nameplate4 = FIRSTMOON }, {})
    SeenLevelEvents.Init(makeRuntime())
    fire("NAME_PLATE_UNIT_ADDED", "nameplate4")
    assert(SeenLevel.Get("G1") == 75, "nameplate unit should be recorded")
  end

  -- test_unit_level_records_that_unit
  do
    reset()
    stubUnits({ party1 = FIRSTMOON }, {})
    SeenLevelEvents.Init(makeRuntime())
    fire("UNIT_LEVEL", "party1")
    assert(SeenLevel.Get("G1") == 75, "UNIT_LEVEL unit should be recorded")
  end

  -- test_unknown_name_records_nothing_until_named
  do
    reset()
    rawset(_G, "UNKNOWNOBJECT", "Unknown")
    local target = { guid = "G1", level = 75, name = "Unknown" }
    stubUnits({ target = target }, {})
    SeenLevelEvents.Init(makeRuntime())
    fire("PLAYER_TARGET_CHANGED")
    assert(SeenLevel.Get("G1") == nil, "a half-loaded unit should record nothing")
    target.name = "Firstmoon"
    fire("PLAYER_TARGET_CHANGED")
    assert(SeenLevel.Get("G1") == 75, "the named sighting should record the guid")
    assert(SeenLevel.Get(nil, "Firstmoon") == 75, "the named sighting should record the name")
  end

  -- test_missing_name_records_nothing
  do
    reset()
    stubUnits({ target = { guid = "G1", level = 75 } }, {})
    SeenLevelEvents.Init(makeRuntime())
    fire("PLAYER_TARGET_CHANGED")
    assert(SeenLevel.Get("G1") == nil, "a unit without a name should record nothing")
  end

  -- test_unit_api_error_does_not_escape
  do
    reset()
    rawset(_G, "UnitIsPlayer", function()
      error("secret value")
    end)
    SeenLevelEvents.Init(makeRuntime())
    local ok = pcall(fire, "PLAYER_TARGET_CHANGED")
    assert(ok, "a throwing unit API must not escape the event handler")
  end

  for _, name in ipairs(STUBBED) do
    rawset(_G, name, saved[name])
  end
  SeenLevelEvents._reset()
  SeenLevel._reset()
end
