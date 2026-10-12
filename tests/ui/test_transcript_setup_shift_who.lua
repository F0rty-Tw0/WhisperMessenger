local PlayerMenu = require("WhisperMessenger.UI.ChatBubble.PlayerMenu")
local TranscriptSetup = require("WhisperMessenger.UI.ConversationPane.TranscriptSetup")

-- Shift + left-click on a sender in a group/channel chat sends /who instead
-- of opening the player menu. Whisper chats are covered by the header.

local function bind(channel, whoPlayer)
  local transcript = {}
  local view = { _selectedContact = channel and { channel = channel } or nil }
  TranscriptSetup.BindPlayerMenu(transcript, view, { whoPlayer = whoPlayer })
  return transcript
end

local function click(transcript, message, button, shift)
  local menuOpened = 0
  local originalOpen = PlayerMenu.Open
  local originalShift = _G.IsShiftKeyDown
  rawset(PlayerMenu, "Open", function()
    menuOpened = menuOpened + 1
    return true
  end)
  _G.IsShiftKeyDown = function()
    return shift
  end
  transcript.openPlayerMenu(message, {}, button)
  rawset(PlayerMenu, "Open", originalOpen)
  _G.IsShiftKeyDown = originalShift
  return menuOpened
end

return function()
  local names = {}
  local function whoPlayer(name)
    names[#names + 1] = name
    return true
  end
  local incoming = { direction = "in", kind = "user", playerName = "Bob" }

  -- test_shift_left_on_channel_sender_sends_who_without_menu
  local menu = click(bind("CHANNEL", whoPlayer), incoming, "LeftButton", true)
  assert(#names == 1 and names[1] == "Bob", "who sent for Bob")
  assert(menu == 0, "menu not opened")

  -- test_shift_left_in_whisper_chat_does_nothing
  names = {}
  menu = click(bind("WOW", whoPlayer), incoming, "LeftButton", true)
  assert(#names == 0 and menu == 0, "whisper chat: no who, no menu")

  -- test_shift_left_on_own_line_does_nothing
  menu = click(bind("CHANNEL", whoPlayer), { direction = "out", kind = "user", playerName = "Me" }, "LeftButton", true)
  assert(#names == 0 and menu == 0, "own line: no who, no menu")

  -- test_shift_left_on_secret_name_does_nothing
  menu = click(bind("CHANNEL", whoPlayer), { direction = "in", kind = "user", playerName = "|Kq1|k" }, "LeftButton", true)
  assert(#names == 0 and menu == 0, "|K name: no who, no menu")

  -- test_shift_left_without_selected_contact_does_nothing
  menu = click(bind(nil, whoPlayer), incoming, "LeftButton", true)
  assert(#names == 0 and menu == 0, "no contact: no who, no menu")

  -- test_shift_left_without_who_callback_does_not_open_menu
  menu = click(bind("CHANNEL", nil), incoming, "LeftButton", true)
  assert(menu == 0, "no callback: no menu")

  -- test_right_button_opens_menu
  menu = click(bind("CHANNEL", whoPlayer), incoming, "RightButton", false)
  assert(menu == 1 and #names == 0, "right click opens menu")

  -- test_nil_button_opens_menu
  menu = click(bind("CHANNEL", whoPlayer), incoming, nil, false)
  assert(menu == 1 and #names == 0, "nil button opens menu")
end
