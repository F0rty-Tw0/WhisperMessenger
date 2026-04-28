local Types = require("WhisperMessenger.Transport.Types")

return function()
  -- AVAILABILITY_STATUS_BY_CODE (Enum.ChatWhisperTargetStatus: only 3 codes)
  assert(Types.AVAILABILITY_STATUS_BY_CODE[0] == "CanWhisper")
  assert(Types.AVAILABILITY_STATUS_BY_CODE[1] == "Offline")
  assert(Types.AVAILABILITY_STATUS_BY_CODE[2] == "WrongFaction", "code 2 should map to WrongFaction per Enum.ChatWhisperTargetStatus")
  assert(Types.AVAILABILITY_STATUS_BY_CODE[3] == "WrongFaction", "code 3 should map to WrongFaction (observed in-game for opposite-faction players)")

  -- WHISPERABLE
  assert(Types.WHISPERABLE.CanWhisper == true)
  assert(Types.WHISPERABLE.XFaction == true, "XFaction (computed) should be whisperable")
  assert(Types.WHISPERABLE.Away == true)
  assert(Types.WHISPERABLE.Busy == true)
  assert(Types.WHISPERABLE.WrongFaction == nil, "WrongFaction should not be whisperable")
  assert(Types.WHISPERABLE.Offline == nil)

  -- CHANNELS
  assert(Types.CHANNELS.WOW == "WOW")
  assert(Types.CHANNELS.BN == "BN")
end
