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
  }

  Gateway.SendCharacterWhisper(api, "Arthas-Area52", "hello")

  assert(calls[1].chatType == "WHISPER")
  assert(calls[1].target == "Arthas-Area52")
  assert(calls[1].message == "hello")
end
