-- Regression: per-tab selection memory. Switching between Whispers and
-- Groups tabs should restore the conversation that was selected in the
-- destination tab (or clear the pane if none). Empty initial state is
-- treated as "no selection yet".
--
-- This test simulates the swap-callback wiring used by MessengerWindow:
-- a small tabSelections table tracked on user select + on tab switch,
-- restored via a handleContactSelected stub.

local ChannelType = require("WhisperMessenger.Model.Identity.ChannelType")

local function makeItem(channel, key, displayName)
  return { channel = channel, conversationKey = key, displayName = displayName }
end

return function()
  -- test_swap_restores_whisper_after_visiting_groups
  do
    local contacts = {
      makeItem(ChannelType.WHISPER, "wow::WOW::Jaina", "Jaina"),
      makeItem(ChannelType.WHISPER, "wow::WOW::Thrall", "Thrall"),
      makeItem(ChannelType.PARTY, "PARTY::1", "Party"),
      makeItem(ChannelType.INSTANCE_CHAT, "INSTANCE::1", "Instance"),
    }

    local activeKey = "wow::WOW::Jaina"
    local tabSelections = { whispers = nil, groups = nil }
    local currentTabMode = "whispers"

    local function handleContactSelected(item)
      activeKey = item and item.conversationKey or nil
    end

    local function getSelectedConversationKey()
      return activeKey
    end

    local function onSelect(item)
      if item and item.conversationKey and (currentTabMode == "whispers" or currentTabMode == "groups") then
        tabSelections[currentTabMode] = item.conversationKey
      end
      handleContactSelected(item)
    end

    local function swap(oldMode, newMode)
      local liveKey = getSelectedConversationKey()
      if liveKey ~= nil then
        tabSelections[oldMode] = liveKey
      end
      local nextKey = tabSelections[newMode]
      local matched = false
      if nextKey then
        for _, item in ipairs(contacts) do
          if item.conversationKey == nextKey then
            handleContactSelected(item)
            matched = true
            break
          end
        end
      end
      if not matched then
        activeKey = nil
      end
    end

    -- Initial state: Jaina auto-selected in whispers tab. Switch to Groups.
    currentTabMode = "groups"
    swap("whispers", "groups")
    assert(tabSelections.whispers == "wow::WOW::Jaina", "whispers selection should be saved on first switch")
    assert(activeKey == nil, "groups has no saved selection yet — pane should clear")

    -- Select Party in Groups.
    onSelect(contacts[3])
    assert(activeKey == "PARTY::1", "party should become active after select")
    assert(tabSelections.groups == "PARTY::1", "groups selection should be tracked on select")

    -- Switch back to Whispers — should restore Jaina.
    currentTabMode = "whispers"
    swap("groups", "whispers")
    assert(tabSelections.groups == "PARTY::1", "groups selection preserved after swap-save")
    assert(activeKey == "wow::WOW::Jaina", "whisper should be restored on return to whispers tab")

    -- Switch back to Groups — should restore Party.
    currentTabMode = "groups"
    swap("whispers", "groups")
    assert(activeKey == "PARTY::1", "party should be restored on return to groups tab")

    -- Select Thrall in whispers, then cycle through groups.
    currentTabMode = "whispers"
    swap("groups", "whispers")
    assert(activeKey == "wow::WOW::Jaina", "precondition: jaina restored")
    onSelect(contacts[2])
    assert(tabSelections.whispers == "wow::WOW::Thrall", "whispers selection updated on new select")

    currentTabMode = "groups"
    swap("whispers", "groups")
    assert(activeKey == "PARTY::1", "party still restored after switching to groups")

    currentTabMode = "whispers"
    swap("groups", "whispers")
    assert(activeKey == "wow::WOW::Thrall", "thrall restored (latest whispers selection)")
  end

  print("PASS: test_tab_selection_memory")
end
