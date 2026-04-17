local Gateway = require("WhisperMessenger.Transport.WhisperGateway")

return function()
  local savedSendChatMessage = _G.SendChatMessage
  local savedBNSendWhisper = _G.BNSendWhisper
  local calls = {}
  local api = {
    SendChatMessage = function(message, chatType, languageID, target)
      table.insert(calls, {
        message = message,
        chatType = chatType,
        languageID = languageID,
        target = target,
      })
    end,
    SendWhisper = function(bnetAccountID, text)
      table.insert(calls, {
        bnetAccountID = bnetAccountID,
        text = text,
        channel = "BN",
      })
      return true
    end,
  }

  Gateway.SendCharacterWhisper(api, "Arthas-Area52", "hello")

  assert(calls[1].chatType == "WHISPER")
  assert(calls[1].target == "Arthas-Area52")
  assert(calls[1].message == "hello")

  Gateway.SendBattleNetWhisper(api, 99, "hello bn")

  assert(calls[2].channel == "BN")
  assert(calls[2].bnetAccountID == 99)
  assert(calls[2].text == "hello bn")

  local legacyCalls = {}
  _G.SendChatMessage = function(message, chatType, languageID, target)
    table.insert(legacyCalls, {
      message = message,
      chatType = chatType,
      languageID = languageID,
      target = target,
      transport = "WOW",
    })
  end
  rawset(_G, "BNSendWhisper", function(bnetAccountID, text)
    table.insert(legacyCalls, {
      bnetAccountID = bnetAccountID,
      text = text,
      transport = "BN",
    })
    return true
  end)

  Gateway.SendCharacterWhisper({}, "Jaina-Area52", "legacy hello")
  local legacyBnResult = Gateway.SendBattleNetWhisper({}, 55, "legacy bn")

  assert(legacyCalls[1].transport == "WOW")
  assert(legacyCalls[1].chatType == "WHISPER")
  assert(legacyCalls[1].target == "Jaina-Area52")
  assert(legacyCalls[1].message == "legacy hello")
  assert(legacyCalls[2].transport == "BN")
  assert(legacyCalls[2].bnetAccountID == 55)
  assert(legacyCalls[2].text == "legacy bn")
  assert(legacyBnResult == true, "expected legacy BNSendWhisper result to be returned")

  _G.SendChatMessage = savedSendChatMessage
  rawset(_G, "BNSendWhisper", savedBNSendWhisper)

  -- test_request_availability_returns_silently_when_api_is_nil
  do
    local ok = pcall(Gateway.RequestAvailability, nil, "guid-1")
    assert(ok, "RequestAvailability should not throw when api is nil")
  end

  -- test_request_availability_returns_silently_when_api_missing_method
  do
    local ok = pcall(Gateway.RequestAvailability, {}, "guid-1")
    assert(ok, "RequestAvailability should not throw when api lacks the request method")
  end

  -- test_request_availability_swallows_errors_from_api_call
  do
    local throwingApi = {
      RequestCanLocalWhisperTarget = function()
        error("C_ChatInfo exploded")
      end,
    }
    local ok = pcall(Gateway.RequestAvailability, throwingApi, "guid-1")
    assert(ok, "RequestAvailability should pcall-wrap the WoW API call")
  end

  -- test_request_availability_forwards_guid_on_success
  do
    local captured = nil
    local api = {
      RequestCanLocalWhisperTarget = function(guid)
        captured = guid
      end,
    }
    Gateway.RequestAvailability(api, "Player-123")
    assert(captured == "Player-123", "RequestAvailability should forward guid to the API")
  end
end
