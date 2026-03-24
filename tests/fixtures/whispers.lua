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
      -- Use a different guid than the whisper fixture so the "don't downgrade
      -- confirmed-by-whisper" guard in EventRouter does not suppress this event.
      guid = "Player-3676-0ABCDEF1",
      status = "Offline",
    },
  },
}
