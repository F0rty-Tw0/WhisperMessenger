local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")

-- The Whispers panel's toggle rows, in display order, plus their defaults.
-- Specs carry the same `key` / `labelKey` fields as the Behavior specs.
local ToggleSpecs = {}

ToggleSpecs.DEFAULTS = {
  hideFromDefaultChat = true,
  closeGameWhisperTab = false,
  autoOpenIncoming = false,
  autoOpenOutgoing = false,
  requestsInbox = false,
  shareTypingStatus = true,
  shareReadReceipts = true,
  showInviteLink = true,
  showChannelContext = true,
  showWidgetMessagePreview = true,
  widgetPreviewReply = false,
}

local function text(key)
  return Localization.Text(key)
end

function ToggleSpecs.Build(config, onChange)
  local specs = {
    {
      key = "hideFromDefaultChat",
      labelKey = "Hide whispers from default chat",
      anchorOffsetY = -24,
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
      key = "closeGameWhisperTab",
      labelKey = "Close the game's whisper tab too",
      initial = config.closeGameWhisperTab == true,
      onChange = function(value)
        onChange("closeGameWhisperTab", value)
      end,
      tooltipLines = {
        text("Close the game's whisper tab too"),
        text(
          "When you remove a chat here, the game's own whisper tab for that player closes as well. Only matters when the game opens whispers in their own tabs."
        ),
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
        text("Opens the messenger when you send a whisper or whisper from the friends list. Disabled during combat."),
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
        text("Lets contacts who also use Whisper Messenger see when you are typing a whisper to them."),
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
        text("Lets contacts who also use Whisper Messenger see when you have read their whispers."),
      },
    },
    {
      key = "showInviteLink",
      labelKey = "Show invite link",
      initial = config.showInviteLink ~= false,
      onChange = function(value)
        onChange("showInviteLink", value)
      end,
      tooltipLines = {
        text("Show invite link"),
        text("Shows an (Invite to WM) link in the chat header. Clicking it whispers that player a short message about this addon."),
      },
    },
    {
      key = "showChannelContext",
      labelKey = "Show their last channel message",
      initial = config.showChannelContext ~= false,
      onChange = function(value)
        onChange("showChannelContext", value)
      end,
      tooltipLines = {
        text("Show their last channel message"),
        text("When someone whispers you, their latest line from a channel such as Trade shows above the whisper. Turn this off to hide it."),
      },
    },
    {
      key = "showWidgetMessagePreview",
      labelKey = "Show widget message preview",
      initial = config.showWidgetMessagePreview ~= false,
      onChange = function(value)
        onChange("showWidgetMessagePreview", value)
      end,
      tooltipLines = {
        text("Show widget message preview"),
        text("Shows sender name and the latest incoming whisper preview on the draggable widget."),
      },
    },
    {
      key = "widgetPreviewReply",
      labelKey = "Reply from widget preview",
      initial = config.widgetPreviewReply == true,
      onChange = function(value)
        onChange("widgetPreviewReply", value)
      end,
      tooltipLines = {
        text("Reply from widget preview"),
        text("Adds a small reply box under the widget message preview. Press Enter to send."),
      },
    },
  }
  for _, spec in ipairs(specs) do
    spec.label = text(spec.labelKey)
  end
  return specs
end

ns.MessengerWindowWhispersToggleSpecs = ToggleSpecs
return ToggleSpecs
