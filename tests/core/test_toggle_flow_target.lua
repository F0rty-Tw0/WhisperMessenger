local ToggleFlow = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.ToggleFlow")

local function build(options)
  options = options or {}
  local case = { sideEffects = 0, visible = options.visible == true }
  local function touch()
    case.sideEffects = case.sideEffects + 1
  end

  local window = options.window
  if window == nil and options.noWindow ~= true then
    window = {
      getTabMode = function()
        return options.tabMode or "whispers"
      end,
      isCompactLayout = options.compact == true,
    }
  end

  case.flow = ToggleFlow.Create({
    runtime = {
      activeConversationKey = options.activeKey,
      store = {
        conversations = {
          ["wow::jaina"] = { channel = "WOW" },
          ["party::me"] = { channel = "PARTY" },
        },
      },
    },
    ensureWindow = touch,
    isWindowVisible = function()
      return case.visible
    end,
    setWindowVisible = function(nextVisible)
      case.visible = nextVisible
      touch()
    end,
    getWindow = function()
      return window
    end,
    findLatestUnreadKey = function(accept)
      if options.unreadKey ~= nil and accept(options.unreadKey) then
        return options.unreadKey
      end

      return nil
    end,
    selectConversation = touch,
    refreshWindow = touch,
  })

  return case
end

return function()
  -- test_open_target_is_the_unread_chat_toggle_selects
  do
    local case = build({ unreadKey = "wow::jaina", activeKey = "party::me" })
    assert(case.flow.openTargetKey() == "wow::jaina")
    assert(case.sideEffects == 0, "openTargetKey must not touch the window")
    assert(case.flow.toggle() == "wow::jaina")
  end

  -- test_open_target_nil_when_window_visible
  do
    local case = build({ visible = true, unreadKey = "wow::jaina" })
    assert(case.flow.openTargetKey() == nil, "a visible window closes, so nothing is shown")
    assert(case.sideEffects == 0)
  end

  -- test_open_target_nil_in_compact_layout
  do
    local case = build({ compact = true, unreadKey = "wow::jaina" })
    assert(case.flow.openTargetKey() == nil, "compact layout opens the list, not a chat")
    assert(case.sideEffects == 0)
  end

  -- test_open_target_falls_back_to_active_key_on_tab
  do
    local case = build({ activeKey = "wow::jaina" })
    assert(case.flow.openTargetKey() == "wow::jaina")
    assert(case.flow.toggle() == "wow::jaina")
  end

  -- test_open_target_nil_when_active_key_on_other_tab
  do
    local case = build({ activeKey = "party::me", tabMode = "whispers" })
    assert(case.flow.openTargetKey() == nil)
    assert(case.flow.toggle() == nil)
  end

  -- test_open_target_without_window_ignores_tab
  do
    local case = build({ noWindow = true, activeKey = "party::me" })
    assert(case.flow.openTargetKey() == "party::me")
    assert(case.sideEffects == 0)
  end
end
