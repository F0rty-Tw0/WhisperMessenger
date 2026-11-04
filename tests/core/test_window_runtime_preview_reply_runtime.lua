local PreviewReplyRuntime = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.PreviewReplyRuntime")
local WindowCallbacks = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.WindowCallbacks")
local Localization = require("WhisperMessenger.Locale.Localization")

local WOW = {
  conversationKey = "wow::WOW::jaina-area52",
  displayName = "Jaina-Area52",
  channel = "WOW",
  guid = "Player-1",
}
local BN = {
  conversationKey = "bnet::7",
  displayName = "Thrall",
  channel = "BN",
  bnetAccountID = 7,
  conversationID = 3,
  gameAccountName = "Thrall-Area52",
}

local PAYLOAD_FIELDS = {
  "conversationKey",
  "target",
  "displayName",
  "channel",
  "bnetAccountID",
  "conversationID",
  "guid",
  "gameAccountName",
  "text",
}

local function metaFor(contact)
  return { conversationKey = contact.conversationKey, sentAt = 500, channel = contact.channel }
end

-- overrides: sendResult, onSend, competitive, settings
local function build(overrides)
  overrides = overrides or {}
  local log = {}
  local sent = {}
  local runtime = {
    isCompetitiveContent = function()
      return overrides.competitive == true
    end,
    isMythicLockdown = function()
      return false
    end,
    isWindowVisible = function()
      return false
    end,
  }
  local accountState = { settings = overrides.settings }
  local reply = PreviewReplyRuntime.Create({
    runtime = runtime,
    accountState = accountState,
    buildContacts = function()
      return { WOW, BN }
    end,
    onSend = overrides.onSend or function(payload)
      sent[#sent + 1] = payload
      log[#log + 1] = "send"
      return overrides.sendResult
    end,
    setDraft = function(key, text)
      log[#log + 1] = "draft:" .. key .. ":" .. text
    end,
    acknowledgeThrough = function(sentAt)
      log[#log + 1] = "ack:" .. tostring(sentAt)
    end,
    refreshWindow = function()
      log[#log + 1] = "refresh"
    end,
    openConversation = function(key)
      log[#log + 1] = "open:" .. key
      return true
    end,
  })
  return reply, log, sent, accountState
end

local function count(log, entry)
  local n = 0
  for _, value in ipairs(log) do
    if value == entry then
      n = n + 1
    end
  end
  return n
end

return function()
  local function test_payload_comes_from_the_contact_like_the_composer()
    for _, contact in ipairs({ WOW, BN }) do
      local reply, _, sent = build({ sendResult = true })
      reply.submit(metaFor(contact), "  hi ")
      local payload = sent[1]
      assert(payload ~= nil, "a payload was sent for " .. contact.channel)
      local expected = {}
      for _, field in ipairs(PAYLOAD_FIELDS) do
        expected[field] = true
      end
      for key in pairs(payload) do
        assert(expected[key], "unexpected payload field " .. tostring(key))
      end
      assert(payload.conversationKey == contact.conversationKey, "key from the contact")
      assert(payload.target == contact.displayName, "target is the display name")
      assert(payload.displayName == contact.displayName, "display name from the contact")
      assert(payload.channel == contact.channel, "channel from the contact")
      assert(payload.bnetAccountID == contact.bnetAccountID, "bnetAccountID from the contact")
      assert(payload.conversationID == contact.conversationID, "conversationID from the contact")
      assert(payload.guid == contact.guid, "guid from the contact")
      assert(payload.gameAccountName == contact.gameAccountName, "gameAccountName from the contact")
      assert(payload.text == "  hi ", "the raw text is sent untrimmed")
      assert(payload.replyTo == nil, "no reply-to from the preview")
    end
  end

  local function test_missing_contact_returns_false_without_sending()
    local reply, log = build({ sendResult = true })
    local result = reply.submit({ conversationKey = "wow::gone", sentAt = 500, channel = "WOW" }, "hi")
    assert(result == false, "an unknown key does not send")
    assert(#log == 0, "no send and no ack, got " .. table.concat(log, ","))
  end

  local function test_accepted_send_acks_through_meta_sent_at_and_does_not_refresh()
    local reply, log = build({ sendResult = true })
    assert(reply.submit(metaFor(WOW), "hi") == true, "an accepted send reports true")
    assert(count(log, "ack:500") == 1, "acked once through 500, got " .. table.concat(log, ","))
    assert(count(log, "refresh") == 0, "submit does not refresh")
  end

  local function test_nil_result_counts_as_accepted()
    local reply, log = build({ sendResult = nil })
    assert(reply.submit(metaFor(WOW), "hi") == true, "nil passes like the composer's ~= false")
    assert(count(log, "ack:500") == 1, "a nil result acks")
  end

  local function test_rejected_send_does_not_ack()
    local reply, log = build({ sendResult = false })
    assert(reply.submit(metaFor(WOW), "hi") == false, "a rejected send reports false")
    assert(count(log, "ack:500") == 0, "a rejected send does not ack")
  end

  local function test_queued_under_lock_counts_as_sent()
    local refreshes = 0
    local onSend = WindowCallbacks.Create({
      runtime = {},
      sendHandler = {
        HandleSend = function(_runtime, payload, refresh)
          payload.deliveryRecorded = true
          refresh()
          return false
        end,
      },
      refreshWindow = function()
        refreshes = refreshes + 1
      end,
    }).onSend
    local reply, log = build({ onSend = onSend })
    assert(reply.submit(metaFor(BN), "hi") == true, "a queued send counts as sent")
    assert(count(log, "ack:500") == 1, "a queued send acks through 500")
    assert(refreshes == 1, "the send path refreshed on its own")
  end

  local function test_dismiss_through_acks_then_refreshes()
    local reply, log = build()
    reply.dismissThrough(metaFor(WOW))
    assert(table.concat(log, ",") == "ack:500,refresh", "ack then refresh, got " .. table.concat(log, ","))
  end

  local function test_open_refused_returns_false_without_draft()
    local reply, log = build({ competitive = true })
    assert(reply.open(metaFor(WOW), "hi") == false, "a refused open reports false")
    assert(#log == 0, "no draft and no open, got " .. table.concat(log, ","))
  end

  local function test_open_saves_text_then_opens_meta_key()
    local key = WOW.conversationKey
    local reply, log = build()
    assert(reply.open(metaFor(WOW), "hi") == true, "an open reports true")
    local expected = "draft:" .. key .. ":hi,open:" .. key
    assert(table.concat(log, ",") == expected, "draft then open, got " .. table.concat(log, ","))

    local blankReply, blankLog = build()
    blankReply.open(metaFor(WOW), "   ")
    assert(table.concat(blankLog, ",") == "open:" .. key, "whitespace writes no draft, got " .. table.concat(blankLog, ","))
  end

  local function test_save_draft_writes_meta_key()
    local reply, log = build()
    reply.saveDraft(metaFor(WOW), "later")
    assert(log[1] == "draft:" .. WOW.conversationKey .. ":later", "draft on the meta key, got " .. tostring(log[1]))
  end

  local function test_is_enabled_reads_the_live_setting()
    local reply, _, _, accountState = build({ settings = { widgetPreviewReply = true } })
    assert(reply.quickReply.isEnabled() == true, "on when the setting is true")
    accountState.settings = {}
    assert(reply.quickReply.isEnabled() == false, "off once the settings table lacks the key")
  end

  local function test_lock_reason_text_is_localized()
    Localization.Configure({ language = "deDE" })
    local locked = build({ competitive = true })
    local text = locked.quickReply.getLockReasonText()
    assert(text == Localization.Text("Competitive Content"), "localized reason, got " .. tostring(text))
    assert(text ~= "Competitive Content", "the reason is translated, not the raw key")
    Localization.Configure({ language = "enUS" })

    local unlocked = build()
    assert(unlocked.quickReply.getLockReasonText() == nil, "no reason when unlocked")
  end

  local function test_quick_reply_routes_to_the_runtime_functions()
    local reply, log = build()
    local quickReply = reply.quickReply
    assert(quickReply.onSubmit == reply.submit, "onSubmit is submit")
    assert(quickReply.onSaveDraft == reply.saveDraft, "onSaveDraft is saveDraft")
    assert(quickReply.onDismissThrough == reply.dismissThrough, "onDismissThrough is dismissThrough")
    assert(quickReply.onOpen == reply.open, "onOpen is open")
    quickReply.onRefresh()
    assert(table.concat(log, ",") == "refresh", "onRefresh refreshes the window")
  end

  test_payload_comes_from_the_contact_like_the_composer()
  test_missing_contact_returns_false_without_sending()
  test_accepted_send_acks_through_meta_sent_at_and_does_not_refresh()
  test_nil_result_counts_as_accepted()
  test_rejected_send_does_not_ack()
  test_queued_under_lock_counts_as_sent()
  test_dismiss_through_acks_then_refreshes()
  test_open_refused_returns_false_without_draft()
  test_open_saves_text_then_opens_meta_key()
  test_save_draft_writes_meta_key()
  test_is_enabled_reads_the_live_setting()
  test_lock_reason_text_is_localized()
  test_quick_reply_routes_to_the_runtime_functions()
end
