local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- Opt-B override: when `hideFromDefaultChat` is on, take over the R key so
-- it fires /wr through a SecureActionButton instead of Blizzard's
-- ChatFrame_ReplyTell (which crashes on tainted chatEditLastTell once a
-- whisper has been suppressed by our filter chain).
--
-- SetOverrideBindingClick + SecureActionButtonTemplate is taint-safe: the
-- binding-table mutation happens inside Blizzard's function body and the
-- click dispatch goes through a secure template, not our addon stack.
local ReplyKeyBinder = {}

local BUTTON_NAME = "WhisperMessengerReplyButton"

function ReplyKeyBinder.New(deps)
  deps = deps or {}
  local createFrame = deps.createFrame or _G.CreateFrame
  local setOverrideBindingClick = deps.setOverrideBindingClick or _G.SetOverrideBindingClick
  local clearOverrideBindings = deps.clearOverrideBindings or _G.ClearOverrideBindings
  local uiParent = deps.uiParent or _G.UIParent
  local getSettings = deps.getSettings or function()
    return {}
  end

  local button
  local bound = false

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

  function self.bind()
    if bound then
      return
    end
    local btn = ensureButton()
    if not btn or type(setOverrideBindingClick) ~= "function" then
      return
    end
    setOverrideBindingClick(btn, true, "R", BUTTON_NAME)
    bound = true
  end

  function self.unbind()
    if not bound then
      return
    end
    if button and type(clearOverrideBindings) == "function" then
      clearOverrideBindings(button)
    end
    bound = false
  end

  function self.sync()
    local settings = getSettings() or {}
    -- Bind R whenever hide-whispers is on — regardless of M+ / suspend.
    -- Letting Blizzard's default /r run in M+ crashes on chatEditLastTell
    -- that was seeded with WhisperMessenger-attributed taint by the filter
    -- chain pre-M+. Our messenger opens even when the composer is disabled
    -- (mythic pause) — strictly better than a Lua error every R-press.
    if settings.hideFromDefaultChat == true then
      self.bind()
    else
      self.unbind()
    end
  end

  function self.isBound()
    return bound
  end

  return self
end

ns.BootstrapReplyKeyBinder = ReplyKeyBinder
return ReplyKeyBinder
