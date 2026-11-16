local ContactsList = require("WhisperMessenger.UI.ContactsList")
local MessengerWindow = require("WhisperMessenger.UI.MessengerWindow")
local FakeUI = require("tests.helpers.fake_ui")

-- The message box wraps and grows up to two rows; the chat list gives up
-- exactly the rows the box takes, and the window follows it back down.

local WINDOW_WIDTH = 1100
local WINDOW_HEIGHT = 700
local CONTENT_HEIGHT = 676
local SEPARATOR = 1
local SMALL_WINDOW_HEIGHT = 180
local ONE_ROW_BAR = 44
local TWO_ROW_BAR = 56
local LONG_TEXT_LENGTH = 600
local MESSAGE_COUNT = 40

local function buildMessages()
  local messages = {}
  for index = 1, MESSAGE_COUNT do
    messages[index] = { direction = index % 2 == 0 and "out" or "in", kind = "user", text = "Message " .. index }
  end
  return messages
end

local function build()
  local factory = FakeUI.NewFactory({ wrap = true })
  _G.UIParent = factory.CreateFrame("Frame", "UIParent", nil)
  _G.UIParent:SetSize(1280, 720)
  local contacts = ContactsList.BuildItems({
    ["me::WOW::arthas-area52"] = { displayName = "Arthas-Area52", lastPreview = "hi", lastActivityAt = 1, channel = "WOW" },
  })
  local sent = {}
  local window = MessengerWindow.Create(factory, {
    contacts = contacts,
    selectedContact = contacts[1],
    conversation = { displayName = contacts[1].displayName, messages = buildMessages() },
    onSend = function(payload)
      sent[#sent + 1] = payload
      return true
    end,
  })
  window.frame:SetSize(WINDOW_WIDTH, WINDOW_HEIGHT)
  window.frame.scripts.OnSizeChanged(window.frame, WINDOW_WIDTH, WINDOW_HEIGHT)
  return window, sent
end

local function resize(window, height)
  window.frame:SetSize(WINDOW_WIDTH, height)
  window.frame.scripts.OnSizeChanged(window.frame, WINDOW_WIDTH, height)
end

local function typeText(window, length)
  local input = window.composer.input
  input:SetText(("a"):rep(length))
  input.scripts.OnTextChanged(input, true)
end

local function threadHeightFor(contentHeight, barHeight)
  return contentHeight - barHeight - SEPARATOR
end

return function()
  local savedUIParent = _G.UIParent

  -- test_chat_list_height_follows_the_bar
  do
    local window = build()
    assert(window.composerPane.height == ONE_ROW_BAR, "setup: one-row bar, got " .. tostring(window.composerPane.height))
    typeText(window, LONG_TEXT_LENGTH)
    assert(window.composerPane.height == TWO_ROW_BAR, "bar grows to two rows, got " .. tostring(window.composerPane.height))
    assert(
      window.threadPane.height == threadHeightFor(CONTENT_HEIGHT, TWO_ROW_BAR),
      "chat list shrinks by the bar growth, got " .. tostring(window.threadPane.height)
    )
  end

  -- test_sending_restores_the_list_height
  do
    local window, sent = build()
    typeText(window, LONG_TEXT_LENGTH)
    window.composer.input.scripts.OnEnterPressed(window.composer.input)
    assert(#sent == 1, "setup: the long message was sent")
    assert(
      window.threadPane.height == threadHeightFor(CONTENT_HEIGHT, ONE_ROW_BAR),
      "chat list returns after send, got " .. tostring(window.threadPane.height)
    )
  end

  -- test_small_window_caps_rows_and_restores_them
  do
    local window = build()
    typeText(window, LONG_TEXT_LENGTH)
    resize(window, SMALL_WINDOW_HEIGHT)
    assert(window.composerPane.height == ONE_ROW_BAR, "one row fits a third of the small window, got " .. tostring(window.composerPane.height))
    resize(window, WINDOW_HEIGHT)
    assert(window.composerPane.height == TWO_ROW_BAR, "two rows return, got " .. tostring(window.composerPane.height))
  end

  -- test_list_at_the_bottom_stays_at_the_bottom
  do
    local window = build()
    local scrollFrame = window.conversation.transcript.scrollFrame
    assert(scrollFrame:GetVerticalScrollRange() > 0, "setup: the transcript overflows")
    scrollFrame:SetVerticalScroll(scrollFrame:GetVerticalScrollRange())
    typeText(window, LONG_TEXT_LENGTH)
    assert(window.composerPane.height == TWO_ROW_BAR, "setup: the bar grew, got " .. tostring(window.composerPane.height))
    assert(
      scrollFrame:GetVerticalScroll() == scrollFrame:GetVerticalScrollRange(),
      "list stays at the newest message, scroll " .. scrollFrame:GetVerticalScroll() .. " of " .. scrollFrame:GetVerticalScrollRange()
    )
  end

  -- test_window_bar_height_matches_the_composer_after_every_relayout
  do
    local window = build()
    assert(window.composerPane.height == window.composer.getHeight(), "setup: build, got " .. tostring(window.composerPane.height))
    typeText(window, LONG_TEXT_LENGTH)
    assert(window.composerPane.height == window.composer.getHeight(), "after typing, got " .. tostring(window.composerPane.height))
    resize(window, SMALL_WINDOW_HEIGHT)
    assert(window.composerPane.height == window.composer.getHeight(), "after a resize, got " .. tostring(window.composerPane.height))
    window.composer.input.scripts.OnEnterPressed(window.composer.input)
    assert(window.composerPane.height == window.composer.getHeight(), "after sending, got " .. tostring(window.composerPane.height))
  end

  -- test_scrolled_up_list_keeps_its_position_when_the_bar_grows
  do
    local window = build()
    local scrollFrame = window.conversation.transcript.scrollFrame
    assert(scrollFrame:GetVerticalScrollRange() > 10, "setup: the transcript can scroll past 10")
    scrollFrame:SetVerticalScroll(10)
    window.composer.loadDraft(("a"):rep(LONG_TEXT_LENGTH))
    assert(window.composerPane.height == TWO_ROW_BAR, "setup: the draft grew the bar, got " .. tostring(window.composerPane.height))
    assert(scrollFrame:GetVerticalScroll() == 10, "scrolled-up list keeps its place, got " .. tostring(scrollFrame:GetVerticalScroll()))
  end

  _G.UIParent = savedUIParent
end
