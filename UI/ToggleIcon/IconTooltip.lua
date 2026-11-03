local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local KeybindHints = ns.KeybindHints or require("WhisperMessenger.UI.Shared.KeybindHints")

-- The toggle icon's hover tooltip: title, unread summary, M+ pause and lock
-- notes, then the keybind and click hints.
local IconTooltip = {}

-- context.badge: the unread badge frame (its visibility gates the summary).
-- context.isLocked: function returning true while the icon is locked.
-- context.options: the icon's Create options (getHideFromDefaultChat).
function IconTooltip.Create(frame, context)
  local badge = context.badge
  local isLocked = context.isLocked
  local options = context.options

  local function show(unreadSummary, isCompetitiveActive)
    if _G.GameTooltip and _G.GameTooltip.SetOwner then
      _G.GameTooltip:SetOwner(frame, "ANCHOR_BOTTOM")
      local unreadText = badge:IsShown() and " — " .. unreadSummary or ""
      local competitiveText = ""
      if isCompetitiveActive then
        competitiveText = "\n" .. Localization.Text("Paused in M+")
      end
      local lockedText = ""
      if isLocked() then
        lockedText = "\n" .. Localization.Text("Locked")
      end
      _G.GameTooltip:SetText("Whisper Messenger" .. unreadText .. competitiveText .. lockedText)
      KeybindHints.AddToTooltip(_G.GameTooltip, type(options.getHideFromDefaultChat) == "function" and options.getHideFromDefaultChat() == true)
      KeybindHints.AddClickHint(_G.GameTooltip)
      _G.GameTooltip:Show()
    end
  end

  local function hide()
    if _G.GameTooltip and _G.GameTooltip.Hide then
      _G.GameTooltip:Hide()
    end
  end

  return {
    show = show,
    hide = hide,
  }
end

ns.ToggleIconIconTooltip = IconTooltip
return IconTooltip
