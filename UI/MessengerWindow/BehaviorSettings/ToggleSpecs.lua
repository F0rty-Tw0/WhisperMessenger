local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")

-- The Behavior panel's toggle rows, in display order, plus their defaults.
-- Each spec carries its setting `key` and the English `labelKey` it is
-- labelled with, so the panel binds and relabels rows by key.
local ToggleSpecs = {}

ToggleSpecs.DEFAULTS = {
  dimWhenMoving = true,
  autoFocusComposer = false,
  hideFromDefaultChat = true,
  autoOpenIncoming = false,
  autoOpenOutgoing = false,
  doubleEscapeToClose = false,
  showGroupChats = true,
  requestsInbox = false,
  hideOnCombat = false,
  shareTypingStatus = true,
  shareReadReceipts = true,
  collapseDuplicates = true,
  hideChannelsFromDefaultChat = true,
}

local function text(key)
  return Localization.Text(key)
end

function ToggleSpecs.Build(config, onChange)
  local profanityEnabled = _G.GetCVar and _G.GetCVar("profanityFilter") == "1" or false

  local specs = {
    {
      key = "dimWhenMoving",
      labelKey = "Dim when moving",
      initial = config.dimWhenMoving ~= false,
      onChange = function(value)
        onChange("dimWhenMoving", value)
      end,
      tooltipLines = {
        text("Dim when moving"),
        text("Reduces window opacity while your character is moving."),
      },
      anchorOffsetY = -24,
    },
    {
      key = "autoFocusComposer",
      labelKey = "Auto-focus chat input",
      initial = config.autoFocusComposer == true,
      onChange = function(value)
        onChange("autoFocusComposer", value)
      end,
      tooltipLines = {
        text("Auto-focus chat input"),
        text("Places the cursor in the text box when you open the messenger."),
      },
    },
    {
      key = "hideFromDefaultChat",
      labelKey = "Hide whispers from default chat",
      initial = config.hideFromDefaultChat == true,
      onChange = function(value)
        onChange("hideFromDefaultChat", value)
      end,
      tooltipLines = {
        text("Hide whispers from default chat"),
        text("Prevents whisper messages from appearing in the default WoW chat frame."),
        " ",
        text(
          "|cffff8080Note:|r In Mythic+ content, Blizzard's /r reply and R-keybind may fail while this is enabled (WoW 12.0 secret-value taint on chatEditLastTell). Use |cffffff00/wr|r (or bind /wr to R via macro) to reply safely."
        ),
      },
    },
    {
      key = "profanityFilter",
      labelKey = "Enable profanity filter",
      initial = profanityEnabled,
      onChange = function(value)
        if _G.SetCVar then
          _G.SetCVar("profanityFilter", value and "1" or "0")
        end
      end,
      tooltipLines = {
        text("Enable profanity filter"),
        text("Uses Blizzard's built-in filter to censor profanity in messages."),
      },
    },
    {
      key = "autoOpenIncoming",
      labelKey = "Auto-open on incoming whisper",
      initial = config.autoOpenIncoming == true,
      onChange = function(value)
        onChange("autoOpenIncoming", value)
      end,
      tooltipLines = {
        text("Auto-open on incoming whisper"),
        text("Opens the messenger when you receive a whisper. Disabled during combat."),
      },
    },
    {
      key = "autoOpenOutgoing",
      labelKey = "Auto-open on outgoing whisper",
      initial = config.autoOpenOutgoing == true,
      onChange = function(value)
        onChange("autoOpenOutgoing", value)
      end,
      tooltipLines = {
        text("Auto-open on outgoing whisper"),
        text("Opens the messenger when you send a whisper, press Reply, or whisper from the friends list. Disabled during combat."),
      },
    },
    {
      key = "hideOnCombat",
      labelKey = "Hide on entering combat",
      initial = config.hideOnCombat == true,
      onChange = function(value)
        onChange("hideOnCombat", value)
      end,
      tooltipLines = {
        text("Hide on entering combat"),
        text("Hides the messenger when combat starts. You can reopen it manually during combat. It does not reopen automatically after combat."),
      },
    },
    {
      key = "doubleEscapeToClose",
      labelKey = "Double ESC to close",
      initial = config.doubleEscapeToClose == true,
      onChange = function(value)
        onChange("doubleEscapeToClose", value)
      end,
      tooltipLines = {
        text("Double ESC to close"),
        text("First Esc clears the chat input; second Esc closes the window."),
      },
    },
    {
      key = "showGroupChats",
      labelKey = "Show group chats",
      initial = config.showGroupChats ~= false,
      onChange = function(value)
        onChange("showGroupChats", value)
      end,
      tooltipLines = {
        text("Show group chats"),
        text("Shows a Groups tab in the contacts list with party, instance, and Battle.net group conversations."),
        text("When off, only whispers appear."),
      },
    },
    {
      key = "requestsInbox",
      labelKey = "Put whispers from strangers in Requests",
      initial = config.requestsInbox == true,
      onChange = function(value)
        onChange("requestsInbox", value)
      end,
      tooltipLines = {
        text("Put whispers from strangers in Requests"),
        text(
          "Whispers from players who are not your friends, guildmates or group members wait quietly in a Requests tab: no sound, no pop-up, no badge."
        ),
      },
    },
    {
      key = "shareTypingStatus",
      labelKey = "Share typing status",
      initial = config.shareTypingStatus ~= false,
      onChange = function(value)
        onChange("shareTypingStatus", value)
      end,
      tooltipLines = {
        text("Share typing status"),
        text("Lets contacts who also use WhisperMessenger see when you are typing a whisper to them."),
      },
    },
    {
      key = "shareReadReceipts",
      labelKey = "Send read receipts",
      initial = config.shareReadReceipts ~= false,
      onChange = function(value)
        onChange("shareReadReceipts", value)
      end,
      tooltipLines = {
        text("Send read receipts"),
        text("Lets contacts who also use WhisperMessenger see when you have read their whispers."),
      },
    },
  }
  for _, spec in ipairs(specs) do
    spec.label = text(spec.labelKey)
  end
  return specs
end

ns.MessengerWindowBehaviorToggleSpecs = ToggleSpecs
return ToggleSpecs
