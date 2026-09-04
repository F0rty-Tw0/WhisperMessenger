return function()
  -- Stub the globals LinkHooks snapshots so we can detect install / restore.
  local savedHook = _G.hooksecurefunc
  local savedSetItemRef = _G.SetItemRef
  local savedChatEditGetActiveWindow = _G.ChatEdit_GetActiveWindow
  local savedChatEditInsertLink = _G.ChatEdit_InsertLink
  local savedChatFrameUtil = _G.ChatFrameUtil
  local savedGetTime = _G.GetTime

  local setItemRefHooks = {}
  local function hooksecurefuncStub(name, fn)
    if name == "SetItemRef" then
      table.insert(setItemRefHooks, fn)
    end
  end
  _G.hooksecurefunc = hooksecurefuncStub

  -- Simulate Blizzard's real ChatEdit_InsertLink: it asks for the active
  -- window and, if one exists, inserts the raw text into it.
  local originalGetActiveWindow = function()
    return nil
  end
  local originalInsertLink = function(text)
    local active = _G.ChatEdit_GetActiveWindow()
    if active ~= nil then
      active:Insert(text)
      return true
    end
    return false
  end
  _G.ChatEdit_GetActiveWindow = originalGetActiveWindow
  _G.ChatEdit_InsertLink = originalInsertLink
  _G.ChatFrameUtil = nil

  local frameTime = 100
  _G.GetTime = function()
    return frameTime
  end

  -- Force a fresh require so the module captures our stubs as originals.
  package.loaded["WhisperMessenger.UI.Composer.LinkHooks"] = nil
  local LinkHooks = require("WhisperMessenger.UI.Composer.LinkHooks")

  local inserts = {}
  local input = {
    focused = false,
    shown = true,
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
    Insert = function(_self, link)
      table.insert(inserts, link)
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
    inserts = {}
    if LinkHooks._isOverrideInstalled() then
      LinkHooks._uninstallOverrides()
    end
  end

  -- test_shift_click_fanout_inserts_once
  do
    reset()
    input.focused = true
    fire("OnEditFocusGained")
    frameTime = 200

    _G.ChatEdit_InsertLink("Gæmmer-Kazzak")
    _G.ChatEdit_InsertLink("|Hplayer:Gæmmer-Kazzak:1:WHISPER|h[Gæmmer]|h")
    for _, fn in ipairs(setItemRefHooks) do
      fn("player:Gæmmer-Kazzak:1:WHISPER", "|cff3fc7eb|Hplayer:Gæmmer-Kazzak:1:WHISPER|hGæmmer|h|r")
    end

    assert(#inserts == 1, "expected exactly one insert from the shift-click fanout, got " .. #inserts)
    assert(inserts[1] == "Gæmmer-Kazzak", "expected the plain name to land, got: " .. tostring(inserts[1]))
  end

  -- test_next_frame_inserts_again
  do
    frameTime = 201
    _G.ChatEdit_InsertLink("|Hitem:1|h[Item]|h")
    assert(#inserts == 2, "expected a second insert on the next frame, got " .. #inserts)
    assert(inserts[2] == "|Hitem:1|h[Item]|h", "expected the item link to land, got: " .. tostring(inserts[2]))
  end

  -- test_dedupe_still_reports_handled
  do
    reset()
    input.focused = true
    fire("OnEditFocusGained")
    frameTime = 300

    local first = _G.ChatEdit_InsertLink("Gæmmer-Kazzak")
    local second = _G.ChatEdit_InsertLink("|Hplayer:Gæmmer-Kazzak:1:WHISPER|h[Gæmmer]|h")
    assert(first == true, "first insert of the frame should report handled")
    assert(second == true, "deduped second insert of the same frame should still report handled")
  end

  -- test_original_used_when_composer_unfocused_but_override_installed
  do
    reset()
    LinkHooks._installOverrides()
    input.focused = false
    frameTime = 400

    local handled = _G.ChatEdit_InsertLink("x")
    assert(handled == false, "unfocused composer should not claim the insert")
    assert(#inserts == 0, "unfocused composer should not receive an insert, got " .. #inserts)
  end

  -- test_no_gettime_keeps_legacy_behavior
  do
    reset()
    _G.GetTime = nil
    input.focused = true
    fire("OnEditFocusGained")

    _G.ChatEdit_InsertLink("Gæmmer-Kazzak")
    _G.ChatEdit_InsertLink("|Hplayer:Gæmmer-Kazzak:1:WHISPER|h[Gæmmer]|h")
    assert(#inserts == 2, "without GetTime both same-frame inserts should land, got " .. #inserts)
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
  _G.GetTime = savedGetTime
  package.loaded["WhisperMessenger.UI.Composer.LinkHooks"] = nil
end
