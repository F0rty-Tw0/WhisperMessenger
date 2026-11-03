local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local GeneralSettings = require("WhisperMessenger.UI.MessengerWindow.GeneralSettings")
local RetentionRow = require("WhisperMessenger.UI.MessengerWindow.GeneralSettings.RetentionRow")
local Retention = require("WhisperMessenger.Model.Retention")
local Localization = require("WhisperMessenger.Locale.Localization")
local ReloadPopups = require("tests.helpers.reload_popups")

local LABEL = "Message Retention"
local CONFIRM = "WHISPER_MESSENGER_CONFIRM_SHORTER_RETENTION"
local HOUR = 3600
local DAY = 86400

local EXPECTED = {
  { seconds = HOUR, label = "1 hour" },
  { seconds = 6 * HOUR, label = "6 hours" },
  { seconds = 12 * HOUR, label = "12 hours" },
  { seconds = DAY, label = "1 day" },
  { seconds = 3 * DAY, label = "3 days" },
  { seconds = 7 * DAY, label = "7 days" },
  { seconds = 30 * DAY, label = "30 days" },
  { seconds = 90 * DAY, label = "90 days" },
  { seconds = Retention.FOREVER_SECONDS, label = "Forever" },
}

local function create(factory, parent, config, changes)
  return GeneralSettings.Create(factory, parent, config, {
    onChange = function(key, value)
      changes[#changes + 1] = { key = key, value = value }
    end,
  })
end

local function row(settings, label)
  return FindUI.byLabel(settings.frame, label or LABEL)
end

local function closedLabel(settings, label)
  return FindUI.ofType(row(settings, label), "Button")[1].label.text
end

-- Opens the menu (closing it first when already open) and returns the
-- listed option labels in order.
local function openLabels(settings)
  local dropdownRow = row(settings)
  local menu = FindUI.dropdownMenu(dropdownRow)
  local button = FindUI.ofType(dropdownRow, "Button")[1]
  if menu:IsShown() then
    FindUI.click(button)
  end
  FindUI.click(button)
  local labels = {}
  for _, option in ipairs(FindUI.dropdownOptions(dropdownRow)) do
    labels[#labels + 1] = option.label.text
  end
  return labels
end

local function pick(settings, label)
  openLabels(settings)
  for _, option in ipairs(FindUI.dropdownOptions(row(settings))) do
    if option.label.text == label then
      FindUI.click(option)
      return
    end
  end
  error("no retention option labelled '" .. label .. "'")
end

local function retentionChanges(changes)
  local out = {}
  for _, change in ipairs(changes) do
    if change.key == "messageMaxAge" then
      out[#out + 1] = change.value
    end
  end
  return out
end

local function contains(list, value)
  for _, item in ipairs(list) do
    if item == value then
      return true
    end
  end
  return false
end

return function()
  Localization.Configure({ language = "enUS" })
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", nil, nil)
  parent:SetSize(600, 500)

  -- test_options_map_each_choice_to_seconds_in_order
  do
    local options = RetentionRow.BuildOptions("enUS", DAY)
    assert(#options == #EXPECTED, "expected " .. #EXPECTED .. " retention choices, got " .. #options)
    for index, expected in ipairs(EXPECTED) do
      assert(
        options[index].key == expected.seconds,
        "choice " .. index .. " should store " .. expected.seconds .. ", got " .. tostring(options[index].key)
      )
      assert(
        options[index].label == expected.label,
        "choice " .. index .. " should read '" .. expected.label .. "', got " .. tostring(options[index].label)
      )
    end
  end

  -- test_retention_is_a_dropdown_showing_the_saved_choice
  do
    local settings = create(factory, parent, { messageMaxAge = 30 * DAY }, {})
    assert(FindUI.dropdownMenu(row(settings)) ~= nil, "retention should be a dropdown")
    assert(FindUI.text(settings.frame, "Message Retention (hours)") == nil, "the old hours slider is gone")
    assert(closedLabel(settings) == "30 days", "closed dropdown should show the saved choice, got " .. tostring(closedLabel(settings)))
  end

  -- test_missing_setting_shows_the_one_day_default
  do
    local settings = create(factory, parent, {}, {})
    assert(closedLabel(settings) == "1 day", "default retention is 1 day, got " .. tostring(closedLabel(settings)))
  end

  -- test_unknown_saved_value_is_shown_as_its_own_entry_and_kept
  do
    local changes = {}
    local settings = create(factory, parent, { messageMaxAge = 48 * HOUR }, changes)
    assert(closedLabel(settings) == "48 hours", "old slider value should show as '48 hours', got " .. tostring(closedLabel(settings)))
    local labels = openLabels(settings)
    assert(#labels == #EXPECTED + 1, "custom value adds one entry, got " .. #labels)
    assert(labels[5] == "48 hours", "custom entry sits between 1 day and 3 days, got " .. tostring(labels[5]))
    assert(#retentionChanges(changes) == 0, "opening the panel never rewrites the saved retention")
  end

  -- test_selecting_a_choice_writes_message_max_age
  do
    local changes = {}
    local settings = create(factory, parent, { messageMaxAge = DAY }, changes)
    pick(settings, "90 days")
    pick(settings, "Forever")
    local written = retentionChanges(changes)
    assert(written[1] == 90 * DAY, "90 days writes 7776000 seconds, got " .. tostring(written[1]))
    assert(written[2] == Retention.FOREVER_SECONDS, "Forever writes FOREVER_SECONDS, got " .. tostring(written[2]))
    assert(closedLabel(settings) == "Forever", "closed dropdown follows the pick")
  end

  -- test_custom_entry_leaves_the_menu_after_another_pick
  do
    local settings = create(factory, parent, { messageMaxAge = 48 * HOUR }, {})
    pick(settings, "7 days")
    local labels = openLabels(settings)
    assert(#labels == #EXPECTED, "custom entry is dropped once another choice is picked, got " .. #labels)
    assert(not contains(labels, "48 hours"), "'48 hours' should no longer be listed")
  end

  -- test_reset_restores_one_day
  ReloadPopups.With(function()
    local changes = {}
    local settings = create(factory, parent, { messageMaxAge = 48 * HOUR }, changes)
    FindUI.click(FindUI.byLabel(settings.frame, "Reset to Defaults"))
    _G.StaticPopupDialogs[CONFIRM].OnAccept()
    local written = retentionChanges(changes)
    assert(written[#written] == DAY, "reset writes the 1 day default, got " .. tostring(written[#written]))
    assert(closedLabel(settings) == "1 day", "reset shows 1 day, got " .. tostring(closedLabel(settings)))
    assert(not contains(openLabels(settings), "48 hours"), "reset drops the custom entry")
  end)

  -- test_shorter_choice_asks_before_saving
  ReloadPopups.With(function(popups)
    local changes = {}
    local settings = create(factory, parent, { messageMaxAge = 90 * DAY }, changes)
    pick(settings, "1 day")
    assert(popups.shown[1] == CONFIRM, "a shorter choice should show the confirm popup, got " .. tostring(popups.shown[1]))
    local dialog = _G.StaticPopupDialogs[CONFIRM]
    assert(
      dialog.text == "Keep chat history for 1 day only? Older messages are deleted now.",
      "prompt names the choice, got " .. tostring(dialog.text)
    )
    assert(dialog.hideOnEscape and dialog.timeout == 0 and dialog.whileDead, "prompt closes on Esc, never times out, shows while dead")
    assert(#retentionChanges(changes) == 0, "nothing is saved before the player accepts")
  end)

  -- test_accepting_the_shorter_choice_saves_it
  ReloadPopups.With(function()
    local changes = {}
    local settings = create(factory, parent, { messageMaxAge = 90 * DAY }, changes)
    pick(settings, "1 day")
    _G.StaticPopupDialogs[CONFIRM].OnAccept()
    local written = retentionChanges(changes)
    assert(#written == 1 and written[1] == DAY, "accept saves 1 day, got " .. tostring(written[1]))
    assert(closedLabel(settings) == "1 day", "closed dropdown shows the accepted choice, got " .. tostring(closedLabel(settings)))
  end)

  -- test_cancelling_the_shorter_choice_keeps_the_old_value
  ReloadPopups.With(function()
    local changes = {}
    local settings = create(factory, parent, { messageMaxAge = 48 * HOUR }, changes)
    pick(settings, "1 day")
    local dialog = _G.StaticPopupDialogs[CONFIRM]
    if dialog and dialog.OnCancel then
      dialog.OnCancel(nil, nil, "clicked")
    end
    assert(#retentionChanges(changes) == 0, "cancel saves nothing")
    assert(closedLabel(settings) == "48 hours", "closed dropdown keeps the old value, got " .. tostring(closedLabel(settings)))
  end)

  -- test_longer_choice_saves_without_asking
  ReloadPopups.With(function(popups)
    local changes = {}
    local settings = create(factory, parent, { messageMaxAge = 7 * DAY }, changes)
    pick(settings, "30 days")
    assert(#popups.shown == 0, "a longer choice should not ask, got " .. tostring(popups.shown[1]))
    assert(retentionChanges(changes)[1] == 30 * DAY, "a longer choice saves at once")
  end)

  -- test_same_choice_saves_without_asking
  ReloadPopups.With(function(popups)
    local changes = {}
    local settings = create(factory, parent, { messageMaxAge = 7 * DAY }, changes)
    pick(settings, "7 days")
    assert(#popups.shown == 0, "picking the saved choice should not ask, got " .. tostring(popups.shown[1]))
  end)

  -- test_saving_another_choice_closes_the_pending_prompt
  ReloadPopups.With(function(popups)
    local changes = {}
    local settings = create(factory, parent, { messageMaxAge = 90 * DAY }, changes)
    pick(settings, "1 day")
    pick(settings, "Forever")
    assert(contains(popups.hidden, CONFIRM), "a later save closes the stale shorter-choice prompt")
  end)

  -- test_reset_closes_the_pending_prompt
  ReloadPopups.With(function(popups)
    local changes = {}
    local settings = create(factory, parent, { messageMaxAge = 90 * DAY }, changes)
    pick(settings, "1 day")
    FindUI.click(FindUI.byLabel(settings.frame, "Reset to Defaults"))
    assert(contains(popups.hidden, CONFIRM), "reset closes the stale shorter-choice prompt")
  end)

  -- test_set_language_translates_label_and_choices
  do
    local settings = create(factory, parent, { messageMaxAge = DAY }, {})
    settings.setLanguage("deDE")
    local germanLabel = Localization.Text(LABEL, "deDE")
    assert(germanLabel ~= LABEL, "German catalog should translate the retention label")
    assert(closedLabel(settings, germanLabel) == Localization.Text("1 day", "deDE"), "closed dropdown should show the German choice")
  end
end
