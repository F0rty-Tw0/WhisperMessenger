-- Integration: verify per-tab selection memory using a real MessengerWindow.
-- Reproduces the user-visible flow: select whisper → switch to Groups (no
-- selection there) → select a group → switch back to whispers (whisper
-- should re-highlight) → switch forward to groups (party should
-- re-highlight).

local ContactsList = require("WhisperMessenger.UI.ContactsList")
local MessengerWindow = require("WhisperMessenger.UI.MessengerWindow")
local ChannelType = require("WhisperMessenger.Model.Identity.ChannelType")
local FakeUI = require("tests.helpers.fake_ui")

return function()
  local items = ContactsList.BuildItems({
    ["me::WOW::jaina"] = {
      displayName = "Jaina",
      channel = "WOW",
      lastActivityAt = 20,
    },
    ["me::WOW::thrall"] = {
      displayName = "Thrall",
      channel = "WOW",
      lastActivityAt = 15,
    },
    ["PARTY::1"] = {
      displayName = "Party Chat",
      channel = ChannelType.PARTY,
      lastActivityAt = 10,
    },
    ["INSTANCE::1"] = {
      displayName = "Instance Chat",
      channel = ChannelType.INSTANCE_CHAT,
      lastActivityAt = 5,
    },
  })

  local factory = FakeUI.NewFactory()
  local savedUIParent = _G.UIParent
  _G.UIParent = factory.CreateFrame("Frame", "UIParent", nil)

  -- Fake runtime-style selection: onSelectConversation is the hook
  -- WindowRuntime.lua wires up; we emulate it by returning a nextState
  -- so selectionController has proper state.
  local activeKey = "me::WOW::jaina" -- initial selected whisper
  local function findItem(key)
    for _, item in ipairs(items) do
      if item.conversationKey == key then
        return item
      end
    end
    return nil
  end
  local function buildState()
    return {
      contacts = items,
      selectedContact = findItem(activeKey),
      conversation = { messages = {} },
    }
  end

  local initialState = buildState()

  local window = MessengerWindow.Create(factory, {
    title = "WhisperMessenger",
    contacts = items,
    selectedContact = initialState.selectedContact,
    conversation = initialState.conversation,
    status = nil,
    initialTabMode = "whispers",
    onSelectConversation = function(conversationKey)
      activeKey = conversationKey
      return buildState()
    end,
    onSend = function() end,
    onClose = function() end,
  })

  assert(window ~= nil, "window should be created")
  assert(window.setTabMode ~= nil, "window should expose setTabMode")

  -- Sanity: initial whisper active
  assert(activeKey == "me::WOW::jaina", "initial activeKey should be Jaina, got: " .. tostring(activeKey))

  -- Step 1: switch to Groups. tabSelections.whispers should be captured via
  -- the swap callback safety net (onSelect was never fired for the initial
  -- auto-selected contact). Groups has no saved selection, so pane clears.
  window.setTabMode("groups")
  assert(window.getTabMode() == "groups", "after setTabMode('groups'), getTabMode should be 'groups', got: " .. tostring(window.getTabMode()))
  -- Pane is cleared on first visit to groups — activeKey intentionally cleared
  -- by refreshSelection({}). But note refreshSelection({}) doesn't run
  -- onSelectConversation, so activeKey (as seen by this test's onSelectConversation
  -- proxy) stays as the last key set.
  -- Instead, verify that switching back restores the whisper.

  -- Step 2: simulate selecting a party row via window.selectConversation.
  -- This uses handleContactSelected under the hood, which should trigger
  -- our onSelect wrapper to update tabSelections.groups. But
  -- window.selectConversation loops over contacts.rows (virtualized), so
  -- we call handleContactSelected-equivalent indirectly. Instead, simulate
  -- the user click by invoking onSelect on the row directly.
  local partyItem = findItem("PARTY::1")
  assert(partyItem ~= nil, "party item should exist in contacts")

  -- Find the row script binding: we can't click easily without the RowScripts
  -- wiring, so invoke the window's selectConversation which runs
  -- handleContactSelected after a row-index lookup in virtualized rows. In
  -- the fake UI all rows get bound since visibleCount is generous, so the
  -- party row should be present.
  local selected = window.selectConversation("PARTY::1")
  assert(selected == true, "party row should be findable and selectable in rows")
  assert(activeKey == "PARTY::1", "activeKey should now be party after select, got: " .. tostring(activeKey))

  -- Step 3: switch back to whispers. Swap callback should:
  --   - save tabSelections.groups = PARTY::1 (via selectionController)
  --   - restore tabSelections.whispers = me::WOW::jaina (captured at step 1)
  --   - call handleContactSelected(jaina) → onSelectConversation(jaina) → activeKey = jaina
  window.setTabMode("whispers")
  assert(window.getTabMode() == "whispers", "tab mode should be whispers")
  assert(activeKey == "me::WOW::jaina", "after switching back to whispers, jaina should be re-selected; activeKey=" .. tostring(activeKey))

  -- Step 4: switch forward to groups again. Should restore party.
  window.setTabMode("groups")
  assert(activeKey == "PARTY::1", "after switching back to groups, party should be re-selected; activeKey=" .. tostring(activeKey))

  _G.UIParent = savedUIParent
  print("PASS: test_tab_selection_memory_live")
end
