-- With "Esc closes the window" off, the composer's Esc only clears focus; it never closes the window.
local FakeUI = require("tests.helpers.fake_ui")
local ConversationPane = require("WhisperMessenger.UI.ConversationPane")
local ComposerRuntime = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.ComposerRuntime")

local CONVERSATION_KEY = "me::WOW::arthas-area52"

local function build(settingsConfig)
  local factory = FakeUI.NewFactory()
  local frame = factory.CreateFrame("Frame", nil, nil)
  local composerPane = factory.CreateFrame("Frame", nil, frame)
  composerPane:SetSize(400, 80)
  local closeCalls = 0
  local runtime = ComposerRuntime.Create(factory, {
    frame = frame,
    layout = { composerPane = composerPane },
    settingsConfig = settingsConfig,
    windowOptions = {},
    conversation = {},
    messageActions = {
      bind = function() end,
    },
    settingsRuntime = {
      setThemeTargets = function() end,
    },
    closeWindow = function()
      closeCalls = closeCalls + 1
    end,
    refreshContacts = function() end,
  })
  local function closes()
    return closeCalls
  end
  return runtime, closes
end

local function selectConversation(runtime)
  local savedRefresh = ConversationPane.Refresh
  ConversationPane.Refresh = function() end
  runtime.refreshSelection({ selectedContact = { conversationKey = CONVERSATION_KEY, channel = "WOW" }, contacts = {} })
  ConversationPane.Refresh = savedRefresh
end

return function()
  local escapeOff = { escapeClosesWindow = false, doubleEscapeToClose = false }

  -- test_escape_off_composer_esc_clears_focus_only
  do
    local runtime, closes = build(escapeOff)
    local input = runtime.composer.input
    input:SetFocus()
    assert(input:HasFocus() == true, "pre: composer input should be focused")

    input.scripts.OnEscapePressed(input)

    assert(closes() == 0, "Esc off: the composer's Esc must not close the window, closed " .. tostring(closes()))
    assert(input:HasFocus() == false, "Esc off: the composer's Esc should clear focus")
  end

  -- test_escape_off_first_esc_still_clears_reply
  do
    local runtime, closes = build(escapeOff)
    selectConversation(runtime)
    runtime.composer.setReply(CONVERSATION_KEY, { author = "Arthas", text = "hi" })
    local input = runtime.composer.input

    input.scripts.OnEscapePressed(input)

    assert(closes() == 0, "Esc off: clearing a reply must not close the window")
    assert(input:HasFocus() == true, "the first Esc only clears the reply, focus stays")
  end

  -- test_escape_on_composer_esc_still_closes_window
  do
    local runtime, closes = build({ escapeClosesWindow = true, doubleEscapeToClose = false })
    local input = runtime.composer.input
    input:SetFocus()

    input.scripts.OnEscapePressed(input)

    assert(closes() == 1, "Esc on: the composer's Esc closes the window, closed " .. tostring(closes()))
  end
end
