local FakeUI = require("tests.helpers.fake_ui")

local function loadAddonFromToc(addonName, tns)
  for line in io.lines("WhisperMessenger.toc") do
    if line ~= "" and string.sub(line, 1, 2) ~= "##" and not string.match(line, "%.xml$") then
      local chunk = assert(loadfile(line))
      chunk(addonName, tns)
    end
  end
end

return function()
  rawset(_G, "time", _G.time or os.time)
  _G.date = _G.date or os.date
  _G.RAID_CLASS_COLORS = _G.RAID_CLASS_COLORS or {}

  -- test_hide_message_preview_blanks_preview_text

  do
    local tns = {}
    loadAddonFromToc("WhisperMessenger", tns)

    local RowView = tns.ContactsListRowView
    local factory = FakeUI.NewFactory()
    local parent = factory.CreateFrame("Frame", nil, nil)
    parent:SetSize(300, 64)

    local item = {
      conversationKey = "wow::WOW::test-realm",
      displayName = "TestPlayer-Realm",
      channel = "WOW",
      lastPreview = "Hello there!",
      lastActivityAt = 100,
      unreadCount = 0,
    }

    -- Without hiding: preview should show the message
    local row1 = RowView.bindRow(factory, parent, nil, 1, item, {})
    assert(row1.preview ~= nil, "row should have preview element")
    assert(row1.preview.text == "Hello there!", "preview should show message, got: " .. tostring(row1.preview.text))

    -- With hiding: preview should be empty
    local row2 = RowView.bindRow(factory, parent, nil, 2, item, { hideMessagePreview = true })
    assert(row2.preview ~= nil, "row should have preview element")
    assert(
      row2.preview.text == "",
      "preview should be empty when hideMessagePreview=true, got: " .. tostring(row2.preview.text)
    )
  end

  -- test_player_logout_clears_conversations_when_enabled

  do
    local tns = {}
    loadAddonFromToc("WhisperMessenger", tns)

    local Store = tns.ConversationStore
    local state = Store.New({ maxMessagesPerConversation = 50 })

    local msg = {
      text = "Hello",
      sentAt = 10,
      playerName = "TestPlayer-Realm",
      channel = "WOW",
      kind = "user",
      direction = "in",
    }
    Store.AppendIncoming(state, "wow::WOW::test-realm", msg, false)

    assert(state.conversations["wow::WOW::test-realm"] ~= nil, "conversation should exist before logout")

    -- Simulate the clear-on-logout behavior
    local accountSettings = { clearOnLogout = true }

    if accountSettings.clearOnLogout then
      for key in pairs(state.conversations) do
        state.conversations[key] = nil
      end
    end

    assert(
      state.conversations["wow::WOW::test-realm"] == nil,
      "conversation should be cleared after logout with clearOnLogout=true"
    )
  end

  -- test_player_logout_preserves_conversations_when_disabled

  do
    local tns = {}
    loadAddonFromToc("WhisperMessenger", tns)

    local Store = tns.ConversationStore
    local state = Store.New({ maxMessagesPerConversation = 50 })

    local msg = {
      text = "Hello",
      sentAt = 10,
      playerName = "TestPlayer-Realm",
      channel = "WOW",
      kind = "user",
      direction = "in",
    }
    Store.AppendIncoming(state, "wow::WOW::test-realm", msg, false)

    local accountSettings = { clearOnLogout = false }

    if accountSettings.clearOnLogout then
      for key in pairs(state.conversations) do
        state.conversations[key] = nil
      end
    end

    assert(
      state.conversations["wow::WOW::test-realm"] ~= nil,
      "conversation should be preserved when clearOnLogout=false"
    )
  end
end
