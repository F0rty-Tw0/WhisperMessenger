-- The automatic reopen after combat must not take keyboard focus: the
-- player's movement and ability keys would land in the composer. A player
-- open still focuses the composer when "auto-focus the input" is on.

local MessengerWindow = require("WhisperMessenger.UI.MessengerWindow")
local WindowCoordinator = require("WhisperMessenger.Core.Bootstrap.WindowCoordinator")
local FakeUI = require("tests.helpers.fake_ui")

local function makeHarness()
  local factory = FakeUI.NewFactory()
  local window = MessengerWindow.Create(factory, {
    title = "WhisperMessenger",
    contacts = {},
    settingsConfig = { autoFocusComposer = true },
  })
  window.frame:Hide()
  window.composer.input:ClearFocus()
  local coordinator = WindowCoordinator.Create({
    runtime = {
      availabilityByGUID = {},
      availabilityRequestedAt = {},
      sendStatusByConversation = {},
      now = function()
        return 1000
      end,
      store = { conversations = {} },
    },
    buildContacts = function()
      return {}
    end,
    getWindow = function()
      return window
    end,
    getIcon = function()
      return { setUnreadCount = function() end }
    end,
    presenceCache = { EnsureFresh = function() end },
    requestAvailability = function() end,
    cTimer = {
      NewTicker = function()
        return { Cancel = function() end }
      end,
    },
  })
  return window, coordinator
end

return function()
  -- test_open_without_composer_focus_does_not_focus_composer
  do
    local window, coordinator = makeHarness()

    coordinator.setWindowVisible(true, { focusComposer = false })

    assert(window.frame:IsShown() == true, "the window should open")
    assert(window.composer.input._hasFocus == false, "an open without composer focus must leave keyboard focus alone")
  end

  -- test_player_open_focuses_composer_when_auto_focus_on
  do
    local window, coordinator = makeHarness()

    coordinator.setWindowVisible(true)

    assert(window.composer.input._hasFocus == true, "a player open should focus the composer when auto-focus is on")
  end

  -- test_player_open_after_unfocused_open_focuses_composer_again
  do
    local window, coordinator = makeHarness()
    coordinator.setWindowVisible(true, { focusComposer = false })
    coordinator.setWindowVisible(false)

    coordinator.setWindowVisible(true)

    assert(window.composer.input._hasFocus == true, "the no-focus open must not carry over to the next player open")
  end
end
