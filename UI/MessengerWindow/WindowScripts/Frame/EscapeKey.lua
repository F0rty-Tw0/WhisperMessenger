local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- While the messenger has focus, the game-menu key (ESC) clicks a hidden
-- button that closes it. Other windows' own ESC handlers (Professions) run
-- before the game's close-all sweep, so UISpecialFrames alone can't close
-- the messenger first. The override is a key binding, not a handler in the
-- game's ESC list: registering there from addon code taints ESC.
--
-- Bindings can't change in combat. PLAYER_REGEN_DISABLED fires just before
-- the lockdown starts, so ESC goes back to the game for the whole fight
-- (it stops casts there) and returns once combat ends.
--
-- The game's ESC list closes a dialog and cancels spell targeting before
-- any window, so ESC also goes back to the game while one is up. A cast in
-- progress is not checked: out of combat, ESC closes the messenger first.
local EscapeKey = {}

local BUTTON_NAME = "WhisperMessengerEscapeButton"
local GAME_MENU_ACTION = "TOGGLEGAMEMENU"
-- Every dialog opens and closes through these (GameDialog's OnShow/OnHide
-- call the first two), on Retail, Classic and WoW: Forever.
local DIALOG_FUNCTIONS = { "StaticPopup_OnShow", "StaticPopup_OnHide", "StaticPopupSpecial_Show", "StaticPopupSpecial_Hide" }

local function defaultInCombat()
  return type(_G.InCombatLockdown) == "function" and _G.InCombatLockdown() == true
end

-- StaticPopup_EscapePressed closes only the hideOnEscape dialogs.
local function escapeClosesDialog()
  local forEachShownDialog = _G["StaticPopup_ForEachShownDialog"]
  if type(forEachShownDialog) ~= "function" then
    return false
  end
  local found = false
  forEachShownDialog(function(dialog)
    if dialog.hideOnEscape and dialog:IsShown() then
      found = true
    end
  end)
  return found
end

local function spellTargeting()
  local spellIsTargeting = _G["SpellIsTargeting"]
  return type(spellIsTargeting) == "function" and spellIsTargeting() == true
end

local function gameHasEscapeFirst()
  return escapeClosesDialog() or spellTargeting()
end

-- Post-hooks only: the game's functions run untouched.
local function watchDialogs(onChange)
  if type(_G.hooksecurefunc) ~= "function" then
    return
  end
  for _, name in ipairs(DIALOG_FUNCTIONS) do
    if type(_G[name]) == "function" then
      pcall(_G.hooksecurefunc, name, onChange)
    end
  end
end

local function gameMenuKeys(getBindingKey)
  local keys = {}
  if type(getBindingKey) ~= "function" then
    return keys
  end
  local raw = { getBindingKey(GAME_MENU_ACTION) }
  for i = 1, #raw do
    if type(raw[i]) == "string" and raw[i] ~= "" then
      table.insert(keys, raw[i])
    end
  end
  return keys
end

function EscapeKey.New(frame, deps)
  deps = deps or {}
  local createFrame = deps.createFrame or _G.CreateFrame
  local getBindingKey = deps.getBindingKey or _G.GetBindingKey
  local setOverrideBindingClick = deps.setOverrideBindingClick or _G["SetOverrideBindingClick"]
  local clearOverrideBindings = deps.clearOverrideBindings or _G["ClearOverrideBindings"]
  local inCombat = deps.inCombat or defaultInCombat

  local focused = false
  -- The game-menu keys held now, joined; nil while ESC belongs to the game.
  local boundKeys = nil
  local button = nil
  local key = {}

  local function currentKeys()
    return table.concat(gameMenuKeys(getBindingKey), " ")
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
    local keys = gameMenuKeys(getBindingKey)
    for _, gameMenuKey in ipairs(keys) do
      setOverrideBindingClick(button, true, gameMenuKey, BUTTON_NAME)
    end
    if #keys > 0 then
      boundKeys = table.concat(keys, " ")
    end
  end

  -- IsVisible: a hidden UIParent (Alt+Z) leaves the window shown but off
  -- screen.
  local function onScreen()
    if type(frame.IsVisible) == "function" then
      return frame:IsVisible()
    end
    return frame:IsShown()
  end

  local function sync()
    if inCombat() then
      return
    end
    if focused and onScreen() and not gameHasEscapeFirst() then
      bind()
    else
      unbind()
    end
  end

  -- The player moved the game-menu key. Changing overrides may fire
  -- UPDATE_BINDINGS too, so only a real key change rebinds.
  local function followRebind()
    if inCombat() or boundKeys == nil or boundKeys == currentKeys() then
      return
    end
    unbind()
    sync()
  end

  if type(createFrame) == "function" then
    button = createFrame("Button", BUTTON_NAME, frame)
  end
  if button then
    if type(button.RegisterForClicks) == "function" then
      button:RegisterForClicks("AnyDown")
    end
    button:SetScript("OnClick", function()
      if frame:IsShown() then
        frame:Hide()
      end
    end)
    if type(button.RegisterEvent) == "function" then
      button:RegisterEvent("PLAYER_REGEN_DISABLED")
      button:RegisterEvent("PLAYER_REGEN_ENABLED")
      button:RegisterEvent("UPDATE_BINDINGS")
      -- Fires when spell targeting starts and ends.
      button:RegisterEvent("CURRENT_SPELL_CAST_CHANGED")
    end
    button:SetScript("OnEvent", function(_self, event)
      if event == "PLAYER_REGEN_DISABLED" then
        unbind()
      elseif event == "UPDATE_BINDINGS" then
        followRebind()
      else
        sync()
      end
    end)
  end
  watchDialogs(function()
    sync()
  end)

  function key.setFocused(isFocused)
    focused = isFocused == true
    sync()
  end

  return key
end

ns.MessengerWindowWindowScriptsFrameEscapeKey = EscapeKey

return EscapeKey
