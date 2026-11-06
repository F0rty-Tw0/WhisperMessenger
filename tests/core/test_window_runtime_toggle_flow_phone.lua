local ToggleFlow = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.ToggleFlow")

local function build(window, visible)
  local case = { selections = {}, order = {}, visible = visible == true }
  case.window = window
  window.showPhoneList = function()
    case.order[#case.order + 1] = "list"
  end
  case.flow = ToggleFlow.Create({
    runtime = { activeConversationKey = "old" },
    isWindowVisible = function()
      return case.visible
    end,
    setWindowVisible = function(nextVisible)
      case.visible = nextVisible
      case.order[#case.order + 1] = nextVisible and "show" or "hide"
    end,
    getWindow = function()
      return window
    end,
    findLatestUnreadKey = function()
      return "unread"
    end,
    selectConversation = function(key)
      case.selections[#case.selections + 1] = key == nil and "none" or key
      case.order[#case.order + 1] = "select"
    end,
  })
  return case
end

return function()
  -- test_phone_toggle_opens_on_the_list_even_with_unread_chats
  do
    local case = build({ isPhoneLayout = true })
    case.flow.toggle()
    assert(case.selections[1] == "none" and #case.selections == 1, "no chat opens by itself")
    assert(table.concat(case.order, ",") == "select,list,show", "the list is in place before the window shows: " .. table.concat(case.order, ","))
  end

  -- test_phone_toggle_closes_an_open_window
  do
    local case = build({ isPhoneLayout = true }, true)
    case.flow.toggle()
    assert(case.visible == false, "closes")
    assert(#case.selections == 0, "closing leaves the selection")
  end

  -- test_classic_toggle_still_jumps_to_the_unread_chat
  do
    local case = build({})
    case.flow.toggle()
    assert(case.selections[1] == "unread", "classic behaviour is unchanged")
  end
end
