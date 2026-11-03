local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local WhisperToasts = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.WhisperToasts")

-- When a whisper may pop a card: the setting is on, the messenger is closed,
-- and nothing (combat, a chat lock, restricted content) blocks it.

local KEY = "me::WOW::jaina-proudmoore"

local function build(overrides)
  overrides = overrides or {}
  local factory = FakeUI.NewFactory()
  local uiParent = factory.CreateFrame("Frame", "UIParent", nil)
  local log = {}
  local runtime
  runtime = {
    store = {
      conversations = {
        [KEY] = {
          displayName = "Jaina-Proudmoore",
          lastIncomingSender = "Jaina-Proudmoore",
          lastIncomingPreview = "meet me in dalaran",
          classTag = "MAGE",
        },
      },
    },
    isCompetitiveContent = function()
      return overrides.competitive == true
    end,
    isMythicLockdown = function()
      return false
    end,
    isWindowVisible = function()
      return overrides.visible == true
    end,
    ensureWindow = function()
      runtime.window = {}
    end,
    setWindowVisible = function(visible)
      log[#log + 1] = "visible:" .. tostring(visible)
    end,
  }
  local settings = { showWhisperToasts = overrides.enabled ~= false, whisperToastCorner = overrides.corner }
  local toasts = WhisperToasts.Create({
    runtime = runtime,
    accountState = { settings = settings },
    uiFactory = factory,
    uiParent = uiParent,
    selectConversation = function(key)
      log[#log + 1] = "select:" .. key
    end,
  })
  return toasts, uiParent, log
end

local function card(uiParent)
  local label = FindUI.text(uiParent, "meet me in dalaran")
  if label and label.parent:IsShown() then
    return label.parent
  end
  return nil
end

return function()
  local savedCombat = rawget(_G, "InCombatLockdown")
  local inCombat = false
  rawset(_G, "InCombatLockdown", function()
    return inCombat
  end)

  -- test_new_whisper_pops_a_card_while_the_window_is_closed
  do
    local toasts, uiParent = build()
    toasts.show(KEY)
    assert(card(uiParent) ~= nil, "a card shows the whisper")
  end

  -- test_setting_off_pops_no_card
  do
    local toasts, uiParent = build({ enabled = false })
    toasts.show(KEY)
    assert(card(uiParent) == nil, "no card while the setting is off")
  end

  -- test_open_window_pops_no_card
  do
    local toasts, uiParent = build({ visible = true })
    toasts.show(KEY)
    assert(card(uiParent) == nil, "no card while the messenger is open")
  end

  -- test_combat_pops_no_card
  do
    inCombat = true
    local toasts, uiParent = build()
    toasts.show(KEY)
    inCombat = false
    assert(card(uiParent) == nil, "no card in combat")
  end

  -- test_chat_lock_or_restricted_content_pops_no_card
  do
    local toasts, uiParent = build({ competitive = true })
    toasts.show(KEY)
    assert(card(uiParent) == nil, "no card while chat is locked or content is restricted")
  end

  -- test_card_uses_the_saved_corner
  do
    local toasts, uiParent = build({ corner = "BOTTOMLEFT" })
    toasts.show(KEY)
    assert(card(uiParent).point[1] == "BOTTOMLEFT", "card anchors to the saved corner")
  end

  -- test_card_defaults_to_top_right
  do
    local toasts, uiParent = build()
    toasts.show(KEY)
    assert(card(uiParent).point[1] == "TOPRIGHT", "default corner is top-right")
  end

  -- test_clicking_a_card_opens_that_conversation
  do
    local toasts, uiParent, log = build()
    toasts.show(KEY)
    FindUI.click(card(uiParent))
    assert(table.concat(log, ",") == "visible:true,select:" .. KEY, "click opens the messenger on that chat, got " .. table.concat(log, ","))
    assert(card(uiParent) == nil, "the clicked card is gone")
  end

  -- test_clear_removes_cards
  do
    local toasts, uiParent = build()
    toasts.show(KEY)
    toasts.clear()
    assert(card(uiParent) == nil, "clear removes the cards")
  end

  rawset(_G, "InCombatLockdown", savedCombat)
end
