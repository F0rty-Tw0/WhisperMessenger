-- WindowActions builds what drives the window: showing and hiding it,
-- refreshing it, selecting and starting a conversation, and the window
-- callbacks that act through those.

local WindowActions = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.WindowActions")

local CONVERSATION_KEY = "wow::WOW::arthas-area52"

local function noop() end

-- log: what the actions did, in order.
local function create(overrides)
  local log = {}
  local contacts = { { conversationKey = CONVERSATION_KEY } }
  local function record(entry)
    log[#log + 1] = entry
  end
  local runtime = {
    localProfileId = "Player-1234",
    chatApi = {},
    store = { conversations = { [CONVERSATION_KEY] = { channel = "WOW", guid = "Player-1-ABC", messages = {} } } },
    now = function()
      return 1000
    end,
  }
  local options = {
    runtime = runtime,
    accountState = { settings = {} },
    characterState = {},
    defaultCharacterState = {},
    positionSlots = { read = noop, write = noop },
    coordinator = {
      setWindowVisible = function(nextVisible, showOptions)
        record("visible:" .. tostring(nextVisible) .. ":" .. tostring(showOptions))
        return "shown"
      end,
      refreshWindow = function(affectedConversationKey, dirtyKeys)
        record("refresh:" .. tostring(affectedConversationKey) .. ":" .. tostring(dirtyKeys))
        return "refreshed"
      end,
    },
    presenceCache = {
      RefreshPresence = function(guid)
        record("presence:" .. guid)
      end,
    },
    markConversationRead = function(store, conversationKey)
      assert(store == runtime.store, "the runtime store is marked")
      record("read:" .. conversationKey)
    end,
    requestAvailability = function(chatApi, guid)
      assert(chatApi == runtime.chatApi, "availability is asked on the runtime chat api")
      record("availability:" .. guid)
    end,
    getIcon = noop,
    getWindow = noop,
    buildContacts = function()
      return contacts
    end,
    acknowledgeLatestWidgetPreview = function(ackContacts)
      assert(ackContacts == contacts, "the acknowledge gets the current contacts")
      record("acknowledge")
    end,
  }
  for key, value in pairs(overrides or {}) do
    options[key] = value
  end
  local actions = WindowActions.Create(options)
  return { actions = actions, runtime = runtime, options = options, log = log }
end

local function joined(log)
  return table.concat(log, ",")
end

return function()
  local function test_showing_the_window_acknowledges_the_preview_then_asks_the_coordinator()
    local built = create()
    local showOptions = {}

    local result = built.actions.setWindowVisible(true, showOptions)

    assert(joined(built.log) == "acknowledge,visible:true:" .. tostring(showOptions), "got " .. joined(built.log))
    assert(result == "shown", "the coordinator's answer comes back")
  end

  local function test_showing_the_window_hands_visibility_back_after_a_combat_hide()
    local built = create()
    built.runtime.hiddenByCombat = true
    built.runtime.unreadDivider = { conversationKey = CONVERSATION_KEY }

    built.actions.setWindowVisible(true)

    assert(built.runtime.hiddenByCombat == nil, "combat end no longer reopens or closes the window")
    assert(built.runtime.unreadDivider ~= nil, "the divider stays while the window opens")
  end

  local function test_hiding_the_window_acknowledges_the_preview_and_drops_the_unread_divider()
    local built = create()
    built.runtime.hiddenByCombat = true
    built.runtime.unreadDivider = { conversationKey = CONVERSATION_KEY }

    built.actions.setWindowVisible(false)

    assert(joined(built.log) == "acknowledge,visible:false:nil", "got " .. joined(built.log))
    assert(built.runtime.unreadDivider == nil, "the divider is gone on the next open")
    assert(built.runtime.hiddenByCombat == true, "a hide leaves the combat flag alone")
  end

  local function test_refresh_passes_both_arguments_to_the_coordinator()
    local built = create()
    local dirtyKeys = {}

    local result = built.actions.refreshWindow(CONVERSATION_KEY, dirtyKeys)

    assert(joined(built.log) == "refresh:" .. CONVERSATION_KEY .. ":" .. tostring(dirtyKeys), "got " .. joined(built.log))
    assert(result == "refreshed", "the coordinator's answer comes back")
  end

  local function test_selecting_a_conversation_stores_it_marks_it_read_and_refreshes()
    local built = create()

    built.actions.selectConversation(CONVERSATION_KEY)

    assert(built.runtime.activeConversationKey == CONVERSATION_KEY, "the runtime holds the selection")
    assert(built.options.characterState.activeConversationKey == CONVERSATION_KEY, "the character state saves it")
    assert(
      joined(built.log) == "read:" .. CONVERSATION_KEY .. ",presence:Player-1-ABC,availability:Player-1-ABC,refresh:nil:nil",
      "got " .. joined(built.log)
    )
  end

  local function test_starting_a_conversation_selects_the_new_chat()
    local built = create()

    local started = built.actions.startConversation("Jaina")

    local activeKey = built.runtime.activeConversationKey
    assert(started == true, "the start reports success")
    assert(type(activeKey) == "string" and activeKey ~= CONVERSATION_KEY, "a new chat is selected, got " .. tostring(activeKey))
    assert(built.runtime.store.conversations[activeKey] ~= nil, "the chat exists in the store")
  end

  local function test_starting_a_conversation_shows_the_whispers_tab_of_the_built_window()
    local tabMode
    local built = create({
      getWindow = function()
        return {
          setTabMode = function(mode)
            tabMode = mode
          end,
        }
      end,
    })

    built.actions.startConversation("Jaina")

    assert(tabMode == "whispers", "the window switches to whispers, got " .. tostring(tabMode))
  end

  local function test_the_window_close_callback_hides_through_set_window_visible()
    local built = create()

    built.actions.windowCallbacks.onClose()

    assert(joined(built.log) == "acknowledge,visible:false:nil", "got " .. joined(built.log))
  end

  local function test_the_window_select_callback_selects_the_conversation()
    local built = create()

    built.actions.windowCallbacks.onSelectConversation(CONVERSATION_KEY)

    assert(built.runtime.activeConversationKey == CONVERSATION_KEY, "the callback reaches the selector")
  end

  local function test_the_window_start_callback_starts_the_conversation()
    local built = create()

    local started = built.actions.windowCallbacks.onStartConversation("Jaina")

    assert(started == true, "the callback reaches the start flow")
    assert(built.runtime.activeConversationKey ~= nil, "and the new chat is selected")
  end

  local function test_mark_all_read_acknowledges_the_widget_preview_and_refreshes()
    local built = create()

    built.actions.windowCallbacks.onMarkAllRead()

    assert(joined(built.log) == "acknowledge,refresh:nil:nil", "got " .. joined(built.log))
  end

  local function test_the_window_callbacks_send_through_the_given_send_handler()
    local sent
    local built = create({
      sendHandler = {
        HandleSend = function(_runtime, payload)
          sent = payload
          return true
        end,
      },
    })
    local payload = { conversationKey = CONVERSATION_KEY, channel = "BN", text = "hello" }

    built.actions.windowCallbacks.onSend(payload)

    assert(sent == payload, "the payload reaches the send handler")
  end

  test_showing_the_window_acknowledges_the_preview_then_asks_the_coordinator()
  test_showing_the_window_hands_visibility_back_after_a_combat_hide()
  test_hiding_the_window_acknowledges_the_preview_and_drops_the_unread_divider()
  test_refresh_passes_both_arguments_to_the_coordinator()
  test_selecting_a_conversation_stores_it_marks_it_read_and_refreshes()
  test_starting_a_conversation_selects_the_new_chat()
  test_starting_a_conversation_shows_the_whispers_tab_of_the_built_window()
  test_the_window_close_callback_hides_through_set_window_visible()
  test_the_window_select_callback_selects_the_conversation()
  test_the_window_start_callback_starts_the_conversation()
  test_mark_all_read_acknowledges_the_widget_preview_and_refreshes()
  test_the_window_callbacks_send_through_the_given_send_handler()
end
