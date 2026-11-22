local FakeUI = require("tests.helpers.fake_ui")
local Probe = require("tests.helpers.menu_popup_probe")
local Localization = require("WhisperMessenger.Locale.Localization")
local MenuPopup = require("WhisperMessenger.UI.Shared.MenuPopup")
local OwnMenu = require("WhisperMessenger.UI.ContactsList.OwnMenu")

-- The Report row of WM's own contact popup: shown only when the game can
-- report this player, and it opens the game's report frame.

local STUBBED = { "Enum", "PlayerLocation", "C_ChatInfo", "C_ReportSystem", "ReportInfo", "ReportFrame" }

local function noop() end

local function location(from, id)
  return {
    from = from,
    id = id,
    IsValid = function()
      return true
    end,
  }
end

local function labels()
  return Probe.Labels()
end

return function()
  local factory = FakeUI.NewFactory()
  local saved = {}
  for _, name in ipairs(STUBBED) do
    saved[name] = rawget(_G, name)
  end
  local savedParent, savedCreateFrame, savedSpecial = _G.UIParent, rawget(_G, "CreateFrame"), _G.UISpecialFrames
  Localization.Configure({ language = "enUS" })
  _G.UIParent = factory.CreateFrame("Frame", "UIParent", nil)
  rawset(_G, "CreateFrame", factory.CreateFrame)
  _G.UISpecialFrames = {}
  local anchor = factory.CreateFrame("Button", nil, _G.UIParent)
  anchor:Show()

  local canReport = true
  local reported
  local function install()
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
        return canReport
      end,
    })
    rawset(_G, "ReportInfo", {
      CreateReportInfoFromType = function(_self, reportType)
        return { type = reportType }
      end,
    })
    rawset(_G, "ReportFrame", {
      InitiateReport = function(_self, info, name, loc, isBN)
        reported = { info = info, name = name, loc = loc, isBN = isBN }
      end,
    })
  end

  local function openAndReport(item)
    reported = nil
    OwnMenu.Open(item, anchor, "Arthas", nil, noop)
    Probe.Click("Report")
    return assert(reported, "report fired")
  end

  local ok, err = pcall(function()
    install()

    -- test_report_uses_chat_type_for_valid_chat_line
    do
      local item = { channel = "WOW", displayName = "Arthas", lineID = 42, guid = "Player-1-A" }
      OwnMenu.Open(item, anchor, "Arthas", nil, noop)
      local got = labels()
      assert(got[#got - 1] == "divider", "divider before Report, got " .. table.concat(got, ","))
      assert(got[#got] == "button:Report", "Report is last, got " .. table.concat(got, ","))
      reported = nil
      Probe.Click("Report")
      assert(reported and reported.info.type == "chat-type", "chat report type")
      assert(reported.loc.from == "line" and reported.loc.id == 42, "chat line location")
      assert(reported.name == "Arthas", "report names the player")
      assert(reported.isBN == false, "not a BN report")
    end

    -- test_invalid_chat_line_falls_back_to_guid
    do
      local got = openAndReport({ channel = "WOW", displayName = "Arthas", lineID = 7, guid = "Player-1-A" })
      assert(got.info.type == "friend-type", "invalid line uses the friend type")
      assert(got.loc.from == "guid", "invalid line uses the guid")
    end

    -- test_report_uses_friend_type_for_guid_only
    do
      local got = openAndReport({ channel = "WOW", displayName = "Arthas", guid = "Player-1-A" })
      assert(got.info.type == "friend-type", "guid only uses the friend type")
    end

    -- test_report_flags_bn_contact
    do
      local got = openAndReport({ channel = "BN", displayName = "Jaina", guid = "Player-1-B" })
      assert(got.isBN == true, "BN contact is flagged")
    end

    -- test_report_hidden_when_cannot_report
    canReport = false
    OwnMenu.Open({ channel = "WOW", displayName = "Arthas", guid = "Player-1-A" }, anchor, "Arthas", nil, noop)
    assert(Probe.Find("Report") == nil, "no Report when the game refuses")
    local got = labels()
    assert(got[#got] ~= "divider", "no trailing divider, got " .. table.concat(got, ","))
    canReport = true

    -- test_report_hidden_without_location
    OwnMenu.Open({ channel = "WOW", displayName = "Arthas" }, anchor, "Arthas", nil, noop)
    assert(Probe.Find("Report") == nil, "no Report without a location")

    -- test_report_hidden_when_api_missing
    rawset(_G, "ReportFrame", nil)
    OwnMenu.Open({ channel = "WOW", displayName = "Arthas", guid = "Player-1-A" }, anchor, "Arthas", nil, noop)
    assert(Probe.Find("Report") == nil, "no Report without ReportFrame")
    install()
    rawset(_G, "PlayerLocation", nil)
    OwnMenu.Open({ channel = "WOW", displayName = "Arthas", guid = "Player-1-A" }, anchor, "Arthas", nil, noop)
    assert(Probe.Find("Report") == nil, "no Report without PlayerLocation")
  end)

  MenuPopup.Close()
  for _, name in ipairs(STUBBED) do
    rawset(_G, name, saved[name])
  end
  _G.UIParent = savedParent
  rawset(_G, "CreateFrame", savedCreateFrame)
  _G.UISpecialFrames = savedSpecial
  assert(ok, err)
end
