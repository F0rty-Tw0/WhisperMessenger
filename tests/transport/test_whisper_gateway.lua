local Gateway = require("WhisperMessenger.Transport.WhisperGateway")

return function()
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
end
