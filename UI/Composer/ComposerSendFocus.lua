local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local BindingKeys = ns.BindingKeys or require("WhisperMessenger.Util.BindingKeys")

-- "Deselect chat input after sending": a send takes the cursor out of the
-- composer, and while the composer is on screen the game's open-chat key puts
-- it back. The key is an override binding on a button, like the ESC override
-- (EscapeKey.lua), so it never touches Blizzard's chat box.
--
-- Bindings can't change in combat, so the override is left as it was when the
-- fight began: bound if the window was open, absent if it was closed (Enter
-- stays the game's chat then, also when the window opens mid-fight). Calling
-- the game's chat opener from here would taint, so in combat the key focuses
-- the composer only while the mouse is over the window and otherwise does
-- nothing. A window closed mid-fight leaves a dead Enter until combat ends,
-- when PLAYER_REGEN_ENABLED releases it.
--
-- Settings hide the composer's pane, so the pane's OnShow picks up a changed
-- toggle when they close.
local ComposerSendFocus = {}

local BUTTON_NAME = "WhisperMessengerComposerEnterButton"
local OPEN_CHAT_ACTION = "OPENCHAT"
local EVENTS = { "PLAYER_REGEN_ENABLED", "UPDATE_BINDINGS", "PLAYER_ENTERING_WORLD" }

local function defaultInCombat()
  return type(_G.InCombatLockdown) == "function" and _G.InCombatLockdown() == true
end

-- The window is the pane's topmost ancestor below UIParent.
local function windowOf(pane)
  local frame = pane
  while type(frame.GetParent) == "function" do
    local parent = frame:GetParent()
    if parent == nil or parent == _G.UIParent then
      break
    end
    frame = parent
  end
  return frame
end

local function defaultMouseIsOver(pane)
  local window = windowOf(pane)
  return type(window.IsMouseOver) == "function" and window:IsMouseOver() == true
end

-- options.isOn(): the setting. options.isEnabled(): the composer can send.
-- deps: optional stand-ins for the game's functions.
function ComposerSendFocus.Create(pane, input, options, deps)
  deps = deps or {}
  local createFrame = deps.createFrame or _G.CreateFrame
  local getBindingKey = deps.getBindingKey or _G.GetBindingKey
  local setOverrideBindingClick = deps.setOverrideBindingClick or _G["SetOverrideBindingClick"]
  local clearOverrideBindings = deps.clearOverrideBindings or _G["ClearOverrideBindings"]
  local inCombat = deps.inCombat or defaultInCombat
  local mouseIsOver = deps.mouseIsOver or defaultMouseIsOver

  -- The open-chat keys held now, joined; nil while the key belongs to the game.
  local boundKeys = nil
  local button = nil

  local function openChatKeys()
    return BindingKeys.ForAction(getBindingKey, OPEN_CHAT_ACTION)
  end

  local function unbind()
    if boundKeys ~= nil and type(clearOverrideBindings) == "function" then
      clearOverrideBindings(button)
    end
    boundKeys = nil
  end

  local function bind()
    if boundKeys ~= nil or button == nil or type(setOverrideBindingClick) ~= "function" then
      return
    end
    local keys = openChatKeys()
    for _, key in ipairs(keys) do
      setOverrideBindingClick(button, true, key, BUTTON_NAME)
    end
    if #keys > 0 then
      boundKeys = table.concat(keys, " ")
    end
  end

  local function isEligible()
    return options.isOn() and options.isEnabled() and pane:IsVisible()
  end

  local function sync()
    if inCombat() then
      return
    end
    if isEligible() then
      bind()
    else
      unbind()
    end
  end

  -- Changing an override may fire UPDATE_BINDINGS too, so only a real key
  -- change rebinds. Unlike ESC, a key assigned while nothing was bound counts.
  local function keysChanged()
    return (boundKeys or "") ~= table.concat(openChatKeys(), " ")
  end

  local function followRebind()
    if inCombat() then
      return
    end
    if keysChanged() then
      unbind()
      sync()
    end
  end

  -- The override survived the fight: release it, or move it to keys changed
  -- during the fight.
  local function afterCombat()
    if keysChanged() then
      unbind()
    end
    sync()
  end

  -- Other addons often reprocess bindings here and may have cleared ours.
  local function reapply()
    if inCombat() then
      return
    end
    unbind()
    sync()
  end

  if type(createFrame) == "function" then
    button = createFrame("Button", BUTTON_NAME, pane)
  end
  if button then
    if type(button.RegisterForClicks) == "function" then
      button:RegisterForClicks("AnyDown")
    end
    button:SetScript("OnClick", function()
      if not isEligible() or (inCombat() and not mouseIsOver(pane)) then
        return
      end
      if input.SetFocus then
        input:SetFocus()
      end
    end)
    if type(button.RegisterEvent) == "function" then
      for _, event in ipairs(EVENTS) do
        button:RegisterEvent(event)
      end
    end
    button:SetScript("OnEvent", function(_self, event)
      if event == "PLAYER_REGEN_ENABLED" then
        afterCombat()
      elseif event == "UPDATE_BINDINGS" then
        followRebind()
      else
        reapply()
      end
    end)
  end
  if type(pane.HookScript) == "function" then
    pane:HookScript("OnShow", sync)
    pane:HookScript("OnHide", sync)
  end

  local focus = { sync = sync }

  function focus.afterSend()
    if options.isOn() and input.ClearFocus then
      input:ClearFocus()
    end
  end

  return focus
end

ns.ComposerSendFocus = ComposerSendFocus

return ComposerSendFocus
