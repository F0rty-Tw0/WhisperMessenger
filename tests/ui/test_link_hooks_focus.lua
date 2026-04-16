return function()
  -- Stub the globals LinkHooks snapshots so we can detect install / restore.
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

  local originalGetActiveWindow = function()
    return nil
  end
  local originalInsertLink = function(_link)
    return false
  end
  _G.ChatEdit_GetActiveWindow = originalGetActiveWindow
  _G.ChatEdit_InsertLink = originalInsertLink
  _G.ChatFrameUtil = nil

  -- Force a fresh require so the module captures our stubs as originals.
  package.loaded["WhisperMessenger.UI.Composer.LinkHooks"] = nil
  local LinkHooks = require("WhisperMessenger.UI.Composer.LinkHooks")

  local input = {
    focused = false,
    shown = true,
    lastInsert = nil,
    scripts = {},
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
    HookScript = function(self, event, fn)
      self.scripts[event] = self.scripts[event] or {}
      table.insert(self.scripts[event], fn)
    end,
  }
  LinkHooks.RegisterInput(input)

  local function fire(event)
    for _, fn in ipairs(input.scripts[event] or {}) do
      fn(input)
    end
  end

  local function reset()
    input.focused = false
    input.lastInsert = nil
    if LinkHooks._isOverrideInstalled() then
      LinkHooks._uninstallOverrides()
    end
  end

  -- ---------------------------------------------------------------
  -- test_overrides_not_installed_at_module_load
  -- (critical — Blizzard's OPENCHAT / UpdateHeader must see Blizzard's own
  --  function while composer is unfocused, otherwise our taint attribution
  --  crashes arithmetic in ChatFrameEditBox.UpdateHeader.)
  -- ---------------------------------------------------------------
  do
    reset()
    assert(
      _G.ChatEdit_GetActiveWindow == originalGetActiveWindow,
      "ChatEdit_GetActiveWindow must NOT be overridden at module load"
    )
    assert(_G.ChatEdit_InsertLink == originalInsertLink, "ChatEdit_InsertLink must NOT be overridden at module load")
    assert(not LinkHooks._isOverrideInstalled(), "override state should start uninstalled")
  end

  -- ---------------------------------------------------------------
  -- test_focus_gained_installs_overrides
  -- ---------------------------------------------------------------
  do
    reset()
    input.focused = true
    fire("OnEditFocusGained")
    assert(LinkHooks._isOverrideInstalled(), "focus-gained should install overrides")
    assert(
      _G.ChatEdit_GetActiveWindow ~= originalGetActiveWindow,
      "ChatEdit_GetActiveWindow should route through our wrapper while focused"
    )
    assert(
      _G.ChatEdit_InsertLink ~= originalInsertLink,
      "ChatEdit_InsertLink should route through our wrapper while focused"
    )
  end

  -- ---------------------------------------------------------------
  -- test_focus_lost_restores_originals
  -- ---------------------------------------------------------------
  do
    reset()
    input.focused = true
    fire("OnEditFocusGained")
    input.focused = false
    fire("OnEditFocusLost")
    assert(not LinkHooks._isOverrideInstalled(), "focus-lost should uninstall overrides")
    assert(
      _G.ChatEdit_GetActiveWindow == originalGetActiveWindow,
      "ChatEdit_GetActiveWindow must be restored to Blizzard's original on focus-lost"
    )
    assert(
      _G.ChatEdit_InsertLink == originalInsertLink,
      "ChatEdit_InsertLink must be restored to Blizzard's original on focus-lost"
    )
  end

  -- ---------------------------------------------------------------
  -- test_wrapped_get_active_window_returns_input_when_focused
  -- ---------------------------------------------------------------
  do
    reset()
    input.focused = true
    fire("OnEditFocusGained")
    local active = _G.ChatEdit_GetActiveWindow()
    assert(active == input, "GetActiveWindow should return our input when focused")
  end

  -- ---------------------------------------------------------------
  -- test_wrapped_insert_link_routes_into_composer_when_focused
  -- ---------------------------------------------------------------
  do
    reset()
    input.focused = true
    fire("OnEditFocusGained")
    local handled = _G.ChatEdit_InsertLink("|Hitem:12345|h[Test Item]|h")
    assert(handled == true, "InsertLink should be handled when our input is focused")
    assert(
      input.lastInsert == "|Hitem:12345|h[Test Item]|h",
      "Input should receive link when focused, got: " .. tostring(input.lastInsert)
    )
  end

  -- ---------------------------------------------------------------
  -- test_set_item_ref_hook_does_nothing_when_unfocused
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
  if LinkHooks._isOverrideInstalled() then
    LinkHooks._uninstallOverrides()
  end
  _G.hooksecurefunc = savedHook
  _G.SetItemRef = savedSetItemRef
  _G.ChatEdit_GetActiveWindow = savedChatEditGetActiveWindow
  _G.ChatEdit_InsertLink = savedChatEditInsertLink
  _G.ChatFrameUtil = savedChatFrameUtil
  package.loaded["WhisperMessenger.UI.Composer.LinkHooks"] = nil
end
