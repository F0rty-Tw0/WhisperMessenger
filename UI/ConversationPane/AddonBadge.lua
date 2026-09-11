local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local GroupHeaderViewModel = ns.ConversationPaneGroupHeaderViewModel or require("WhisperMessenger.UI.ConversationPane.GroupHeaderViewModel")
local applyColor = UIHelpers.applyColor

local AddonBadge = {}

-- Floor for the addon badge's click target when the font reports no height.
local BADGE_MIN_HEIGHT = 12

function AddonBadge.addonBadgeText()
  return "(" .. Localization.Text("Uses WM") .. ")"
end

function AddonBadge.inviteHintText()
  return "(" .. Localization.Text("Invite to WM") .. ")"
end

function AddonBadge.inviteSentText()
  return "(" .. Localization.Text("Invite sent") .. ")"
end

-- Addon badge modes: "addon" = peer runs WhisperMessenger, "invite" = clickable
-- invite hint, "sent" = the invite already went out for this conversation.
local function badgeTextFor(mode)
  if mode == "invite" then
    return AddonBadge.inviteHintText()
  end
  if mode == "sent" then
    return AddonBadge.inviteSentText()
  end
  return AddonBadge.addonBadgeText()
end

-- Keeps the badge's click target glued to its label, which changes width every
-- time the mode or the language changes.
function AddonBadge.sizeAddonBadge(button, label)
  if button == nil or label == nil or type(button.SetSize) ~= "function" then
    return
  end
  local width = type(label.GetStringWidth) == "function" and label:GetStringWidth() or 0
  local height = type(label.GetStringHeight) == "function" and label:GetStringHeight() or 0
  button:SetSize(math.max(width, 1), math.max(height, BADGE_MIN_HEIGHT))
end

-- Returns the clickable button and the label it carries. The label stays the
-- badge handle everywhere else; the button only exists so the invite hint can
-- be clicked.
function AddonBadge.createAddonBadge(factory, headerFrame, headerFactionIcon)
  local button = factory.CreateFrame("Button", nil, headerFrame)
  button:SetPoint("LEFT", headerFactionIcon, "RIGHT", 6, 0)
  button:EnableMouse(false)

  local label = button:CreateFontString(nil, "OVERLAY", Theme.FONTS.header_status)
  label:SetPoint("LEFT", button, "LEFT", 0, 0)
  applyColor(label, Theme.TAG_GOLD)
  label:SetText(AddonBadge.addonBadgeText())
  AddonBadge.sizeAddonBadge(button, label)
  button:Hide()
  label:Hide()

  if type(button.SetScript) == "function" then
    -- `_wmInviteContact` is set by AddonBadge.Refresh and is nil in every mode
    -- but the clickable invite hint, so it gates the click and the tooltip.
    button:SetScript("OnClick", function(self)
      local contact = self._wmInviteContact
      local invite = self._wmOnInvite
      if contact ~= nil and type(invite) == "function" then
        invite(contact)
      end
    end)
    button:SetScript("OnEnter", function(self)
      if self._wmInviteContact == nil then
        return
      end
      if _G.GameTooltip and _G.GameTooltip.SetOwner then
        _G.GameTooltip:SetOwner(self, "ANCHOR_TOP")
        _G.GameTooltip:SetText(Localization.Text("Click to whisper this player an invite to WhisperMessenger."))
        _G.GameTooltip:Show()
      end
    end)
    button:SetScript("OnLeave", function()
      if _G.GameTooltip and _G.GameTooltip.Hide then
        _G.GameTooltip:Hide()
      end
    end)
  end

  return button, label
end

-- A nil contact leaves the badge inert: no click, no tooltip, no mouse.
local function setInviteTarget(view, button, selectedContact)
  if button == nil then
    return
  end
  button._wmInviteContact = selectedContact
  button._wmOnInvite = selectedContact ~= nil and view.onInviteContact or nil
  if type(button.EnableMouse) == "function" then
    button:EnableMouse(selectedContact ~= nil)
  end
end

function AddonBadge.SetLanguage(view)
  if view and view.headerAddonBadge and type(view.headerAddonBadge.SetText) == "function" then
    view.headerAddonBadge:SetText(badgeTextFor(view._headerAddonBadgeMode))
    AddonBadge.sizeAddonBadge(view.headerAddonBadgeButton, view.headerAddonBadge)
  end
end

function AddonBadge.Refresh(view, selectedContact, conversation)
  if view.headerAddonBadge == nil then
    return
  end

  -- Direct whisper contacts only (not groups): show "(Uses WM)" when the
  -- peer also runs the addon, "(Invite sent)" once we've whispered them an
  -- invite, else a dimmed, clickable "(Invite to WM)" hint.
  local hasContact = selectedContact ~= nil
  local vm = GroupHeaderViewModel.Build(selectedContact, conversation)
  local badge = view.headerAddonBadge
  local badgeButton = view.headerAddonBadgeButton
  local isDirectContact = hasContact and not (vm and vm.isGroup) and (selectedContact.channel == "WOW" or selectedContact.channel == "BN")
  if isDirectContact then
    local anchor = view.headerFactionIcon
    if type(anchor) ~= "table" or type(anchor.IsShown) ~= "function" or not anchor:IsShown() then
      anchor = view.headerName
    end
    local anchored = badgeButton or badge
    if anchor and type(anchored.ClearAllPoints) == "function" then
      anchored:ClearAllPoints()
      anchored:SetPoint("LEFT", anchor, "RIGHT", 6, 0)
    end

    local mode
    if selectedContact.peerHasAddon then
      mode = "addon"
    elseif conversation and conversation.inviteSent == true then
      mode = "sent"
    else
      mode = "invite"
    end
    view._headerAddonBadgeMode = mode
    badge:SetText(badgeTextFor(mode))
    UIHelpers.applyColor(badge, mode == "addon" and Theme.TAG_GOLD or Theme.COLORS.text_secondary)
    AddonBadge.sizeAddonBadge(badgeButton, badge)
    setInviteTarget(view, badgeButton, mode == "invite" and selectedContact or nil)

    badge:Show()
    if badgeButton then
      badgeButton:Show()
    end
  else
    setInviteTarget(view, badgeButton, nil)
    badge:Hide()
    if badgeButton then
      badgeButton:Hide()
    end
  end
end

ns.ConversationPaneAddonBadge = AddonBadge

return AddonBadge
