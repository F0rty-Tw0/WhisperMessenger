local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local applyColorTexture = UIHelpers.applyColorTexture
local applyVertexColor = UIHelpers.applyVertexColor

local trace = ns.trace
if not trace then
  if type(require) == "function" then
    local ok, loaded = pcall(require, "WhisperMessenger.Core.Trace")
    if ok and loaded then
      trace = loaded
    end
  end
  if not trace then
    trace = function() end
  end
end

local ActionButtons = {}

--- Show action buttons on a row (pin + remove), respecting unread state.
---@param row table row frame with item, pinButton, removeButton fields
function ActionButtons.showActions(row)
  local hasUnread = row.item and (row.item.unreadCount or 0) > 0
  if hasUnread then
    return
  end
  if row.pinButton then
    row.pinButton:Show()
  end
  if row.removeButton then
    row.removeButton:Show()
  end
end

--- Hide action buttons on a row (keeps pin visible for pinned items).
---@param row table row frame with item, pinButton, removeButton fields
function ActionButtons.hideActions(row)
  if row.pinButton and not (row.item and row.item.pinned) then
    row.pinButton:Hide()
  end
  if row.removeButton then
    row.removeButton:Hide()
  end
end

--- Create the remove button and attach it to row.
--- Returns the button frame.
---@param factory table frame factory
---@param row table parent row frame
---@param parentWidth number width of the parent for layout
---@param options table callbacks: onRemove(item)
function ActionButtons.createRemoveButton(factory, row, parentWidth, options)
  local ACTION_SIZE = Theme.LAYOUT.CONTACT_ACTION_SIZE
  local ACTION_SPACING = Theme.LAYOUT.CONTACT_ACTION_SPACING
  local rowBaseBg = row.item and row.item.pinned and Theme.COLORS.bg_contact_pinned or Theme.COLORS.bg_secondary

  local btn = factory.CreateFrame("Button", nil, row)
  btn:SetSize(ACTION_SIZE, ACTION_SIZE)
  btn:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -Theme.LAYOUT.CONTACT_PADDING, 4 + ACTION_SIZE + ACTION_SPACING)
  if btn.EnableMouse then
    btn:EnableMouse(true)
  end

  btn.icon = btn:CreateTexture(nil, "ARTWORK")
  btn.icon:SetSize(ACTION_SIZE - 2, ACTION_SIZE - 2)
  btn.icon:SetPoint("CENTER", btn, "CENTER", 0, 0)
  btn.icon:SetTexture(Theme.TEXTURES.remove_icon)
  if btn.icon.SetDesaturated then
    btn.icon:SetDesaturated(true)
  end
  applyVertexColor(btn.icon, Theme.COLORS.action_icon)

  if btn.SetScript then
    btn:SetScript("OnEnter", function(self)
      applyVertexColor(self.icon, Theme.COLORS.action_remove_hover)
      if not row.selected then
        applyColorTexture(row.bg, Theme.COLORS.bg_contact_hover)
      end
      ActionButtons.showActions(row)
      if _G.GameTooltip and _G.GameTooltip.SetOwner then
        _G.GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        _G.GameTooltip:SetText("Remove")
        _G.GameTooltip:Show()
      end
    end)

    btn:SetScript("OnLeave", function(self)
      applyVertexColor(self.icon, Theme.COLORS.action_icon)
      if not (row.IsMouseOver and row:IsMouseOver()) then
        if row.selected then
          applyColorTexture(row.bg, Theme.COLORS.bg_contact_selected)
        else
          applyColorTexture(row.bg, rowBaseBg)
        end
        ActionButtons.hideActions(row)
      end
      if _G.GameTooltip and _G.GameTooltip.Hide then
        _G.GameTooltip:Hide()
      end
    end)

    btn:SetScript("OnClick", function()
      if row.item and options.onRemove then
        trace(
          "remove clicked",
          "key=" .. tostring(row.item.conversationKey),
          "name=" .. tostring(row.item.displayName),
          "channel=" .. tostring(row.item.channel),
          "pinned=" .. tostring(row.item.pinned)
        )
        options.onRemove(row.item)
      end
    end)
  end

  return btn
end

--- Create the pin button and attach it to row.
--- Requires row.removeButton to already exist for anchoring.
--- Returns the button frame.
---@param factory table frame factory
---@param row table parent row frame (must have row.removeButton)
---@param item table contact item data
---@param parentWidth number width of the parent for layout
---@param options table callbacks: onPin(item)
function ActionButtons.createPinButton(factory, row, item, parentWidth, options)
  local ACTION_SIZE = Theme.LAYOUT.CONTACT_ACTION_SIZE
  local ACTION_SPACING = Theme.LAYOUT.CONTACT_ACTION_SPACING
  local rowBaseBg = item.pinned and Theme.COLORS.bg_contact_pinned or Theme.COLORS.bg_secondary

  local btn = factory.CreateFrame("Button", nil, row)
  btn:SetSize(ACTION_SIZE, ACTION_SIZE)
  if row.removeButton then
    btn:SetPoint("TOP", row.removeButton, "BOTTOM", 0, -ACTION_SPACING)
  end
  if btn.EnableMouse then
    btn:EnableMouse(true)
  end

  btn.icon = btn:CreateTexture(nil, "ARTWORK")
  btn.icon:SetSize(ACTION_SIZE - 2, ACTION_SIZE - 2)
  btn.icon:SetPoint("CENTER", btn, "CENTER", 0, 0)
  if btn.icon.SetDesaturated then
    btn.icon:SetDesaturated(true)
  end

  if btn.SetScript then
    btn:SetScript("OnEnter", function(self)
      applyVertexColor(self.icon, Theme.COLORS.action_icon_hover)
      if not row.selected then
        applyColorTexture(row.bg, Theme.COLORS.bg_contact_hover)
      end
      ActionButtons.showActions(row)
      if _G.GameTooltip and _G.GameTooltip.SetOwner then
        _G.GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local pinLabel = item.pinned and "Unpin" or "Pin"
        _G.GameTooltip:SetText(pinLabel)
        _G.GameTooltip:Show()
      end
    end)

    btn:SetScript("OnLeave", function(self)
      local baseColor = item.pinned and Theme.COLORS.action_icon_pinned or Theme.COLORS.action_icon
      applyVertexColor(self.icon, baseColor)
      if not (row.IsMouseOver and row:IsMouseOver()) then
        if row.selected then
          applyColorTexture(row.bg, Theme.COLORS.bg_contact_selected)
        else
          applyColorTexture(row.bg, rowBaseBg)
        end
        ActionButtons.hideActions(row)
      end
      if _G.GameTooltip and _G.GameTooltip.Hide then
        _G.GameTooltip:Hide()
      end
    end)

    btn:SetScript("OnClick", function()
      if row.item and options.onPin then
        trace(
          "pin clicked",
          "key=" .. tostring(row.item.conversationKey),
          "name=" .. tostring(row.item.displayName),
          "channel=" .. tostring(row.item.channel),
          "pinned=" .. tostring(row.item.pinned)
        )
        options.onPin(row.item)
      end
    end)
  end

  return btn
end

ns.ContactsListActionButtons = ActionButtons
return ActionButtons
