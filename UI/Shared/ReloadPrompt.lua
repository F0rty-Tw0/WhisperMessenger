local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")

-- Game popup asking to reload the interface now. Reload UI runs onAccept,
-- then reloads; Cancel runs onCancel (the change then applies on the next
-- reload).
local ReloadPrompt = {}

ReloadPrompt.DIALOG = "WHISPER_MESSENGER_RELOAD_UI"

function ReloadPrompt.Show(text, onCancel, onAccept)
  if type(_G.StaticPopup_Show) ~= "function" then
    if onCancel then
      onCancel()
    end
    return
  end
  _G.StaticPopupDialogs = _G.StaticPopupDialogs or {}
  _G.StaticPopupDialogs[ReloadPrompt.DIALOG] = {
    text = text,
    -- The game's own localized labels.
    button1 = rawget(_G, "RELOADUI") or "Reload UI",
    button2 = rawget(_G, "CANCEL") or Localization.Text("Cancel"),
    OnAccept = function()
      if onAccept then
        onAccept()
      end
      if type(_G.ReloadUI) == "function" then
        _G.ReloadUI()
      end
    end,
    OnCancel = function()
      if onCancel then
        onCancel()
      end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
  }
  _G.StaticPopup_Show(ReloadPrompt.DIALOG)
end

function ReloadPrompt.Hide()
  if type(_G.StaticPopup_Hide) == "function" then
    _G.StaticPopup_Hide(ReloadPrompt.DIALOG)
  end
end

ns.ReloadPrompt = ReloadPrompt
return ReloadPrompt
