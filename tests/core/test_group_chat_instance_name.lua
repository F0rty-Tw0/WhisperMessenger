local Store = require("WhisperMessenger.Model.ConversationStore")
local ConversationSnapshot = require("WhisperMessenger.Model.ConversationSnapshot")
local GroupChatIngest = require("WhisperMessenger.Core.Ingest.GroupChatIngest")
local InstanceName = require("WhisperMessenger.Core.Ingest.GroupChatIngest.InstanceName")

return function()
  local savedIsInInstance = rawget(_G, "IsInInstance")
  local savedGetInstanceInfo = rawget(_G, "GetInstanceInfo")
  local savedIsSecret = rawget(_G, "issecretvalue")

  local function stubInstance(inInstance, name)
    rawset(_G, "IsInInstance", function()
      return inInstance, "party"
    end)
    rawset(_G, "GetInstanceInfo", function()
      return name, "party", 1
    end)
  end

  -- test_current_returns_name_inside_instance
  do
    stubInstance(true, "Halls of Atonement")
    local name = InstanceName.Current()
    assert(name == "Halls of Atonement", "inside an instance the name comes back, got: " .. tostring(name))
  end

  -- test_current_is_nil_outside_instance
  do
    stubInstance(false, "Stormwind City")
    local name = InstanceName.Current()
    assert(name == nil, "outside an instance there is no name, got: " .. tostring(name))
  end

  -- test_empty_name_is_ignored
  do
    stubInstance(true, "")
    assert(InstanceName.Current() == nil, "an empty instance name is no name")
  end

  -- test_secret_name_is_ignored
  do
    stubInstance(true, "Halls of Atonement")
    rawset(_G, "issecretvalue", function()
      return true
    end)
    local name = InstanceName.Current()
    rawset(_G, "issecretvalue", savedIsSecret)
    assert(name == nil, "a secret instance name is ignored, got: " .. tostring(name))
  end

  -- test_secret_check_runs_before_any_comparison
  -- A real 12.0 secret raises on == ""; the harness cannot raise there, so
  -- this checks the secret test sees the name before the empty-name test.
  do
    stubInstance(true, "")
    local checked = false
    rawset(_G, "issecretvalue", function()
      checked = true
      return false
    end)
    InstanceName.Current()
    rawset(_G, "issecretvalue", savedIsSecret)
    assert(checked, "the secret check must run before the name is compared")
  end

  -- test_missing_instance_api_returns_nil
  do
    rawset(_G, "IsInInstance", nil)
    rawset(_G, "GetInstanceInfo", nil)
    assert(InstanceName.Current() == nil, "a client without the instance APIs has no name")
  end

  -- test_instance_api_error_returns_nil
  do
    stubInstance(true, "Halls of Atonement")
    rawset(_G, "IsInInstance", function()
      error("instance API raised")
    end)
    local ok, name = pcall(InstanceName.Current)
    assert(ok, "IsInInstance raising must not escape Current")
    assert(name == nil, "IsInInstance raising gives no name, got: " .. tostring(name))

    stubInstance(true, "Halls of Atonement")
    rawset(_G, "GetInstanceInfo", function()
      error("instance API raised")
    end)
    ok, name = pcall(InstanceName.Current)
    assert(ok, "GetInstanceInfo raising must not escape Current")
    assert(name == nil, "GetInstanceInfo raising gives no name, got: " .. tostring(name))
  end

  local PARTY_GUID = "Party-0-instance"
  local PARTY_KEY = "party::arthas-area52::1::" .. PARTY_GUID

  local function makeState()
    return {
      localProfileId = "arthas-area52",
      store = Store.New({ maxMessagesPerConversation = 50 }),
      groupPartyGUIDsByCategory = { [1] = PARTY_GUID },
      now = function()
        return 100
      end,
    }
  end

  local lineID = 0
  local function sayInParty(state)
    lineID = lineID + 1
    GroupChatIngest.HandleEvent(state, "CHAT_MSG_PARTY", {
      text = "line " .. lineID,
      playerName = "Member-Realm",
      guid = "Player-1084-OTHER",
      lineID = lineID,
    })
    return state.store.conversations[PARTY_KEY]
  end

  -- test_first_line_inside_instance_stamps_name
  do
    stubInstance(true, "Halls of Atonement")
    local conversation = sayInParty(makeState())
    assert(
      conversation.instanceName == "Halls of Atonement",
      "a line inside an instance stamps its name, got: " .. tostring(conversation.instanceName)
    )
  end

  -- test_line_outside_instance_stamps_nothing
  do
    stubInstance(false, "Stormwind City")
    local conversation = sayInParty(makeState())
    assert(conversation.instanceName == nil, "a line outside an instance stamps no name, got: " .. tostring(conversation.instanceName))
  end

  -- test_outside_lines_then_instance_line_stamps_name
  do
    local state = makeState()
    stubInstance(false, "Stormwind City")
    sayInParty(state)
    stubInstance(true, "Halls of Atonement")
    local conversation = sayInParty(state)
    assert(conversation.instanceName == "Halls of Atonement", "the first instance line names the chat, got: " .. tostring(conversation.instanceName))
  end

  -- test_later_instance_keeps_first_name
  do
    local state = makeState()
    stubInstance(true, "Halls of Atonement")
    sayInParty(state)
    stubInstance(true, "Mists of Tirna Scithe")
    local conversation = sayInParty(state)
    assert(conversation.instanceName == "Halls of Atonement", "a later instance keeps the first name, got: " .. tostring(conversation.instanceName))
  end

  -- test_instance_api_error_still_ingests_the_line
  do
    local state = makeState()
    stubInstance(true, "Halls of Atonement")
    rawset(_G, "IsInInstance", function()
      error("instance API raised")
    end)
    local conversation = sayInParty(state)
    assert(conversation ~= nil and #conversation.messages == 1, "a raising instance API must not drop the line")
    assert(conversation.instanceName == nil, "a raising instance API stamps no name")
  end

  -- test_snapshot_carries_instance_name
  do
    stubInstance(true, "Halls of Atonement")
    local conversation = sayInParty(makeState())
    local snapshot = ConversationSnapshot.Build(PARTY_KEY, conversation)
    assert(snapshot.instanceName == "Halls of Atonement", "the snapshot carries the instance name, got: " .. tostring(snapshot.instanceName))
  end

  rawset(_G, "IsInInstance", savedIsInInstance)
  rawset(_G, "GetInstanceInfo", savedGetInstanceInfo)
  rawset(_G, "issecretvalue", savedIsSecret)
end
