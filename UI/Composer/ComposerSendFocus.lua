local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local BindingKeys = ns.BindingKeys or require("WhisperMessenger.Util.BindingKeys")
local ComposerEnterButton = ns.ComposerEnterButton or require("WhisperMessenger.UI.Composer.ComposerEnterButton")
local PointerFocus = ns.MessengerWindowWindowScriptsFramePointerFocus
  or require("WhisperMessenger.UI.MessengerWindow.WindowScripts.Frame.PointerFocus")

-- "Deselect chat input after sending": a send takes the cursor out of the
-- composer, and while the composer is on screen the game's open-chat key puts
-- it back. The key is an override binding on a button (ComposerEnterButton),
-- so it never touches Blizzard's chat box. Bindings are only set outside
-- combat, so the button is made at the first one, never in combat.
--
-- Bindings can't change in combat. PLAYER_REGEN_DISABLED fires just before the
-- lockdown, so with the setting on and the window open it takes the key even
-- while the composer is hidden (settings, a panel, the contact list) or has no
-- conversation. A closed window leaves Enter the game's chat for the fight,
-- also when the window opens mid-fight; a window that hides as combat starts
-- (hide in combat) gives the key back through its own OnHide, since its hidden
-- composer gets none. Calling the game's chat opener from here would taint, so
-- in combat the key focuses the composer only while it is shown and the mouse
-- is over the window, and otherwise does nothing. "Over the window" includes
-- its parts outside its edges (the tabs below a compact window, the Retail
-- portrait) and the toggle icon while docked in its corner, not while it
-- floats elsewhere. When combat ends, PLAYER_REGEN_ENABLED keeps or
-- releases the key as usual.
--
-- Settings hide the composer's pane, so the pane's OnShow picks up a changed
-- toggle when they close.
local ComposerSendFocus = {}

local OPEN_CHAT_ACTION = "OPENCHAT"
local TOGGLE_ICON_NAME = "WhisperMessengerToggleIcon"
local EVENTS = { "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "UPDATE_BINDINGS", "PLAYER_ENTERING_WORLD" }

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

-- region is `ancestor` or sits somewhere below it.
local function isWithin(region, ancestor)
  local current = region
  while current ~= nil do
    if current == ancestor then
      return true
    end
    if type(current.GetParent) ~= "function" then
      return false
    end
    current = current:GetParent()
  end
  return false
end

-- The toggle icon (UIParent's child) while it is pinned to the window's icon
-- spot; nil while it floats on its own or glides between the two.
local function dockedToggleIcon(window)
  local icon = _G[TOGGLE_ICON_NAME]
  if icon == nil or type(icon.GetPoint) ~= "function" then
    return nil
  end
  local _, relativeTo = icon:GetPoint()
  if relativeTo ~= nil and isWithin(relativeTo, window) then
    return icon
  end
  return nil
end

-- The Retail template's portrait sticks out past the window's corner and
-- takes no mouse, so the frame under the cursor there is whatever is behind it.
local function overProtrudingPart(window)
  local portrait = window.PortraitContainer
  return portrait ~= nil and type(portrait.IsMouseOver) == "function" and portrait:IsMouseOver() == true
end

-- The window's own rect, its portrait, or a frame under the cursor that
-- belongs to the window (drawn outside it) or to the docked toggle icon.
local function defaultMouseIsOver(pane)
  local window = windowOf(pane)
  if type(window.IsMouseOver) == "function" and window:IsMouseOver() == true then
    return true
  end
  if overProtrudingPart(window) then
    return true
  end
  local toggleIcon = dockedToggleIcon(window)
  return PointerFocus.FindFocusAncestor(function(frame)
    return frame == window or (toggleIcon ~= nil and frame == toggleIcon)
  end) ~= nil
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

  local function isEligible()
    return options.isOn() and options.isEnabled() and pane:IsVisible()
  end

  local function onPress()
    if not isEligible() or (inCombat() and not mouseIsOver(pane)) then
      return
    end
    if input.SetFocus then
      input:SetFocus()
    end
  end

  -- Only ever runs outside combat, so the secure button is made here.
  local function bind()
    if boundKeys ~= nil or type(createFrame) ~= "function" or type(setOverrideBindingClick) ~= "function" then
      return
    end
    local keys = openChatKeys()
    if #keys == 0 then
      return
    end
    button = button or ComposerEnterButton.Create(createFrame, onPress)
    if button == nil then
      return
    end
    for _, key in ipairs(keys) do
      setOverrideBindingClick(button, true, key, ComposerEnterButton.NAME)
    end
    boundKeys = table.concat(keys, " ")
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

  -- A window hidden while its composer is already hidden fires no OnHide on
  -- the composer, so the window's own one releases the key.
  local windowHideHooked = false
  local function hookWindowHide(window)
    if windowHideHooked or type(window.HookScript) ~= "function" then
      return
    end
    windowHideHooked = true
    window:HookScript("OnHide", sync)
  end

  -- Last chance before the lockdown: an open window keeps the key for the
  -- fight even while its composer is hidden or disabled.
  local function beforeCombat()
    if inCombat() or not options.isOn() then
      return
    end
    local window = windowOf(pane)
    if window:IsVisible() then
      hookWindowHide(window)
      bind()
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

  -- A plain frame takes the events, so it can be made even in combat.
  local events = type(createFrame) == "function" and createFrame("Frame", nil, pane) or nil
  if events then
    if type(events.RegisterEvent) == "function" then
      for _, event in ipairs(EVENTS) do
        events:RegisterEvent(event)
      end
    end
    events:SetScript("OnEvent", function(_self, event)
      if event == "PLAYER_REGEN_DISABLED" then
        beforeCombat()
      elseif event == "PLAYER_REGEN_ENABLED" then
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
