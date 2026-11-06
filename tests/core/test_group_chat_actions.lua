local GroupChatActions = require("WhisperMessenger.Core.GroupChat.GroupChatActions")
local GroupChatService = require("WhisperMessenger.Core.GroupChat.GroupChatService")
local GroupChatEnv = require("tests.helpers.group_chat_env")

local function setup()
  local env = GroupChatEnv.New()
  local service = GroupChatService.Create({ runtime = env.runtime, timer = env.timer })
  local log = { printed = {}, selected = {}, refreshed = {}, tab = nil, visible = false }
  env.runtime.ensureWindow = function()
    env.runtime.window = {
      setTabMode = function(mode)
        log.tab = mode
      end,
    }
  end
  env.runtime.setWindowVisible = function(visible)
    log.visible = visible
  end
  env.runtime.refreshWindow = function(key)
    log.refreshed[#log.refreshed + 1] = key or "all"
  end
  local actions = GroupChatActions.Create({
    runtime = env.runtime,
    service = service,
    windowRuntime = {
      selectConversation = function(key)
        log.selected[#log.selected + 1] = key
      end,
    },
    print = function(text)
      log.printed[#log.printed + 1] = text
    end,
  })
  return env, service, actions, log
end

return function()
  -- test_create_and_open_shows_the_new_chat_on_the_groups_tab
  do
    local env, service, actions, log = setup()
    assert(actions.CreateAndOpen("Anna") == true)
    assert(log.visible == true and log.tab == "groups", "window shown on Groups")
    assert(service.FindByConversationKey(log.selected[1]) ~= nil, "the new chat is selected")
    env.restore()
  end

  -- test_refusals_are_printed
  do
    local env, _, actions, log = setup()
    assert(actions.CreateAndOpen("  ") == false)
    assert(log.printed[1] == "Enter at least one player name.")
    assert(actions.SlashCommand("") == false)
    assert(log.printed[2] == "To start a group chat: /wmsg group Name, Name-Realm")
    env.restore()
  end

  -- test_candidates_come_from_the_friend_lists_minus_self
  do
    local env, service = setup()
    local actions = GroupChatActions.Create({
      runtime = env.runtime,
      service = service,
      friendEnv = {
        friendList = {
          GetNumFriends = function()
            return 3
          end,
          GetFriendInfoByIndex = function(index)
            return ({ { name = "Anna", connected = true }, { name = "Me", connected = true }, { name = "Bela-Kazzak", connected = true } })[index]
          end,
        },
      },
    })
    local candidates = actions.Candidates({ "Anna" })
    assert(#candidates == 1 and candidates[1].name == "Bela", "self and excluded left out, local realm dropped")
    env.restore()
  end

  -- test_menu_actions_change_the_group_and_redraw
  do
    local env, service, actions, log = setup()
    actions.SlashCommand("Anna")
    local item = { conversationKey = log.selected[1] }
    assert(actions.CanManage(item))
    assert(actions.AddMembers(item, "Bela") == true)
    assert(actions.Rename(item, "Crew") == true)
    assert(service.FindByConversationKey(item.conversationKey).name == "Crew")
    assert(actions.Leave(item) == true)
    assert(not actions.CanManage(item), "a left chat has nothing to manage")
    assert(actions.Members(item)[1] == "Anna" and actions.Members(item)[2] == "Bela", "members for the picker")
    assert(#log.refreshed == 3, "each change redraws")
    assert(actions.AddMembers(item, "Csilla") == false, "a left chat takes nobody")
    assert(actions.CanManage({ conversationKey = "wow::WOW::anna" }) == false, "whisper rows are not group chats")
    env.restore()
  end
end
