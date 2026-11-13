local Composer = require("WhisperMessenger.UI.Composer")
local FakeUI = require("tests.helpers.fake_ui")
local ManualCopyCapture = require("tests.helpers.manual_copy_capture")

-- A protected slash command (/use, /target, /cast, ...) cannot run from addon
-- code: the game blocks it. The composer hands it to the game's chat box for
-- the player to send with Enter, or shows it in the copy dialog when
-- prefilling would taint the game's slash commands. It never runs through the
-- chat box's Enter handler and is never whispered.

local COMMAND_PROMPT = "Press Ctrl+C to copy the command, then paste it into chat."

local function build()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "parent", nil)
  parent:SetSize(600, 50)
  local selectedContact = { conversationKey = "me::WOW::arthas", displayName = "Arthas", channel = "WOW" }
  local sent = {}
  local composer = Composer.Create(factory, parent, selectedContact, function(payload)
    table.insert(sent, payload)
    return true
  end)
  return composer, sent
end

-- A default chat edit box whose Enter handler records the text it would run.
local function fakeChatEditBox()
  local editBox = { text = "", ran = {} }
  function editBox:SetText(text)
    self.text = text
  end
  function editBox:GetText()
    return self.text
  end
  function editBox:GetScript(name)
    if name ~= "OnEnterPressed" then
      return nil
    end
    return function(box)
      table.insert(box.ran, box:GetText())
      box:SetText("")
    end
  end
  return editBox
end

local function press(composer, text)
  composer.input:SetText(text)
  composer.input.scripts.OnEnterPressed(composer.input)
end

local SAVED_GLOBALS = { "DEFAULT_CHAT_FRAME", "ChatFrameUtil", "ChatFrame_OpenChat", "IsSecureCmd", "SlashCmdList" }

-- Game state where /use and /target are protected and prefilling is safe.
local function setup()
  local editBox = fakeChatEditBox()
  local opened = {}
  rawset(_G, "DEFAULT_CHAT_FRAME", { editBox = editBox })
  rawset(_G, "ChatFrame_OpenChat", nil)
  rawset(_G, "ChatFrameUtil", {
    OpenChat = function(text)
      opened[#opened + 1] = text
    end,
  })
  rawset(_G, "IsSecureCmd", function(command)
    local key = string.upper(command)
    return key == "/USE" or key == "/TARGET"
  end)
  rawset(_G, "SlashCmdList", {})
  return editBox, opened
end

return function()
  local saved = {}
  for _, name in ipairs(SAVED_GLOBALS) do
    saved[name] = rawget(_G, name)
  end

  local ok, err = pcall(function()
    -- test_protected_command_prefills_chat_box_for_the_player_to_send
    do
      local editBox, opened = setup()
      local composer, sent = build()
      ManualCopyCapture.With(function(capture)
        press(composer, "/use Hearthstone")
        assert(opened[1] == "/use Hearthstone", "prefills the chat box, got " .. tostring(opened[1]))
        assert(#opened == 1, "opens chat once")
        assert(capture.count == 0, "no copy dialog when prefilling is safe")
      end)
      assert(#editBox.ran == 0, "a protected command never runs through the Enter handler")
      assert(#sent == 0, "a protected command is never whispered")
      assert(composer.input:GetText() == "", "composer cleared after handing off the command")
    end

    -- test_protected_command_check_ignores_case_and_leading_spaces
    do
      local editBox, opened = setup()
      local composer = build()
      press(composer, "  /TARGET Arthas")
      assert(opened[1] == "/TARGET Arthas", "prefills the trimmed command, got " .. tostring(opened[1]))
      assert(#editBox.ran == 0, "never runs through the Enter handler")
    end

    -- test_protected_command_shows_copy_dialog_when_prefill_unsafe
    do
      local editBox, opened = setup()
      rawset(_G, "SlashCmdList", { SOMEADDON = function() end })
      local composer, sent = build()
      ManualCopyCapture.With(function(capture)
        press(composer, "/target Arthas")
        assert(#opened == 0, "unsafe prefill -> chat box not opened")
        assert(capture.count == 1 and capture.text == "/target Arthas", "copy dialog holds the command, got " .. tostring(capture.text))
        local dialog = _G.StaticPopupDialogs.WHISPER_MESSENGER_BUBBLE_COPY_TEXT
        assert(dialog.text == COMMAND_PROMPT, "tells the player to paste it, got " .. tostring(dialog.text))
      end)
      assert(#editBox.ran == 0, "unsafe prefill -> never runs through the Enter handler")
      assert(#sent == 0, "unsafe prefill -> never whispered")
      assert(composer.input:GetText() == "", "composer cleared after handing off the command")
    end

    -- test_unprotected_command_still_runs_directly
    do
      local editBox, opened = setup()
      local composer = build()
      press(composer, "/roll 100")
      assert(editBox.ran[1] == "/roll 100", "runs /roll through the chat box, got " .. tostring(editBox.ran[1]))
      assert(#opened == 0, "an unprotected command is not prefilled")
    end

    -- test_protected_command_without_open_chat_runs_directly_instead_of_vanishing
    do
      local editBox = setup()
      rawset(_G, "ChatFrameUtil", nil)
      rawset(_G, "ChatFrame_OpenChat", nil)
      local composer = build()
      press(composer, "/use Hearthstone")
      assert(editBox.ran[1] == "/use Hearthstone", "no way to open chat -> runs as before, got " .. tostring(editBox.ran[1]))
    end

    -- test_missing_secure_check_runs_command_directly
    do
      local editBox = setup()
      rawset(_G, "IsSecureCmd", nil)
      local composer = build()
      press(composer, "/use Hearthstone")
      assert(editBox.ran[1] == "/use Hearthstone", "no IsSecureCmd -> runs as before, got " .. tostring(editBox.ran[1]))
    end
  end)

  for _, name in ipairs(SAVED_GLOBALS) do
    rawset(_G, name, saved[name])
  end
  assert(ok, err)
end
