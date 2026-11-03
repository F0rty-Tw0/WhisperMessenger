local TabVisibilitySetting = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.TabVisibilitySetting")

local function fakeRuntime(tabMode)
  local calls = { refreshes = 0, toggles = 0 }
  local runtime = {
    window = {
      getTabMode = function()
        return tabMode
      end,
      setTabMode = function(mode)
        calls.setTabMode = mode
      end,
      refreshTabToggleVisibility = function()
        calls.toggles = calls.toggles + 1
      end,
    },
    refreshWindow = function()
      calls.refreshes = calls.refreshes + 1
    end,
  }
  return runtime, calls
end

return function()
  -- test_hiding_group_chats_leaves_the_groups_tab

  do
    local runtime, calls = fakeRuntime("groups")
    TabVisibilitySetting.Apply(runtime, {}, "showGroupChats", false)
    assert(calls.setTabMode == "whispers", "the open groups tab falls back to whispers")
    assert(calls.toggles == 1 and calls.refreshes == 1, "toggles and window refresh")
  end

  -- test_showing_group_chats_keeps_the_open_tab

  do
    local runtime, calls = fakeRuntime("groups")
    TabVisibilitySetting.Apply(runtime, {}, "showGroupChats", true)
    assert(calls.setTabMode == nil, "turning the tab on does not switch tabs")
  end

  -- test_turning_off_requests_leaves_the_requests_tab

  do
    local runtime, calls = fakeRuntime("requests")
    TabVisibilitySetting.Apply(runtime, {}, "requestsInbox", nil)
    assert(calls.setTabMode == "whispers", "an unset requests inbox falls back to whispers")
    assert(calls.refreshes == 1, "the window refreshes")
  end

  -- test_no_enabled_channels_leaves_the_channels_tab

  do
    local runtime, calls = fakeRuntime("channels")
    TabVisibilitySetting.Apply(runtime, { enabledChannels = {} }, "enabledChannels", {})
    assert(calls.setTabMode == "whispers", "the channels tab closes when no channel is enabled")
    assert(calls.toggles == 1, "the tab toggles refresh")
    assert(calls.refreshes == 0, "the caller refreshes the window for channels")
  end

  -- test_other_keys_are_ignored

  do
    local runtime, calls = fakeRuntime("groups")
    TabVisibilitySetting.Apply(runtime, {}, "fontSize", 12)
    assert(calls.toggles == 0 and calls.refreshes == 0 and calls.setTabMode == nil, "nothing is touched")
  end
end
