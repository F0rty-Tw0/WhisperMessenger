local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local Localization = require("WhisperMessenger.Locale.Localization")
local WhispersSettings = require("WhisperMessenger.UI.MessengerWindow.WhispersSettings")
local BehaviorSettings = require("WhisperMessenger.UI.MessengerWindow.BehaviorSettings")

local WHISPER_LABELS = {
  "Hide whispers from default chat",
  "Auto-open on incoming whisper",
  "Auto-open on outgoing whisper",
  "Put whispers from strangers in Requests",
  "Share typing status",
  "Send read receipts",
}

local function create(config)
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  local changes = {}
  local result = WhispersSettings.Create(factory, parent, config, {
    onChange = function(key, value)
      changes[key] = value
    end,
  })
  return result, changes, factory, parent
end

return function()
  Localization.Configure({ language = "enUS" })

  -- test_shows_exactly_the_six_whisper_toggles
  do
    local result = create({})
    for _, label in ipairs(WHISPER_LABELS) do
      assert(FindUI.toggle(result.frame, label) ~= nil, "missing whisper toggle: " .. label)
    end
    assert(FindUI.countToggles(result.frame) == #WHISPER_LABELS, "expected 6 toggles, got " .. FindUI.countToggles(result.frame))
  end

  -- test_behavior_no_longer_shows_whisper_toggles
  do
    local factory = FakeUI.NewFactory()
    local parent = factory.CreateFrame("Frame", "UIParent", nil)
    local behavior = BehaviorSettings.Create(factory, parent, {}, { onChange = function() end })
    for _, label in ipairs(WHISPER_LABELS) do
      assert(FindUI.text(behavior.frame, label) == nil, "Behavior should not show: " .. label)
    end
  end

  -- test_reset_restores_whisper_defaults
  do
    local result, changes = create({
      hideFromDefaultChat = false,
      autoOpenIncoming = true,
      autoOpenOutgoing = true,
      requestsInbox = true,
      shareTypingStatus = false,
      shareReadReceipts = false,
    })
    FindUI.click(FindUI.byLabel(result.frame, "Reset to Defaults"))
    assert(changes.hideFromDefaultChat == true, "reset turns hide-from-chat on")
    assert(changes.autoOpenIncoming == false, "reset turns auto-open incoming off")
    assert(changes.autoOpenOutgoing == false, "reset turns auto-open outgoing off")
    assert(changes.requestsInbox == false, "reset turns the Requests inbox off")
    assert(changes.shareTypingStatus == true, "reset turns typing status on")
    assert(changes.shareReadReceipts == true, "reset turns read receipts on")
  end

  -- test_empty_config_shows_saved_defaults
  do
    local result = create({})
    assert(FindUI.isToggleOn(FindUI.toggle(result.frame, "Hide whispers from default chat")) == false, "never-saved hide-from-chat shows off")
    assert(FindUI.isToggleOn(FindUI.toggle(result.frame, "Auto-open on incoming whisper")) == false, "incoming defaults off")
    assert(FindUI.isToggleOn(FindUI.toggle(result.frame, "Auto-open on outgoing whisper")) == false, "outgoing defaults off")
    assert(FindUI.isToggleOn(FindUI.toggle(result.frame, "Put whispers from strangers in Requests")) == false, "Requests defaults off")
    assert(FindUI.isToggleOn(FindUI.toggle(result.frame, "Share typing status")) == true, "typing defaults on")
    assert(FindUI.isToggleOn(FindUI.toggle(result.frame, "Send read receipts")) == true, "receipts default on")
  end

  -- test_saved_values_start_in_place
  do
    local result = create({ requestsInbox = true, shareTypingStatus = false })
    assert(FindUI.isToggleOn(FindUI.toggle(result.frame, "Put whispers from strangers in Requests")) == true, "saved Requests starts on")
    assert(FindUI.isToggleOn(FindUI.toggle(result.frame, "Share typing status")) == false, "explicit false starts off")
  end

  -- test_toggling_reports_setting_keys
  do
    local result, changes = create({})
    local keysByLabel = {
      ["Hide whispers from default chat"] = "hideFromDefaultChat",
      ["Auto-open on incoming whisper"] = "autoOpenIncoming",
      ["Auto-open on outgoing whisper"] = "autoOpenOutgoing",
      ["Put whispers from strangers in Requests"] = "requestsInbox",
      ["Share typing status"] = "shareTypingStatus",
      ["Send read receipts"] = "shareReadReceipts",
    }
    for label, key in pairs(keysByLabel) do
      FindUI.click(FindUI.toggle(result.frame, label))
      assert(changes[key] ~= nil, label .. " should report " .. key)
    end
  end

  -- test_auto_open_incoming_toggle_has_tooltip
  do
    local tooltipTitle, addedLines = nil, {}
    _G.GameTooltip = {
      SetOwner = function() end,
      SetText = function(_self, value)
        tooltipTitle = value
      end,
      AddLine = function(_self, value)
        addedLines[#addedLines + 1] = value
      end,
      Show = function() end,
      Hide = function() end,
    }
    local result = create({})
    local row = FindUI.byLabel(result.frame, "Auto-open on incoming whisper")
    row:GetScript("OnEnter")(row)
    assert(tooltipTitle == "Auto-open on incoming whisper", "tooltip title uses the label")
    assert(#addedLines > 0, "tooltip has a description line")
    _G.GameTooltip = nil
  end

  -- test_russian_localizes_whispers_panel
  do
    Localization.Configure({ language = "ruRU" })
    local result = create({})
    assert(FindUI.text(result.frame, "Шепот") ~= nil, "title is translated")
    assert(FindUI.text(result.frame, Localization.Text("Control how whispers behave.")) ~= nil, "hint is shown")
    assert(Localization.Text("Control how whispers behave.") ~= "Control how whispers behave.", "hint is translated")
    assert(
      FindUI.toggle(result.frame, "Скрывать шепот из стандартного чата") ~= nil,
      "default chat toggle is translated"
    )

    result.setLanguage()
    assert(
      FindUI.toggle(result.frame, "Скрывать шепот из стандартного чата") ~= nil,
      "setLanguage keeps the translated label"
    )
    Localization.Configure({ language = "enUS" })
  end
end
