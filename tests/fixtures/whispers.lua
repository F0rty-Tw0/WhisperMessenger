return {
  incoming = {
    eventName = "CHAT_MSG_WHISPER",
    payload = {
      text = "hi there",
      playerName = "Arthas-Area52",
      lineID = 101,
      guid = "Player-3676-0ABCDEF0",
    },
  },
  inform = {
    eventName = "CHAT_MSG_WHISPER_INFORM",
    payload = {
      text = "hello back",
      playerName = "Arthas-Area52",
      lineID = 102,
      guid = "Player-3676-0ABCDEF0",
    },
  },
  afk = {
    eventName = "CHAT_MSG_AFK",
    payload = {
      text = "Away from keyboard",
      playerName = "Arthas-Area52",
      lineID = 103,
      guid = "Player-3676-0ABCDEF0",
    },
  },
  availability = {
    eventName = "CAN_LOCAL_WHISPER_TARGET_RESPONSE",
    payload = {
      guid = "Player-3676-0ABCDEF0",
      status = "Offline",
    },
  },
}
