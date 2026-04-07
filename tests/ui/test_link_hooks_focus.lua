return function()
  -- Stub the globals LinkHooks wraps so installEarlyOverrides() at load
  -- time wraps known no-op functions. We then drive the *wrapped* versions
  -- and assert how they react to focus state.
  local savedHook = _G.hooksecurefunc
  local savedSetItemRef = _G.SetItemRef
  local savedChatEditGetActiveWindow = _G.ChatEdit_GetActiveWindow
  local savedChatEditInsertLink = _G.ChatEdit_InsertLink
  local savedChatFrameUtil = _G.ChatFrameUtil

  local setItemRefHooks = {}
  _G.hooksecurefunc = function(name, fn)
    if name == "SetItemRef" then
      table.insert(setItemRefHooks, fn)
    end
  end
  _G.ChatEdit_GetActiveWindow = function()
    return nil
  end
  _G.ChatEdit_InsertLink = function(_link)
    return false
  end
  _G.ChatFrameUtil = nil

  -- Force a fresh require so installEarlyOverrides runs against our stubs.
  package.loaded["WhisperMessenger.UI.Composer.LinkHooks"] = nil
  local LinkHooks = require("WhisperMessenger.UI.Composer.LinkHooks")

  local wrappedGetActiveWindow = _G.ChatEdit_GetActiveWindow
  local wrappedInsertLink = _G.ChatEdit_InsertLink

  local input = {
    focused = false,
    shown = true,
    lastInsert = nil,
    IsVisible = function(self)
      return self.shown
    end,
    IsShown = function(self)
      return self.shown
    end,
    HasFocus = function(self)
      return self.focused
    end,
    Insert = function(self, link)
      self.lastInsert = link
    end,
  }
  LinkHooks.RegisterInput(input)

  local function reset()
    input.focused = false
    input.lastInsert = nil
  end

  -- ---------------------------------------------------------------
  -- test_get_active_window_returns_nil_when_unfocused
  -- ---------------------------------------------------------------
  do
    reset()
    local active = wrappedGetActiveWindow()
    assert(active == nil, "GetActiveWindow should return nil when our input is not focused")
  end

  -- ---------------------------------------------------------------
  -- test_get_active_window_returns_input_when_focused
  -- ---------------------------------------------------------------
  do
    reset()
    input.focused = true
    local active = wrappedGetActiveWindow()
    assert(active == input, "GetActiveWindow should return our input when focused")
  end

  -- ---------------------------------------------------------------
  -- test_insert_link_does_nothing_when_unfocused
  -- ---------------------------------------------------------------
  do
    reset()
    local handled = wrappedInsertLink("|Hitem:12345|h[Test Item]|h")
    assert(handled ~= true, "InsertLink should not be handled when our input is unfocused")
    assert(input.lastInsert == nil, "Input should not have received a link insert when unfocused")
  end

  -- ---------------------------------------------------------------
  -- test_insert_link_inserts_when_focused
  -- ---------------------------------------------------------------
  do
    reset()
    input.focused = true
    local handled = wrappedInsertLink("|Hitem:12345|h[Test Item]|h")
    assert(handled == true, "InsertLink should be handled when our input is focused")
    assert(
      input.lastInsert == "|Hitem:12345|h[Test Item]|h",
      "Input should receive link when focused, got: " .. tostring(input.lastInsert)
    )
  end

  -- ---------------------------------------------------------------
  -- test_set_item_ref_hook_does_nothing_when_unfocused
  -- (covers chat-bubble link clicks and quest links — quests used to be
  -- inserted even without focus, which surprised users)
  -- ---------------------------------------------------------------
  do
    reset()
    assert(#setItemRefHooks > 0, "SetItemRef hook should have been installed")
    for _, fn in ipairs(setItemRefHooks) do
      fn("quest:12345", "[Some Quest]")
    end
    assert(input.lastInsert == nil, "SetItemRef hook should not insert quest link when unfocused")
  end

  -- ---------------------------------------------------------------
  -- test_set_item_ref_hook_inserts_when_focused
  -- ---------------------------------------------------------------
  do
    reset()
    input.focused = true
    for _, fn in ipairs(setItemRefHooks) do
      fn("|Hitem:12345|h[Test Item]|h", "|Hitem:12345|h[Test Item]|h")
    end
    assert(input.lastInsert ~= nil, "SetItemRef hook should insert when focused")
  end

  -- Cleanup global state
  _G.hooksecurefunc = savedHook
  _G.SetItemRef = savedSetItemRef
  _G.ChatEdit_GetActiveWindow = savedChatEditGetActiveWindow
  _G.ChatEdit_InsertLink = savedChatEditInsertLink
  _G.ChatFrameUtil = savedChatFrameUtil
  package.loaded["WhisperMessenger.UI.Composer.LinkHooks"] = nil
end
