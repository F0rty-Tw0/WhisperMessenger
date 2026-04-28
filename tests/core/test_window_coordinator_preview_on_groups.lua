-- The chat-icon preview popup should appear when an incoming whisper arrives
-- while the window is open on the Groups tab: the whisper conversation is NOT
-- visible in the pane, so the popup is the only place the user sees it.
-- Suppression still applies when the Whispers tab is active (the conversation
-- is already on screen).

local WindowCoordinator = require("WhisperMessenger.Core.Bootstrap.WindowCoordinator")

local function makeWindow(tabMode)
  local shown = true
  local window = {
    frame = { shown = true },
    refreshSelection = function() end,
    getTabMode = function()
      return tabMode
    end,
  }
  function window.frame:IsShown()
    return shown
  end
  return window
end

local function makeRuntime()
  return {
    availabilityByGUID = {},
    availabilityRequestedAt = {},
    now = function()
      return 1000
    end,
    chatApi = {},
    store = { conversations = {} },
  }
end

local function captureIcon()
  local calls = {}
  return {
    setUnreadCount = function() end,
    setIncomingPreview = function(senderName, messageText, classTag)
      calls[#calls + 1] = { senderName = senderName, messageText = messageText, classTag = classTag }
    end,
  },
    calls
end

local SAMPLE_PREVIEW = { senderName = "Arthas", messageText = "gg wp", classTag = "DEATHKNIGHT" }

return function()
  -- test_preview_shown_when_window_open_but_on_groups_tab
  do
    local window = makeWindow("groups")
    local icon, calls = captureIcon()
    local coord = WindowCoordinator.Create({
      runtime = makeRuntime(),
      buildContacts = function()
        return {}
      end,
      getWindow = function()
        return window
      end,
      getIcon = function()
        return icon
      end,
      buildMessagePreview = function()
        return SAMPLE_PREVIEW
      end,
      isMythicRestricted = function()
        return false
      end,
      requestAvailability = function() end,
    })

    coord.refreshContacts()

    assert(#calls == 1, "setIncomingPreview must be called exactly once per refresh; got " .. #calls)
    assert(
      calls[1].messageText == "gg wp",
      "preview must surface when Groups tab is active and whisper is NOT visible in pane; got " .. tostring(calls[1].messageText)
    )
  end

  -- test_preview_suppressed_when_window_open_on_whispers_tab
  do
    local window = makeWindow("whispers")
    local icon, calls = captureIcon()
    local coord = WindowCoordinator.Create({
      runtime = makeRuntime(),
      buildContacts = function()
        return {}
      end,
      getWindow = function()
        return window
      end,
      getIcon = function()
        return icon
      end,
      buildMessagePreview = function()
        return SAMPLE_PREVIEW
      end,
      isMythicRestricted = function()
        return false
      end,
      requestAvailability = function() end,
    })

    coord.refreshContacts()

    assert(#calls == 1, "setIncomingPreview should still be called; got " .. #calls)
    assert(
      calls[1].messageText == nil,
      "preview must remain suppressed on Whispers tab since conversation is on screen; got " .. tostring(calls[1].messageText)
    )
  end

  -- test_preview_shown_when_window_closed
  do
    local window = {
      frame = { shown = false },
      refreshSelection = function() end,
      getTabMode = function()
        return "whispers"
      end,
    }
    function window.frame:IsShown()
      return false
    end
    local icon, calls = captureIcon()
    local coord = WindowCoordinator.Create({
      runtime = makeRuntime(),
      buildContacts = function()
        return {}
      end,
      getWindow = function()
        return window
      end,
      getIcon = function()
        return icon
      end,
      buildMessagePreview = function()
        return SAMPLE_PREVIEW
      end,
      isMythicRestricted = function()
        return false
      end,
      requestAvailability = function() end,
    })

    coord.refreshContacts()

    assert(calls[1].messageText == "gg wp", "regression: preview must show when window is hidden")
  end
end
