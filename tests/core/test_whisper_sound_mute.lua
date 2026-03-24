local FakeUI = require("tests.helpers.fake_ui")
local Bootstrap = require("WhisperMessenger.Bootstrap")

return function()
  local factory = FakeUI.NewFactory()
  local savedUIParent = _G.UIParent
  local savedSlashCmdList = _G.SlashCmdList
  local savedSlash1 = _G.SLASH_WHISPERMESSENGER1
  local savedSlash2 = _G.SLASH_WHISPERMESSENGER2
  local savedPlaySound = _G.PlaySound
  local savedSOUNDKIT = _G.SOUNDKIT

  _G.UIParent = factory.CreateFrame("Frame", "UIParent", nil)
  _G.SlashCmdList = {}
  _G.SLASH_WHISPERMESSENGER1 = nil
  _G.SLASH_WHISPERMESSENGER2 = nil

  -- -----------------------------------------------------------------------
  -- test_suppresses_tell_message_sound
  -- -----------------------------------------------------------------------
  do
    local playedSounds = {}
    _G.SOUNDKIT = { TELL_MESSAGE = 3175 }
    _G.PlaySound = function(soundKitID)
      table.insert(playedSounds, soundKitID)
      return true, 1
    end

    local runtime = Bootstrap.Initialize(factory, {
      accountState = {
        schemaVersion = 1,
        conversations = {},
        contacts = {},
        pendingHydration = {},
        settings = {},
      },
      characterState = {
        window = { x = 0, y = 0, width = 900, height = 560 },
        icon = {},
      },
    })

    -- PlaySound should now be wrapped — tell sound should be suppressed
    local result = _G.PlaySound(3175)
    assert(result == false, "test_suppresses_tell_message_sound: PlaySound(TELL_MESSAGE) should return false")

    -- Other sounds should still play through
    _G.PlaySound(7355)
    local otherPlayed = false
    for _, id in ipairs(playedSounds) do
      if id == 7355 then
        otherPlayed = true
      end
    end
    assert(otherPlayed, "test_suppresses_tell_message_sound: other sounds should still play")

    -- Tell sound should NOT have been passed through
    local tellPlayed = false
    for _, id in ipairs(playedSounds) do
      if id == 3175 then
        tellPlayed = true
      end
    end
    assert(not tellPlayed, "test_suppresses_tell_message_sound: tell sound should NOT have played")
  end

  _G.PlaySound = savedPlaySound
  _G.SOUNDKIT = savedSOUNDKIT
  _G.UIParent = savedUIParent
  _G.SlashCmdList = savedSlashCmdList
  _G.SLASH_WHISPERMESSENGER1 = savedSlash1
  _G.SLASH_WHISPERMESSENGER2 = savedSlash2
end
