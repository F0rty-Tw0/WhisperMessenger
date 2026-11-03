local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local HeaderView = ns.ConversationPaneHeaderView or require("WhisperMessenger.UI.ConversationPane.HeaderView")
local HeaderElements = ns.ConversationPaneHeaderElements or require("WhisperMessenger.UI.ConversationPane.HeaderElements")
local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local applyColor = UIHelpers.applyColor

-- Repaints every conversation-pane piece with the current theme colors.
local ThemeRefresh = {}

function ThemeRefresh.Apply(view)
  if view.headerFrame and view.headerFrame.bg then
    UIHelpers.applyColorTexture(view.headerFrame.bg, Theme.COLORS.bg_header)
  end
  if view.headerDivider then
    HeaderElements.applyDividerTheme(view.headerDivider)
  end
  HeaderView.Refresh(view, view._selectedContact, view._conversation, view._status)
  if view.headerStatus then
    applyColor(view.headerStatus, Theme.COLORS.text_secondary)
  end
  if view.headerStatusDetail then
    applyColor(view.headerStatusDetail, Theme.COLORS.text_secondary)
  end
  if view.headerEmpty and view.headerEmpty.applyTheme then
    view.headerEmpty.applyTheme()
  end
  if view.activeStatusBanner then
    applyColor(view.activeStatusBanner, Theme.COLORS.text_system)
  end
  view.requestBanner.refreshTheme()
  view.replyBanner.refreshTheme()
  view.infoStrip.refreshTheme()
  if view.edgeFade then
    view.edgeFade.refreshTheme()
  end
  if view.transcript and view.transcript.refreshSkin then
    view.transcript.refreshSkin()
  end
end

ns.ConversationPaneThemeRefresh = ThemeRefresh
return ThemeRefresh
