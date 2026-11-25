local Probe = require("tests.helpers.menu_popup_probe")
local World = require("tests.helpers.menu_popup_world")
local Localization = require("WhisperMessenger.Locale.Localization")
local OwnMenu = require("WhisperMessenger.UI.ContactsList.OwnMenu")

-- The Report row of WM's own contact popup: shown only when the game can
-- report this player, and it opens the game's report frame.

local STUBBED = { "Enum", "PlayerLocation", "C_ChatInfo", "C_ReportSystem", "ReportInfo", "ReportFrame" }

local function noop() end

local function guidItem()
  return { channel = "WOW", displayName = "Arthas", guid = "Player-1-A" }
end

local function lineItem()
  return { channel = "WOW", displayName = "Arthas", lineID = 42, guid = "Player-1-A" }
end

-- The game's report APIs, stubbed. state.valid is what IsValid answers,
-- state.canReport what CanReportPlayer answers (a function runs instead),
-- state.reported the last InitiateReport call.
local function install(state, saved)
  local function location(from, id)
    return {
      from = from,
      id = id,
      IsValid = function()
        return state.valid
      end,
    }
  end
  rawset(_G, "Enum", setmetatable({ ReportType = { Chat = "chat-type", Friend = "friend-type" } }, { __index = saved.Enum }))
  rawset(_G, "PlayerLocation", {
    CreateFromChatLineID = function(_self, id)
      return location("line", id)
    end,
    CreateFromGUID = function(_self, guid)
      return location("guid", guid)
    end,
  })
  rawset(_G, "C_ChatInfo", {
    IsValidChatLine = function(id)
      return id == 42
    end,
  })
  rawset(_G, "C_ReportSystem", {
    CanReportPlayer = function()
      if type(state.canReport) == "function" then
        return state.canReport()
      end
      return state.canReport
    end,
  })
  rawset(_G, "ReportInfo", {
    CreateReportInfoFromType = function(_self, reportType)
      return { type = reportType }
    end,
  })
  rawset(_G, "ReportFrame", {
    InitiateReport = function(_self, info, name, loc, isBN)
      state.reported = { info = info, name = name, loc = loc, isBN = isBN }
    end,
  })
end

-- Runs fn(anchor, state) with the report APIs stubbed and a popup world.
local function withReportApis(fn)
  local saved = {}
  for _, name in ipairs(STUBBED) do
    saved[name] = rawget(_G, name)
  end
  local state = { valid = true, canReport = true }
  install(state, saved)
  local ok, err = pcall(World.With, function(_factory, anchor)
    fn(anchor, state)
  end)
  for _, name in ipairs(STUBBED) do
    rawset(_G, name, saved[name])
  end
  if not ok then
    error(err, 0)
  end
end

local function openAndReport(anchor, state, item)
  state.reported = nil
  OwnMenu.Open(item, anchor, "Arthas", nil, noop)
  Probe.Click("Report")
  return assert(state.reported, "report fired")
end

local function openWithoutReport(anchor, item)
  OwnMenu.Open(item, anchor, "Arthas", nil, noop)
  return Probe.Find("Report") == nil
end

local function runReportCases()
  -- test_report_row_is_last_after_a_divider
  withReportApis(function(anchor)
    OwnMenu.Open(lineItem(), anchor, "Arthas", nil, noop)
    local got = Probe.Labels()
    assert(got[#got - 1] == "divider" and got[#got] == "button:Report", "divider then Report last, got " .. table.concat(got, ","))
  end)

  -- test_report_uses_chat_type_for_valid_chat_line
  withReportApis(function(anchor, state)
    local got = openAndReport(anchor, state, lineItem())
    assert(got.info.type == "chat-type", "chat report type")
    assert(got.loc.from == "line" and got.loc.id == 42, "chat line location")
  end)

  -- test_report_names_the_player
  withReportApis(function(anchor, state)
    local got = openAndReport(anchor, state, lineItem())
    assert(got.name == "Arthas", "report names the player")
    assert(got.isBN == false, "not a BN report")
  end)

  -- test_invalid_chat_line_falls_back_to_guid
  withReportApis(function(anchor, state)
    local got = openAndReport(anchor, state, { channel = "WOW", displayName = "Arthas", lineID = 7, guid = "Player-1-A" })
    assert(got.info.type == "friend-type", "invalid line uses the friend type")
    assert(got.loc.from == "guid", "invalid line uses the guid")
  end)

  -- test_report_uses_friend_type_for_guid_only
  withReportApis(function(anchor, state)
    local got = openAndReport(anchor, state, guidItem())
    assert(got.info.type == "friend-type", "guid only uses the friend type")
  end)

  -- test_report_flags_bn_contact
  withReportApis(function(anchor, state)
    local got = openAndReport(anchor, state, { channel = "BN", displayName = "Jaina", guid = "Player-1-B" })
    assert(got.isBN == true, "BN contact is flagged")
  end)
end

local function runHiddenCases()
  -- test_report_hidden_when_cannot_report
  withReportApis(function(anchor, state)
    state.canReport = false
    assert(openWithoutReport(anchor, guidItem()), "no Report when the game refuses")
  end)

  -- test_no_trailing_divider_without_report
  withReportApis(function(anchor, state)
    state.canReport = false
    OwnMenu.Open(guidItem(), anchor, "Arthas", nil, noop)
    local got = Probe.Labels()
    assert(got[#got] ~= "divider", "no trailing divider, got " .. table.concat(got, ","))
  end)

  -- test_report_hidden_when_location_invalid
  withReportApis(function(anchor, state)
    state.valid = false
    assert(openWithoutReport(anchor, guidItem()), "no Report for an invalid location")
  end)

  -- test_report_hidden_when_can_report_throws
  withReportApis(function(anchor, state)
    state.canReport = function()
      error("CanReportPlayer blew up")
    end
    assert(openWithoutReport(anchor, guidItem()), "a throwing check counts as no")
  end)

  -- test_report_hidden_without_location
  withReportApis(function(anchor)
    assert(openWithoutReport(anchor, { channel = "WOW", displayName = "Arthas" }), "no Report without a location")
  end)

  -- test_report_hidden_without_report_frame
  withReportApis(function(anchor)
    rawset(_G, "ReportFrame", nil)
    assert(openWithoutReport(anchor, guidItem()), "no Report without ReportFrame")
  end)

  -- test_report_hidden_without_player_location
  withReportApis(function(anchor)
    rawset(_G, "PlayerLocation", nil)
    assert(openWithoutReport(anchor, guidItem()), "no Report without PlayerLocation")
  end)
end

return function()
  Localization.Configure({ language = "enUS" })
  runReportCases()
  runHiddenCases()
end
