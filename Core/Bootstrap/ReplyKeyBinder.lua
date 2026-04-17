local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- Opt-B override: when `hideFromDefaultChat` is on, take over the user's
-- REPLY key (default "R", but respects their keybinding) so it fires /wr
-- through a SecureActionButton instead of Blizzard's ChatFrame_ReplyTell
-- (which crashes on tainted chatEditLastTell once a whisper has been
-- suppressed by our filter chain).
--
-- SetOverrideBindingClick + SecureActionButtonTemplate is taint-safe: the
-- binding-table mutation happens inside Blizzard's function body and the
-- click dispatch goes through a secure template, not our addon stack.
local ReplyKeyBinder = {}

local BUTTON_NAME = "WhisperMessengerReplyButton"

local function defaultGetBindingKey(action)
  if type(_G.GetBindingKey) == "function" then
    return _G.GetBindingKey(action)
  end
  return nil
end

-- Collect up to 8 slots (Blizzard UI exposes 2; API historically returns up
-- to 4). Vararg iteration is simpler than pcall-with-unpack gymnastics.
local function collectReplyKeys(getBindingKey)
  local keys = {}
  if type(getBindingKey) ~= "function" then
    return keys
  end
  local raw = { getBindingKey("REPLY") }
  for i = 1, #raw do
    local key = raw[i]
    if type(key) == "string" and key ~= "" then
      table.insert(keys, key)
    end
  end
  return keys
end

local function keysEqual(a, b)
  if #a ~= #b then
    return false
  end
  for i = 1, #a do
    if a[i] ~= b[i] then
      return false
    end
  end
  return true
end

function ReplyKeyBinder.New(deps)
  deps = deps or {}
  local createFrame = deps.createFrame or _G.CreateFrame
  local setOverrideBindingClick = deps.setOverrideBindingClick or _G.SetOverrideBindingClick
  local clearOverrideBindings = deps.clearOverrideBindings or _G.ClearOverrideBindings
  local uiParent = deps.uiParent or _G.UIParent
  local getBindingKey = deps.getBindingKey or defaultGetBindingKey
  local getSettings = deps.getSettings or function()
    return {}
  end

  local button
  local boundKeys = {}

  local function ensureButton()
    if button then
      return button
    end
    if type(createFrame) ~= "function" then
      return nil
    end
    button = createFrame("Button", BUTTON_NAME, uiParent, "SecureActionButtonTemplate")
    if button and button.SetAttribute then
      button:SetAttribute("type", "macro")
      button:SetAttribute("macrotext", "/wr")
    end
    -- Secure action buttons need RegisterForClicks to actually receive
    -- click events from SetOverrideBindingClick. SetOverrideBindingClick
    -- dispatches the virtual click on key-DOWN, so register AnyDown only.
    -- Registering both AnyUp+AnyDown fires the binding twice per keypress;
    -- the second fire races the newly-focused composer and leaks the
    -- trigger character into it.
    if button and button.RegisterForClicks then
      button:RegisterForClicks("AnyDown")
    end
    return button
  end

  local self = {}

  local function clearCurrentBindings()
    if #boundKeys == 0 then
      return
    end
    if button and type(clearOverrideBindings) == "function" then
      clearOverrideBindings(button)
    end
    boundKeys = {}
  end

  function self.bind()
    local btn = ensureButton()
    if not btn or type(setOverrideBindingClick) ~= "function" then
      return
    end

    local desiredKeys = collectReplyKeys(getBindingKey)

    -- Already bound to this exact key-set: no-op. Keeps sync() idempotent
    -- and avoids tearing down a working override every call.
    if keysEqual(desiredKeys, boundKeys) then
      return
    end

    -- Tear down any prior override before re-applying. Without this, a
    -- rebind (R → T) would leave the stale R override alive alongside T.
    clearCurrentBindings()

    -- REPLY is unbound (user chose no reply hotkey). Respect that — do
    -- not grab an arbitrary key.
    if #desiredKeys == 0 then
      return
    end

    for _, key in ipairs(desiredKeys) do
      setOverrideBindingClick(btn, true, key, BUTTON_NAME)
    end
    boundKeys = desiredKeys
  end

  function self.unbind()
    clearCurrentBindings()
  end

  function self.sync()
    local settings = getSettings() or {}
    -- Bind whenever hide-whispers is on — regardless of M+ / suspend.
    -- Letting Blizzard's default /r run in M+ crashes on chatEditLastTell
    -- that was seeded with WhisperMessenger-attributed taint by the filter
    -- chain pre-M+. Our messenger opens even when the composer is disabled
    -- (mythic pause) — strictly better than a Lua error every reply-press.
    if settings.hideFromDefaultChat == true then
      self.bind()
    else
      self.unbind()
    end
  end

  function self.isBound()
    return #boundKeys > 0
  end

  return self
end

ns.BootstrapReplyKeyBinder = ReplyKeyBinder
return ReplyKeyBinder
