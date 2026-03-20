local Types = require("WhisperMessenger.Transport.Types")

return function()
  -- AVAILABILITY_STATUS_BY_CODE
  assert(Types.AVAILABILITY_STATUS_BY_CODE[0] == "CanWhisper")
  assert(Types.AVAILABILITY_STATUS_BY_CODE[1] == "Offline")
  assert(Types.AVAILABILITY_STATUS_BY_CODE[2] == "WrongFaction")

  -- WHISPERABLE
  assert(Types.WHISPERABLE.CanWhisper == true)
  assert(Types.WHISPERABLE.CanWhisperGuild == true)
  assert(Types.WHISPERABLE.Offline == nil)

  -- CHANNELS
  assert(Types.CHANNELS.WOW == "WOW")
  assert(Types.CHANNELS.BN == "BN")
end
