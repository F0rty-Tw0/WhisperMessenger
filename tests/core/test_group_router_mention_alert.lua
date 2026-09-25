local Store = require("WhisperMessenger.Model.ConversationStore")
local EventBridge = require("WhisperMessenger.Core.Bootstrap.EventBridge")

-- A group line naming the player alerts with sound + taskbar flash, even in a
-- muted conversation; ordinary group lines stay silent. Never auto-opens.

local function guildLine(runtime, text)
  return EventBridge.RouteGroupEvent(runtime, "CHAT_MSG_GUILD", text, "Jaina-Area52", "", "", "", "", 0, 0, "", 0, 5, "Player-1-JAINA")
end

return function()
  local flashes, sounds, autoOpens = 0, 0, 0
  local savedUnitName = _G.UnitName
  rawset(_G, "UnitName", function()
    return "Arthas"
  end)
  rawset(_G, "FlashClientIcon", function()
    flashes = flashes + 1
  end)
  rawset(_G, "PlaySound", function()
    sounds = sounds + 1
  end)

  local runtime = {
    localProfileId = "arthas-area52",
    localPlayerGuid = "Player-1-SELF",
    store = Store.New({ maxMessagesPerConversation = 50 }),
    accountState = { settings = { playSoundOnWhisper = true, autoOpenIncoming = true } },
    onAutoOpen = function()
      autoOpens = autoOpens + 1
    end,
  }

  -- test_plain_group_line_is_silent
  guildLine(runtime, "anyone for Arathi?")
  assert(flashes == 0 and sounds == 0, "no alert without a mention")

  -- test_mention_plays_sound_and_flashes
  guildLine(runtime, "Arthas can you tank?")
  assert(flashes == 1, "mention flashes the taskbar, got " .. flashes)
  assert(sounds == 1, "mention plays the notification sound, got " .. sounds)
  assert(autoOpens == 0, "mentions never auto-open the window")

  -- test_mention_breaks_through_mute
  runtime.store.conversations["guild::arthas-area52"].muted = true
  guildLine(runtime, "arthas?")
  assert(flashes == 2 and sounds == 2, "muted group still alerts on a mention")

  -- test_flash_setting_off_applies_to_mentions
  runtime.accountState.settings.flashTaskbarOnWhisper = false
  guildLine(runtime, "arthas!!")
  assert(flashes == 2 and sounds == 3, "flash setting off: sound only")

  rawset(_G, "UnitName", savedUnitName)
  rawset(_G, "FlashClientIcon", nil)
  rawset(_G, "PlaySound", nil)
end
