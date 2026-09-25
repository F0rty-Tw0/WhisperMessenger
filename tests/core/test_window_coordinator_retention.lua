local WindowCoordinator = require("WhisperMessenger.Core.Bootstrap.WindowCoordinator")
local Store = require("WhisperMessenger.Model.ConversationStore")

local MAX_AGE = 3600

return function()
  local function makeCoordinator(nowValue)
    local shown = false
    local window = { frame = {}, refreshSelection = function() end }
    function window.frame:IsShown()
      return shown
    end
    function window.frame:Show()
      shown = true
    end
    function window.frame:Hide()
      shown = false
    end

    local clock = { value = nowValue }
    local runtime = {
      availabilityByGUID = {},
      availabilityRequestedAt = {},
      now = function()
        return clock.value
      end,
      chatApi = {},
      store = Store.New({ conversationMaxAge = MAX_AGE, messageMaxAge = MAX_AGE }),
    }
    local tickers = {}
    local coord = WindowCoordinator.Create({
      runtime = runtime,
      getWindow = function()
        return window
      end,
      requestAvailability = function() end,
      cTimer = {
        NewTicker = function(_interval, cb)
          local ticker = { cb = cb, Cancel = function() end }
          tickers[#tickers + 1] = ticker
          return ticker
        end,
      },
    })
    return coord, runtime, tickers, clock
  end

  local function idleConversation(lastActivityAt)
    return { messages = {}, unreadCount = 0, lastActivityAt = lastActivityAt }
  end

  -- test_status_tick_expires_idle_conversation_while_window_open
  do
    local coord, runtime, tickers, clock = makeCoordinator(10000)
    runtime.store.conversations["k::idle"] = idleConversation(10000)
    coord.setWindowVisible(true)
    assert(runtime.store.conversations["k::idle"] ~= nil, "fresh conversation is kept on show")

    clock.value = 10000 + MAX_AGE + 1
    tickers[1].cb()

    assert(runtime.store.conversations["k::idle"] == nil, "idle conversation expires on the status tick")
  end

  -- test_showing_window_expires_idle_conversation
  do
    local coord, runtime = makeCoordinator(10000 + MAX_AGE + 1)
    runtime.store.conversations["k::idle"] = idleConversation(10000)

    coord.setWindowVisible(true)

    assert(runtime.store.conversations["k::idle"] == nil, "idle conversation expires when the window opens")
  end
end
