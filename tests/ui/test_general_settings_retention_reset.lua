local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local GeneralSettings = require("WhisperMessenger.UI.MessengerWindow.GeneralSettings")
local Localization = require("WhisperMessenger.Locale.Localization")
local ReloadPopups = require("tests.helpers.reload_popups")

-- Reset to Defaults sets Message Retention back to 1 day. From a longer
-- retention that deletes older chats, so it asks first, like a shorter pick.

local CONFIRM = "WHISPER_MESSENGER_CONFIRM_SHORTER_RETENTION"
local HOUR = 3600
local DAY = 86400

local function create(factory, parent, config, changes)
  return GeneralSettings.Create(factory, parent, config, {
    onChange = function(key, value)
      changes[#changes + 1] = { key = key, value = value }
    end,
  })
end

local function closedRetention(settings)
  return FindUI.ofType(FindUI.byLabel(settings.frame, "Message Retention"), "Button")[1].label.text
end

local function clickReset(settings)
  FindUI.click(FindUI.byLabel(settings.frame, "Reset to Defaults"))
end

local function changed(changes, key)
  local value
  for _, change in ipairs(changes) do
    if change.key == key then
      value = change.value
    end
  end
  return value
end

return function()
  Localization.Configure({ language = "enUS" })
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", nil, nil)
  parent:SetSize(600, 500)
  local LONG = { messageMaxAge = 90 * DAY, timeFormat = "24h" }

  -- test_reset_from_longer_retention_asks_before_resetting
  ReloadPopups.With(function(popups)
    local changes = {}
    local settings = create(factory, parent, LONG, changes)
    clickReset(settings)
    assert(popups.shown[1] == CONFIRM, "reset to a shorter retention should ask first, got " .. tostring(popups.shown[1]))
    local text = _G.StaticPopupDialogs[CONFIRM].text
    assert(
      text == "Reset this page to its defaults? Chat history is then kept for 1 day only, and older messages are deleted now.",
      "prompt names the reset and the default, got " .. tostring(text)
    )
    assert(#changes == 0, "nothing on the page is reset before the player accepts, got " .. #changes .. " changes")
    assert(closedRetention(settings) == "90 days", "retention still shows the saved choice, got " .. tostring(closedRetention(settings)))
  end)

  -- test_accepting_the_reset_prompt_resets_everything
  ReloadPopups.With(function()
    local changes = {}
    local settings = create(factory, parent, LONG, changes)
    clickReset(settings)
    _G.StaticPopupDialogs[CONFIRM].OnAccept()
    assert(changed(changes, "messageMaxAge") == DAY, "accept resets retention to 1 day, got " .. tostring(changed(changes, "messageMaxAge")))
    assert(changed(changes, "timeFormat") == "12h", "accept resets the rest of the page too")
    assert(closedRetention(settings) == "1 day", "retention shows 1 day after accept, got " .. tostring(closedRetention(settings)))
  end)

  -- test_cancelling_the_reset_prompt_keeps_everything
  ReloadPopups.With(function()
    local changes = {}
    local settings = create(factory, parent, LONG, changes)
    clickReset(settings)
    local dialog = _G.StaticPopupDialogs[CONFIRM]
    if dialog and dialog.OnCancel then
      dialog.OnCancel(nil, nil, "clicked")
    end
    assert(#changes == 0, "cancel resets nothing, got " .. #changes .. " changes")
    assert(closedRetention(settings) == "90 days", "retention keeps the saved choice, got " .. tostring(closedRetention(settings)))
  end)

  -- test_reset_at_or_below_the_default_does_not_ask
  for _, saved in ipairs({ DAY, 6 * HOUR }) do
    ReloadPopups.With(function(popups)
      local changes = {}
      local settings = create(factory, parent, { messageMaxAge = saved, timeFormat = "24h" }, changes)
      clickReset(settings)
      assert(#popups.shown == 0, "reset from " .. saved .. "s should not ask, got " .. tostring(popups.shown[1]))
      assert(changed(changes, "messageMaxAge") == DAY, "reset writes 1 day at once from " .. saved .. "s")
      assert(changed(changes, "timeFormat") == "12h", "reset resets the rest of the page at once")
    end)
  end
end
