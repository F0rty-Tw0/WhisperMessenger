local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ContextMenu = {}
-- stylua: ignore start
local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local ManualCopy = ns.ChatBubbleContextMenuManualCopy or require("WhisperMessenger.UI.ChatBubble.ContextMenu.ManualCopy")
local MessageReactions = ns.MessageReactions or require("WhisperMessenger.Model.MessageReactions")
local ReactionPicker = ns.ChatBubbleReactionPicker or require("WhisperMessenger.UI.ChatBubble.ReactionPicker")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
-- stylua: ignore end

local MENU_FRAME_NAME = "WhisperMessengerBubbleContextMenu"
local function reactionsAllowed(message, canReact)
  if type(canReact) == "function" then
    return canReact(message)
  end
  return MessageReactions.IsEligible(message)
end

local function styleMenuText(text)
  return UIHelpers.colorEscape(Theme.COLORS.option_button_text) .. text .. "|r"
end

local function getMenuFrame()
  if type(_G.CreateFrame) ~= "function" or _G.UIParent == nil then
    return nil
  end

  local frame = _G[MENU_FRAME_NAME]
  if frame ~= nil then
    return frame
  end

  -- UIDropDownMenuTemplate was removed in Retail 10.0 — pcall so a throw falls through to CopyText.
  local ok, created = pcall(_G.CreateFrame, "Frame", MENU_FRAME_NAME, _G.UIParent, "UIDropDownMenuTemplate")
  if not ok then
    return nil
  end
  return created
end

function ContextMenu.CopyText(text)
  if type(ManualCopy) ~= "table" or type(ManualCopy.CopyText) ~= "function" then
    return false
  end

  return ManualCopy.CopyText(text)
end

-- Retail's menu API: Reply + Copy text. False when the API is missing.
local function openModernMenu(normalized, anchorFrame, onReply)
  local menuUtil = _G.MenuUtil
  if type(menuUtil) ~= "table" or type(menuUtil.CreateContextMenu) ~= "function" then
    return false
  end
  menuUtil.CreateContextMenu(anchorFrame, function(_owner, rootDescription)
    rootDescription:CreateButton(Localization.Text("Reply"), onReply)
    rootDescription:CreateButton(Localization.Text("Copy text"), function()
      ContextMenu.CopyText(normalized)
    end)
  end)
  return true
end

-- options.onReply(): optional; adds "Reply" to whichever menu opens.
function ContextMenu.Open(text, anchorFrame, options)
  local normalized = type(ManualCopy) == "table" and type(ManualCopy.NormalizeText) == "function" and ManualCopy.NormalizeText(text) or nil
  if normalized == nil then
    return false
  end

  options = options or {}
  local reactionsAllowedForMessage = reactionsAllowed(options.message, options.canReact)
  if not reactionsAllowedForMessage then
    ReactionPicker.Close()
  elseif type(options.onReact) == "function" then
    local factory = options.factory
    if factory == nil and type(_G.CreateFrame) == "function" then
      factory = { CreateFrame = _G.CreateFrame }
    end
    if
      ReactionPicker.Open(factory, anchorFrame, options.message, options.onReact, function()
        return ContextMenu.CopyText(normalized)
      end, options.canReact, options.onReply)
    then
      return true
    end
  end

  if type(options.onReply) == "function" and openModernMenu(normalized, anchorFrame, options.onReply) then
    return true
  end

  local menuFrame = getMenuFrame()
  if menuFrame == nil then
    return ContextMenu.CopyText(normalized)
  end

  local menuAnchor = anchorFrame or "cursor"
  local menu = {
    {
      text = styleMenuText("Copy Text"),
      notCheckable = true,
      padding = 0,
      minWidth = 1,
      fontObject = Theme.FONTS.icon_label,
      func = function()
        ContextMenu.CopyText(normalized)
      end,
    },
  }
  if type(options.onReply) == "function" then
    table.insert(menu, 1, {
      text = styleMenuText(Localization.Text("Reply")),
      notCheckable = true,
      padding = 0,
      minWidth = 1,
      fontObject = Theme.FONTS.icon_label,
      func = options.onReply,
    })
  end

  if type(_G.EasyMenu) == "function" then
    local ok = pcall(_G.EasyMenu, menu, menuFrame, menuAnchor, 0, 0, "MENU")
    if ok then
      return true
    end
    return ContextMenu.CopyText(normalized)
  end

  if
    type(_G.UIDropDownMenu_Initialize) ~= "function"
    or type(_G.UIDropDownMenu_CreateInfo) ~= "function"
    or type(_G.UIDropDownMenu_AddButton) ~= "function"
    or type(_G.ToggleDropDownMenu) ~= "function"
  then
    return ContextMenu.CopyText(normalized)
  end

  local function initializeMenu(_, level)
    if level ~= 1 then
      return
    end

    for _, item in ipairs(menu) do
      local info = _G.UIDropDownMenu_CreateInfo()
      for key, value in pairs(item) do
        info[key] = value
      end
      _G.UIDropDownMenu_AddButton(info, level)
    end
  end

  local initialized = pcall(_G.UIDropDownMenu_Initialize, menuFrame, initializeMenu, "MENU")
  if not initialized then
    return ContextMenu.CopyText(normalized)
  end

  local toggled = pcall(_G.ToggleDropDownMenu, 1, nil, menuFrame, menuAnchor, 0, 0)
  if not toggled then
    return ContextMenu.CopyText(normalized)
  end
  return true
end

ns.ChatBubbleContextMenu = ContextMenu
return ContextMenu
