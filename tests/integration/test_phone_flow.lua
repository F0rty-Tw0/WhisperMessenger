local FakeUI = require("tests.helpers.fake_ui")
local Bootstrap = require("WhisperMessenger.Bootstrap")
local Theme = require("WhisperMessenger.UI.Theme")

-- The phone layout through the real runtime: button, list, chat, back, and
-- what each does to unread counts, drafts and the Mythic pause notice.

local KEY = "wow::WOW::arthas-area52"
local OTHER = "wow::WOW::jaina-area52"
local SLIDE = Theme.LAYOUT.PHONE_SLIDE_SECONDS + 0.01

local function conversation(name, unread)
  return {
    displayName = name,
    channel = "WOW",
    lastActivityAt = os.time(),
    unreadCount = unread,
    messages = { { direction = "in", kind = "user", playerName = name, text = "Need help?", sentAt = os.time() } },
  }
end

local function boot(settings)
  local factory = FakeUI.NewFactory()
  local saved = { uiParent = _G.UIParent, slash = _G.SlashCmdList }
  _G.UIParent = factory.CreateFrame("Frame", "UIParent", nil)
  _G.UIParent:SetSize(1920, 1080)
  _G.UIParent:Show()
  _G.SlashCmdList = {}
  local runtime = Bootstrap.Initialize(factory, {
    localProfileId = "me",
    accountState = {
      schemaVersion = 1,
      conversations = { [KEY] = conversation("Arthas-Area52", 2), [OTHER] = conversation("Jaina-Area52", 0) },
      contacts = {},
      pendingHydration = {},
      settings = settings or {},
    },
    characterState = { window = { x = 0, y = 0, width = 900, height = 560 }, icon = {} },
  })
  return runtime, function()
    _G.UIParent = saved.uiParent
    _G.SlashCmdList = saved.slash
  end
end

local function finishSlide(runtime)
  local viewport = runtime.window.phoneViewport
  if viewport.scripts and viewport.scripts.OnUpdate then
    viewport.scripts.OnUpdate(viewport, SLIDE)
  end
end

local function clickRow(runtime, key)
  for _, row in ipairs(runtime.window.contacts.rows) do
    if row.item and row.item.conversationKey == key then
      row.scripts.OnClick(row, "LeftButton")
      finishSlide(runtime)
      return
    end
  end
  error("no row for " .. key)
end

local function clickBack(runtime)
  local back = runtime.window.backButton
  back.scripts.OnClick(back)
  finishSlide(runtime)
end

local function run(settings, body)
  local runtime, restore = boot(settings)
  local ok, err = pcall(body, runtime)
  restore()
  assert(ok, err)
end

return function()
  -- test_button_opens_the_list_and_leaves_unread_chats_unread
  run(nil, function(runtime)
    runtime.toggle()
    assert(runtime.window.isPhoneLayout, "phone layout is the default")
    assert(runtime.window.frame.shown == true, "opens")
    assert(runtime.window.contactsPane:IsShown(), "on the list")
    assert(runtime.activeConversationKey == nil, "no chat opens by itself")
    assert(runtime.store.conversations[KEY].unreadCount == 2, "unread stays unread until the chat is opened")
  end)

  -- test_opening_a_chat_reads_it_and_back_returns_to_the_list
  run(nil, function(runtime)
    runtime.toggle()
    clickRow(runtime, KEY)
    assert(runtime.activeConversationKey == KEY, "chat open")
    assert(runtime.store.conversations[KEY].unreadCount == 0, "opening reads it")
    assert(runtime.window.contentPane:IsShown(), "chat on screen")
    clickBack(runtime)
    assert(runtime.activeConversationKey == nil, "back leaves the chat")
    assert(runtime.window.contactsPane:IsShown(), "list on screen")
  end)

  -- test_a_whisper_landing_on_the_list_stays_unread
  run(nil, function(runtime)
    runtime.toggle()
    clickRow(runtime, KEY)
    clickBack(runtime)
    assert(runtime.isConversationOpen(KEY) == false, "the list is not the chat, so a new whisper counts as unread")
  end)

  -- test_reopening_after_closing_in_a_chat_starts_on_the_list
  run(nil, function(runtime)
    runtime.toggle()
    clickRow(runtime, KEY)
    runtime.toggle()
    assert(runtime.window.frame.shown == false, "closes")
    runtime.toggle()
    assert(runtime.window.contactsPane:IsShown(), "list again")
    assert(not runtime.window.contentPane:IsShown(), "no chat showing")
    assert(not runtime.window.backButton:IsShown(), "no back button on the list")
  end)

  -- test_a_draft_survives_going_back_to_the_list
  run(nil, function(runtime)
    runtime.toggle()
    clickRow(runtime, KEY)
    local input = runtime.window.composer.input
    input:SetText("half a thought")
    input.scripts.OnTextChanged(input)
    clickBack(runtime)
    clickRow(runtime, OTHER)
    clickBack(runtime)
    clickRow(runtime, KEY)
    assert(runtime.window.composer.input:GetText() == "half a thought", "got " .. tostring(runtime.window.composer.input:GetText()))
  end)

  -- test_mythic_notice_shows_on_the_chat_opened_during_suspend
  run(nil, function(runtime)
    runtime.toggle()
    runtime.suspend()
    runtime.toggle()
    clickRow(runtime, KEY)
    local banner = runtime.window.conversation.activeStatusBanner
    assert(banner.shown == true and banner.text ~= "", "the pause notice shows in the chat")
    assert(runtime.window.composer.sendButton.disabled == true, "sending stays blocked")
    runtime.resume()
  end)

  -- test_classic_setting_keeps_the_classic_window
  run({ phoneLayout = false }, function(runtime)
    runtime.toggle()
    assert(runtime.window.isPhoneLayout == nil, "classic window")
    assert(runtime.activeConversationKey == KEY, "the button still jumps to the unread chat")
  end)

  -- test_the_button_badge_keeps_counting_with_the_window_open
  run(nil, function(runtime)
    runtime.toggle()
    runtime.refreshWindow()
    local badge = runtime.icon.badge
    assert(badge:IsShown(), "the count stays on the button")
    assert(runtime.icon.badgeLabel:GetText() == "2", "got " .. tostring(runtime.icon.badgeLabel:GetText()))
  end)
end
