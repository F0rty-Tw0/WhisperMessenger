-- Flows builds what the icon surfaces and the key bindings start: the window
-- toggle, the icon click, the preview open and the reply under a preview.

local Flows = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.Flows")

local CONVERSATION_KEY = "wow::WOW::arthas-area52"

local function noop() end

-- log: what the flows did, in order. state.visible: whether the window is up.
local function create(overrides)
  local log = {}
  local state = { visible = false }
  local contacts = { { conversationKey = CONVERSATION_KEY, displayName = "Arthas-Area52", channel = "WOW" } }
  local function record(entry)
    log[#log + 1] = entry
  end
  local runtime = {
    store = { conversations = {} },
    panelRegistry = {
      get = noop,
      firstBadgedKey = noop,
    },
    isCompetitiveContent = function()
      return false
    end,
    isMythicLockdown = function()
      return false
    end,
    isWindowVisible = function()
      return state.visible
    end,
    ensureWindow = function()
      record("runtime.ensureWindow")
    end,
    setWindowVisible = function(visible)
      record("runtime.visible:" .. tostring(visible))
    end,
  }
  local options = {
    runtime = runtime,
    accountState = { settings = {} },
    windowCallbacks = {
      onSend = function(payload)
        record("send:" .. payload.conversationKey .. ":" .. payload.text)
      end,
      onDraftChanged = function(conversationKey, text)
        record("draft:" .. conversationKey .. ":" .. text)
      end,
      onMarkAllRead = noop,
    },
    buildContacts = function()
      return contacts
    end,
    buildLatestIncomingPreview = function(builtContacts)
      assert(builtContacts == contacts, "the preview is built from the current contacts")
      return { conversationKey = CONVERSATION_KEY }
    end,
    acknowledgeLatestWidgetPreview = noop,
    acknowledgeWidgetPreviewThrough = function(sentAt)
      record("acknowledgeThrough:" .. tostring(sentAt))
    end,
    ensureWindow = function()
      record("ensureWindow")
    end,
    isWindowVisible = function()
      return state.visible
    end,
    setWindowVisible = function(visible)
      state.visible = visible
      record("visible:" .. tostring(visible))
    end,
    getWindow = noop,
    findLatestUnreadKey = noop,
    selectConversation = function(conversationKey)
      record("select:" .. tostring(conversationKey))
    end,
    refreshWindow = function()
      record("refresh")
    end,
  }
  for key, value in pairs(overrides or {}) do
    options[key] = value
  end
  local flows = Flows.Create(options)
  return { flows = flows, runtime = runtime, options = options, state = state, log = log }
end

local function joined(log)
  return table.concat(log, ",")
end

return function()
  local function test_toggle_builds_the_window_then_shows_it()
    local built = create()

    built.flows.toggle()

    assert(joined(built.log) == "ensureWindow,visible:true,refresh", "got " .. joined(built.log))
  end

  local function test_toggle_hides_a_visible_window()
    local built = create()
    built.state.visible = true

    built.flows.toggle()

    assert(joined(built.log) == "ensureWindow,visible:false,refresh", "got " .. joined(built.log))
  end

  local function test_toggle_opens_onto_the_latest_unread_chat()
    local built = create({
      findLatestUnreadKey = function()
        return CONVERSATION_KEY
      end,
    })

    local openedKey = built.flows.toggle()

    assert(openedKey == CONVERSATION_KEY, "toggle returns the chat it opened onto")
    assert(joined(built.log) == "ensureWindow,visible:true,select:" .. CONVERSATION_KEY, "got " .. joined(built.log))
  end

  local function test_open_target_key_names_the_chat_a_toggle_would_open()
    local built = create()
    built.runtime.activeConversationKey = CONVERSATION_KEY

    assert(built.flows.openTargetKey() == CONVERSATION_KEY, "the active chat while the window is hidden")
    built.state.visible = true
    assert(built.flows.openTargetKey() == nil, "none while the window is up: the toggle closes it")
    assert(#built.log == 0, "asking touches nothing, got " .. joined(built.log))
  end

  local function test_the_icon_click_runs_the_window_toggle()
    local built = create()

    built.flows.surfaceHandlers.onToggle()

    assert(joined(built.log) == "ensureWindow,visible:true,refresh", "got " .. joined(built.log))
  end

  local function test_the_preview_click_opens_the_window_on_the_latest_whisper()
    local built = create()

    local opened = built.flows.surfaceHandlers.onOpenPreview()

    assert(opened == true, "the open reports success")
    assert(joined(built.log) == "runtime.ensureWindow,runtime.visible:true,select:" .. CONVERSATION_KEY, "got " .. joined(built.log))
  end

  local function test_a_quick_reply_sends_through_the_window_callbacks_and_acknowledges()
    local built = create()
    local quickReply = built.flows.surfaceHandlers.quickReply

    local accepted = quickReply.onSubmit({ conversationKey = CONVERSATION_KEY, sentAt = 42 }, "hello")

    assert(accepted == true, "the reply is accepted")
    assert(joined(built.log) == "send:" .. CONVERSATION_KEY .. ":hello,acknowledgeThrough:42", "got " .. joined(built.log))
  end

  local function test_a_quick_reply_draft_is_saved_through_the_window_callbacks()
    local built = create()

    built.flows.surfaceHandlers.quickReply.onSaveDraft({ conversationKey = CONVERSATION_KEY }, "half a tho")

    assert(joined(built.log) == "draft:" .. CONVERSATION_KEY .. ":half a tho", "got " .. joined(built.log))
  end

  local function test_opening_from_the_reply_row_goes_through_the_preview_open()
    local built = create()

    local opened = built.flows.surfaceHandlers.quickReply.onOpen({ conversationKey = CONVERSATION_KEY })

    assert(opened == true, "the open reports success")
    assert(joined(built.log) == "runtime.ensureWindow,runtime.visible:true,select:" .. CONVERSATION_KEY, "got " .. joined(built.log))
  end

  local function test_the_surfaces_get_the_callers_mark_all_read_acknowledge_and_refresh()
    local built = create()
    local handlers = built.flows.surfaceHandlers

    assert(handlers.onMarkAllRead == built.options.windowCallbacks.onMarkAllRead, "mark all read is the window callback")
    assert(handlers.acknowledgeLatestWidgetPreview == built.options.acknowledgeLatestWidgetPreview, "the acknowledge passes through")
    assert(handlers.refreshWindow == built.options.refreshWindow, "the refresh passes through")
  end

  test_toggle_builds_the_window_then_shows_it()
  test_toggle_hides_a_visible_window()
  test_toggle_opens_onto_the_latest_unread_chat()
  test_open_target_key_names_the_chat_a_toggle_would_open()
  test_the_icon_click_runs_the_window_toggle()
  test_the_preview_click_opens_the_window_on_the_latest_whisper()
  test_a_quick_reply_sends_through_the_window_callbacks_and_acknowledges()
  test_a_quick_reply_draft_is_saved_through_the_window_callbacks()
  test_opening_from_the_reply_row_goes_through_the_preview_open()
  test_the_surfaces_get_the_callers_mark_all_read_acknowledge_and_refresh()
end
