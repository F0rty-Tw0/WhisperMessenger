local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local KeybindHints = ns.KeybindHints or require("WhisperMessenger.UI.Shared.KeybindHints")

-- Opens the game's Key Bindings screen for the "Set keybind…" button. Every
-- current flavor has the Settings panel, which can scroll to our section;
-- older clients only have KeyBindingFrame. Nothing opens in combat.
local KeybindOpener = {}

KeybindOpener.ACTION = "WHISPERMESSENGER_TOGGLE"
-- The category attribute in Bindings.xml; the Settings panel names our
-- binding section after it.
KeybindOpener.CATEGORY = "Whisper Messenger"
KeybindOpener.REASON_COMBAT = "Key bindings can't be changed in combat."
KeybindOpener.REASON_UNSUPPORTED = "This game version can't open Key Bindings from here. Use the game menu instead."

local function inCombat()
  return type(_G.InCombatLockdown) == "function" and _G.InCombatLockdown() == true
end

local function settingsPanel()
  local settings = _G.Settings
  if type(settings) == "table" and type(settings.OpenToCategory) == "function" and settings.KEYBINDINGS_CATEGORY_ID ~= nil then
    return settings
  end
  return nil
end

local function hasLegacyFrame()
  return type(_G.KeyBindingFrame_LoadUI) == "function" and type(_G.ShowUIPanel) == "function"
end

-- Returns enabled, reasonKey (an English Localization key, nil when enabled).
function KeybindOpener.Availability()
  if settingsPanel() == nil and not hasLegacyFrame() then
    return false, KeybindOpener.REASON_UNSUPPORTED
  end
  if inCombat() then
    return false, KeybindOpener.REASON_COMBAT
  end
  return true, nil
end

-- closeWindow runs first so the messenger never covers the game screen.
-- Returns true when a Key Bindings screen was asked to open.
function KeybindOpener.Open(closeWindow)
  if not KeybindOpener.Availability() then
    return false
  end
  if type(closeWindow) == "function" then
    closeWindow()
  end
  local settings = settingsPanel()
  if settings then
    settings.OpenToCategory(settings.KEYBINDINGS_CATEGORY_ID, KeybindOpener.CATEGORY)
    return true
  end
  _G.KeyBindingFrame_LoadUI()
  if _G.KeyBindingFrame == nil then
    return false
  end
  _G.ShowUIPanel(_G.KeyBindingFrame)
  return true
end

-- "CTRL-O, ALT-W" in the game's key names, or nil when nothing is bound.
function KeybindOpener.CurrentKeysText()
  if type(_G.GetBindingKey) ~= "function" then
    return nil
  end
  local names = KeybindHints.KeyNames(_G.GetBindingKey(KeybindOpener.ACTION))
  if #names == 0 then
    return nil
  end
  return table.concat(names, ", ")
end

ns.MessengerWindowBehaviorKeybindOpener = KeybindOpener
return KeybindOpener
