-- Regression: after roundtripping Group → Whisper → Group, the Groups tab
-- must show the previously-selected group (or empty if none was selected),
-- not the whisper from the intermediate Whispers visit. Mirrors the user
-- report that "going back to Groups still shows the whisper in messages".

local ContactsList = require("WhisperMessenger.UI.ContactsList")
local MessengerWindow = require("WhisperMessenger.UI.MessengerWindow")
local ChannelType = require("WhisperMessenger.Model.Identity.ChannelType")
local FakeUI = require("tests.helpers.fake_ui")

return function()
  local items = ContactsList.BuildItems({
    ["me::WOW::jaina"] = { displayName = "Jaina", channel = "WOW", lastActivityAt = 20 },
    ["me::WOW::thrall"] = { displayName = "Thrall", channel = "WOW", lastActivityAt = 15 },
    ["PARTY::1"] = { displayName = "Party Chat", channel = ChannelType.PARTY, lastActivityAt = 10 },
    ["INSTANCE::1"] = { displayName = "Instance Chat", channel = ChannelType.INSTANCE_CHAT, lastActivityAt = 5 },
  })

  local factory = FakeUI.NewFactory()
  local savedUIParent = _G.UIParent
  _G.UIParent = factory.CreateFrame("Frame", "UIParent", nil)

  local activeKey = "me::WOW::jaina"
  local paneCleared = false
  local paneSelectedKey = "me::WOW::jaina"

  local function findItem(key)
    for _, item in ipairs(items) do
      if item.conversationKey == key then
        return item
      end
    end
    return nil
  end

  local function buildState(key)
    if key == nil then
      return { contacts = items, selectedContact = nil, conversation = nil }
    end
    return { contacts = items, selectedContact = findItem(key), conversation = { messages = {} } }
  end

  local window = MessengerWindow.Create(factory, {
    title = "WhisperMessenger",
    contacts = items,
    selectedContact = findItem(activeKey),
    conversation = { messages = {} },
    initialTabMode = "whispers",
    onSelectConversation = function(conversationKey)
      activeKey = conversationKey
      paneCleared = false
      paneSelectedKey = conversationKey
      return buildState(conversationKey)
    end,
    onSend = function() end,
    onClose = function() end,
  })

  -- Instrument the pane refresh so we can observe what the user sees.
  -- ConversationPane.Refresh(view, selectedContact, ...) — when selectedContact
  -- is nil the user sees an empty pane; when non-nil they see its content.
  local ConversationPane = require("WhisperMessenger.UI.ConversationPane")
  local originalRefresh = ConversationPane.Refresh
  ConversationPane.Refresh = function(view, selectedContact, conversation, status, notice)
    if selectedContact == nil then
      paneCleared = true
      paneSelectedKey = nil
    else
      paneCleared = false
      paneSelectedKey = selectedContact.conversationKey
    end
    return originalRefresh(view, selectedContact, conversation, status, notice)
  end

  -- Scenario: never select a group. Roundtrip tabs and confirm Groups tab is
  -- empty on the second visit (not holding onto the whisper).
  window.setTabMode("groups")
  assert(paneCleared == true, "first switch to Groups with no prior group selection should clear the pane")

  window.setTabMode("whispers")
  assert(
    paneSelectedKey == "me::WOW::jaina",
    "switching back to Whispers should restore jaina, got: " .. tostring(paneSelectedKey)
  )

  window.setTabMode("groups")
  assert(
    paneCleared == true,
    "second switch to Groups must clear the pane (no group was ever selected), got key: " .. tostring(paneSelectedKey)
  )

  -- Now select a group, roundtrip, and confirm the group is restored.
  assert(window.selectConversation("PARTY::1") == true, "party row should be selectable")
  assert(paneSelectedKey == "PARTY::1", "party should be shown after select")

  window.setTabMode("whispers")
  assert(paneSelectedKey == "me::WOW::jaina", "whispers restore: jaina")

  window.setTabMode("groups")
  assert(
    paneSelectedKey == "PARTY::1",
    "groups restore: party should be re-shown, not jaina, got: " .. tostring(paneSelectedKey)
  )

  ConversationPane.Refresh = originalRefresh

  -- Second scenario: start on Groups tab with nothing selected. Go to
  -- Whispers, select a whisper, come back to Groups. Should still be empty.
  local paneSelectedKey2 = nil
  local function buildState2(key)
    if key == nil then
      return { contacts = items, selectedContact = nil, conversation = nil }
    end
    return { contacts = items, selectedContact = findItem(key), conversation = { messages = {} } }
  end

  local window2 = MessengerWindow.Create(factory, {
    title = "WhisperMessenger",
    contacts = items,
    selectedContact = nil,
    conversation = nil,
    initialTabMode = "groups",
    onSelectConversation = function(conversationKey)
      paneSelectedKey2 = conversationKey
      return buildState2(conversationKey)
    end,
    onSend = function() end,
    onClose = function() end,
  })

  local originalRefresh2 = ConversationPane.Refresh
  ConversationPane.Refresh = function(view, selectedContact, conversation, status, notice)
    if selectedContact == nil then
      paneSelectedKey2 = nil
    else
      paneSelectedKey2 = selectedContact.conversationKey
    end
    return originalRefresh2(view, selectedContact, conversation, status, notice)
  end

  assert(window2.getTabMode() == "groups", "second window should start on groups")

  window2.setTabMode("whispers")
  assert(window2.selectConversation("me::WOW::thrall") == true, "should be able to select thrall")
  assert(paneSelectedKey2 == "me::WOW::thrall", "thrall should be shown")

  window2.setTabMode("groups")
  assert(
    paneSelectedKey2 == nil,
    "groups tab should be empty (no group ever selected), got key: " .. tostring(paneSelectedKey2)
  )

  ConversationPane.Refresh = originalRefresh

  -- Regression: messenger opens on Groups tab but the active conversation
  -- from the persisted state is a whisper. The initial state has
  -- tabMode=groups + selectedContact=whisper. Roundtripping tabs must not
  -- cause the whisper to be restored on the Groups tab.
  local paneSelectedKey3 = "me::WOW::jaina"
  local function buildState3(key)
    if key == nil then
      return { contacts = items, selectedContact = nil, conversation = nil }
    end
    return { contacts = items, selectedContact = findItem(key), conversation = { messages = {} } }
  end

  local window3 = MessengerWindow.Create(factory, {
    title = "WhisperMessenger",
    contacts = items,
    selectedContact = findItem("me::WOW::jaina"), -- whisper selected …
    conversation = { messages = {} },
    initialTabMode = "groups", -- … but tab is groups (mismatch from persisted state)
    onSelectConversation = function(conversationKey)
      paneSelectedKey3 = conversationKey
      return buildState3(conversationKey)
    end,
    onSend = function() end,
    onClose = function() end,
  })

  local originalRefresh3 = ConversationPane.Refresh
  ConversationPane.Refresh = function(view, selectedContact, conversation, status, notice)
    if selectedContact == nil then
      paneSelectedKey3 = nil
    else
      paneSelectedKey3 = selectedContact.conversationKey
    end
    return originalRefresh3(view, selectedContact, conversation, status, notice)
  end

  -- User toggles Whispers then Groups.
  window3.setTabMode("whispers")
  window3.setTabMode("groups")
  assert(
    paneSelectedKey3 ~= "me::WOW::jaina",
    "Groups tab must not restore the whisper after a roundtrip — whisper should never leak into the groups-tab memory"
  )
  assert(
    paneSelectedKey3 == nil,
    "Groups tab should be empty after roundtrip with no group ever selected, got: " .. tostring(paneSelectedKey3)
  )

  ConversationPane.Refresh = originalRefresh
  _G.UIParent = savedUIParent
end
