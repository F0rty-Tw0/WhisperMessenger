local FakeUI = require("tests.helpers.fake_ui")
local FakeChatLines = require("tests.helpers.fake_chat_lines")
local LockdownCatcher = require("WhisperMessenger.Core.Bootstrap.LockdownCatcher")

local SECRET = FakeChatLines.SECRET
local RECEIVED_AT = 500

local function newCatcher(inMythic)
  return LockdownCatcher.New({
    isMythicContent = function()
      return inMythic == true
    end,
    now = function()
      return RECEIVED_AT
    end,
  })
end

-- Event args after the event name: 1 text, 2 sender, 11 line ID, 12 GUID, 13 BNet account ID.
local function whisper(catcher, eventName, overrides)
  local a = { text = "hi", sender = "Arthas-Area52", lineID = 7, guid = "Player-1-ABC", bnetID = 12 }
  for key, value in pairs(overrides or {}) do
    a[key] = value
  end
  catcher.handle(eventName, a.text, a.sender, nil, nil, nil, nil, nil, nil, nil, nil, a.lineID, a.guid, a.bnetID)
end

local function installWithFakeFrame(Bootstrap)
  local factory = FakeUI.NewFactory()
  local created
  local catcher = LockdownCatcher.Install({
    createFrame = function(frameType, name, parent)
      created = factory.CreateFrame(frameType, name, parent)
      return created
    end,
    Bootstrap = Bootstrap,
  })
  assert(catcher ~= nil, "install must return the catcher")
  assert(created ~= nil, "install must create its own frame")
  return catcher, created
end

local function heldCount(catcher)
  local lines = catcher.drain()
  return #lines
end

return function()
  local restore = FakeChatLines.Install({})

  -- test_holds_character_whisper_with_secret_text

  do
    local catcher = newCatcher()
    whisper(catcher, "CHAT_MSG_WHISPER", { text = SECRET })
    local lines, lost = catcher.drain()
    assert(#lines == 1, "secret text must be held, got " .. #lines)
    local line = lines[1]
    assert(line.event == "CHAT_MSG_WHISPER", "held line keeps the event, got " .. tostring(line.event))
    assert(line.lineID == 7, "held line keeps the line ID, got " .. tostring(line.lineID))
    assert(line.receivedAt == RECEIVED_AT, "held line keeps the receive time, got " .. tostring(line.receivedAt))
    assert(line.incoming == true, "CHAT_MSG_WHISPER is incoming")
    assert(lost == 0, "nothing lost under the cap, got " .. tostring(lost))
  end

  -- test_holds_character_whisper_with_secret_sender

  do
    local catcher = newCatcher()
    whisper(catcher, "CHAT_MSG_WHISPER_INFORM", { sender = SECRET })
    local lines = catcher.drain()
    assert(#lines == 1, "secret sender must be held, got " .. #lines)
    assert(lines[1].incoming == false, "CHAT_MSG_WHISPER_INFORM is not incoming")
  end

  -- test_holds_character_whisper_with_secret_guid

  do
    local catcher = newCatcher()
    whisper(catcher, "CHAT_MSG_WHISPER", { guid = SECRET })
    assert(heldCount(catcher) == 1, "secret GUID must be held for a character whisper")
  end

  -- test_holds_bnet_whisper_with_secret_account_id

  do
    local catcher = newCatcher()
    whisper(catcher, "CHAT_MSG_BN_WHISPER", { bnetID = SECRET })
    local lines = catcher.drain()
    assert(#lines == 1, "secret BNet account ID must be held, got " .. #lines)
    assert(lines[1].incoming == true, "CHAT_MSG_BN_WHISPER is incoming")
  end

  -- test_ignores_bnet_whisper_with_only_arg12_secret

  do
    local catcher = newCatcher()
    whisper(catcher, "CHAT_MSG_BN_WHISPER", { guid = SECRET })
    assert(catcher.isEmpty(), "BNet whisper with only arg 12 secret is filed live, not held")
  end

  -- test_holds_readable_whisper_while_in_mythic

  do
    local catcher = newCatcher(true)
    whisper(catcher, "CHAT_MSG_WHISPER", {})
    assert(heldCount(catcher) == 1, "readable whisper must be held while in mythic content")
  end

  -- test_ignores_readable_whisper_outside_mythic

  do
    local catcher = newCatcher(false)
    whisper(catcher, "CHAT_MSG_WHISPER", {})
    assert(catcher.isEmpty(), "readable whisper outside mythic content is filed live, not held")
  end

  -- test_ignores_secret_line_id

  do
    local catcher = newCatcher(true)
    whisper(catcher, "CHAT_MSG_WHISPER", { text = SECRET, lineID = SECRET })
    assert(catcher.isEmpty(), "a secret line ID cannot be replayed, so it is not held")
  end

  -- test_ignores_non_number_line_id

  do
    local catcher = newCatcher(true)
    whisper(catcher, "CHAT_MSG_WHISPER", { text = SECRET, lineID = "7" })
    assert(catcher.isEmpty(), "a non-number line ID is not held")
  end

  -- test_counts_incoming_past_cap_as_lost

  do
    local catcher = newCatcher()
    for lineID = 1, LockdownCatcher.CAP + 1 do
      whisper(catcher, "CHAT_MSG_WHISPER", { text = SECRET, lineID = lineID })
    end
    local lines, lost = catcher.drain()
    assert(#lines == LockdownCatcher.CAP, "holds at most CAP lines, got " .. #lines)
    assert(lost == 1, "incoming past the cap counts as lost, got " .. tostring(lost))
  end

  -- test_inform_past_cap_not_counted

  do
    local catcher = newCatcher()
    for lineID = 1, LockdownCatcher.CAP + 1 do
      whisper(catcher, "CHAT_MSG_WHISPER_INFORM", { text = SECRET, lineID = lineID })
    end
    local lines, lost = catcher.drain()
    assert(#lines == LockdownCatcher.CAP, "holds at most CAP lines, got " .. #lines)
    assert(lost == 0, "outgoing past the cap is not counted as lost, got " .. tostring(lost))
  end

  -- test_drain_clears_queue_and_lost

  do
    local catcher = newCatcher()
    for lineID = 1, LockdownCatcher.CAP + 1 do
      whisper(catcher, "CHAT_MSG_WHISPER", { text = SECRET, lineID = lineID })
    end
    catcher.drain()
    assert(catcher.isEmpty(), "drain must empty the queue")
    local lines, lost = catcher.drain()
    assert(#lines == 0 and lost == 0, "second drain returns nothing, got " .. #lines .. " lines, " .. tostring(lost) .. " lost")
  end

  -- test_install_registers_four_events_on_own_frame

  do
    local loadFrame = {}
    local Bootstrap = { _loadFrame = loadFrame }
    local catcher, frame = installWithFakeFrame(Bootstrap)
    assert(catcher ~= nil, "install must return the catcher")
    assert(Bootstrap._lockdownCatcher == catcher, "install must set Bootstrap._lockdownCatcher")
    assert(Bootstrap._loadFrame == loadFrame, "install must not touch the load frame")
    for _, name in ipairs({ "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM", "CHAT_MSG_BN_WHISPER", "CHAT_MSG_BN_WHISPER_INFORM" }) do
      assert(frame:IsEventRegistered(name), "catcher frame must register " .. name)
    end
    assert(frame:GetName() == "WhisperMessengerLockdownCatcher", "catcher has its own named frame, got " .. tostring(frame:GetName()))
  end

  -- test_installed_frame_routes_whispers_to_catcher

  do
    local Bootstrap = { _inMythicContent = true, runtime = {
      now = function()
        return 900
      end,
    } }
    local catcher, frame = installWithFakeFrame(Bootstrap)
    local onEvent = frame:GetScript("OnEvent")
    assert(type(onEvent) == "function", "install must set an OnEvent script")
    onEvent(frame, "CHAT_MSG_WHISPER", "hi", "Arthas-Area52", nil, nil, nil, nil, nil, nil, nil, nil, 9, "Player-1-ABC")
    local lines = catcher.drain()
    assert(#lines == 1, "OnEvent must hold a readable whisper while Bootstrap is in mythic content, got " .. #lines)
    assert(lines[1].receivedAt == 900, "held time comes from runtime.now, got " .. tostring(lines[1].receivedAt))
  end

  -- test_install_skipped_without_issecretvalue

  do
    local savedSecret = _G.issecretvalue
    _G.issecretvalue = nil
    local created = 0
    local Bootstrap = {}
    local catcher = LockdownCatcher.Install({
      createFrame = function()
        created = created + 1
        return {}
      end,
      Bootstrap = Bootstrap,
    })
    _G.issecretvalue = savedSecret
    assert(catcher == nil, "install must be skipped without issecretvalue")
    assert(created == 0, "install must create no frame without issecretvalue, got " .. created)
    assert(Bootstrap._lockdownCatcher == nil, "install must not set the catcher without issecretvalue")
  end

  -- test_handler_starts_no_ticker

  do
    local catcher = newCatcher(true)
    for lineID = 1, 3 do
      whisper(catcher, "CHAT_MSG_WHISPER", { text = SECRET, lineID = lineID })
    end
    assert(#FakeChatLines.ticks == 0, "the catcher must not start a ticker, got " .. #FakeChatLines.ticks)
  end

  restore()
end
