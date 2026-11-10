local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local Localization = require("WhisperMessenger.Locale.Localization")
local WhispersSettings = require("WhisperMessenger.UI.MessengerWindow.WhispersSettings")
local AddonGreetingsSelector = require("WhisperMessenger.UI.MessengerWindow.WhispersSettings.AddonGreetingsSelector")

local PREVIEW = "Show widget message preview"
local REPLY = "Reply from widget preview"

local function create(config)
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  local changes = {}
  local result = WhispersSettings.Create(factory, parent, config, {
    onChange = function(key, value)
      changes[key] = value
    end,
  })
  return result, changes
end

return function()
  Localization.Configure({ language = "enUS" })

  -- test_preview_rows_follow_channel_context
  do
    local result = create({})
    local contextRow = FindUI.byLabel(result.frame, "Show their last channel message")
    local previewRow = FindUI.byLabel(result.frame, PREVIEW)
    local replyRow = FindUI.byLabel(result.frame, REPLY)
    assert(previewRow.points[1][2] == contextRow, "test_preview_rows_follow_channel_context: preview row hangs under Show their last channel message")
    assert(replyRow.points[1][2] == previewRow, "test_preview_rows_follow_channel_context: reply row hangs under the preview row")
  end

  -- test_addon_greetings_sits_under_reply_row
  do
    local result = create({})
    local replyRow = FindUI.byLabel(result.frame, REPLY)
    local greetingsRow = FindUI.byLabel(result.frame, AddonGreetingsSelector.LABEL)
    assert(greetingsRow.points[1][2] == replyRow, "test_addon_greetings_sits_under_reply_row")
  end

  -- test_preview_defaults_on_reply_defaults_off
  do
    local result = create({})
    assert(FindUI.isToggleOn(FindUI.toggle(result.frame, PREVIEW)) == true, "test_preview_defaults_on_reply_defaults_off: preview on")
    assert(FindUI.isToggleOn(FindUI.toggle(result.frame, REPLY)) == false, "test_preview_defaults_on_reply_defaults_off: reply off")
  end

  -- test_preview_toggle_writes_its_key
  do
    local result, changes = create({})
    FindUI.click(FindUI.toggle(result.frame, PREVIEW))
    assert(changes.showWidgetMessagePreview == false, "test_preview_toggle_writes_its_key: got " .. tostring(changes.showWidgetMessagePreview))
  end

  -- test_reply_toggle_writes_its_key
  do
    local result, changes = create({})
    FindUI.click(FindUI.toggle(result.frame, REPLY))
    assert(changes.widgetPreviewReply == true, "test_reply_toggle_writes_its_key: got " .. tostring(changes.widgetPreviewReply))
  end

  -- test_reply_toggle_shows_saved_value
  do
    local result = create({ widgetPreviewReply = true })
    assert(FindUI.isToggleOn(FindUI.toggle(result.frame, REPLY)) == true, "test_reply_toggle_shows_saved_value")
  end

  -- test_reply_disabled_while_preview_off
  do
    local result = create({ showWidgetMessagePreview = false })
    assert(result.widgetPreviewReplyAvailability.isEnabled() == false, "test_reply_disabled_while_preview_off")
  end

  -- test_turning_preview_on_enables_reply
  do
    local result = create({ showWidgetMessagePreview = false })
    FindUI.click(FindUI.toggle(result.frame, PREVIEW))
    assert(result.widgetPreviewReplyAvailability.isEnabled() == true, "test_turning_preview_on_enables_reply")
  end

  -- test_preview_off_then_on_reenables_reply
  do
    local result = create({})
    FindUI.click(FindUI.toggle(result.frame, PREVIEW))
    assert(result.widgetPreviewReplyAvailability.isEnabled() == false, "test_preview_off_then_on_reenables_reply: off disables")
    FindUI.click(FindUI.toggle(result.frame, PREVIEW))
    assert(result.widgetPreviewReplyAvailability.isEnabled() == true, "test_preview_off_then_on_reenables_reply: on re-enables")
  end

  -- test_reset_reenables_reply_and_writes_both_defaults
  do
    local result, changes = create({ showWidgetMessagePreview = false, widgetPreviewReply = true })
    FindUI.click(FindUI.byLabel(result.frame, "Reset to Defaults"))
    assert(result.widgetPreviewReplyAvailability.isEnabled() == true, "test_reset_reenables_reply_and_writes_both_defaults: row enabled")
    assert(changes.showWidgetMessagePreview == true, "test_reset_reenables_reply_and_writes_both_defaults: preview default")
    assert(changes.widgetPreviewReply == false, "test_reset_reenables_reply_and_writes_both_defaults: reply default")
  end
end
