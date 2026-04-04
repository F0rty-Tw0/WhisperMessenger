local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ContextMenu = {}
local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local ManualCopy = ns.ChatBubbleContextMenuManualCopy
  or require("WhisperMessenger.UI.ChatBubble.ContextMenu.ManualCopy")

local MENU_FRAME_NAME = "WhisperMessengerBubbleContextMenu"

local function colorToHex(color)
  local function component(value)
    local v = math.floor((tonumber(value) or 1) * 255 + 0.5)
    if v < 0 then
      v = 0
    elseif v > 255 then
      v = 255
    end
    return v
  end

  local r = component(color and color[1] or 1)
  local g = component(color and color[2] or 1)
  local b = component(color and color[3] or 1)
  return string.format("|cff%02x%02x%02x", r, g, b)
end

local function styleMenuText(text)
  return colorToHex(Theme.COLORS.option_button_text) .. text .. "|r"
end

local function getMenuFrame()
  if type(_G.CreateFrame) ~= "function" or _G.UIParent == nil then
    return nil
  end

  local frame = _G[MENU_FRAME_NAME]
  if frame ~= nil then
    return frame
  end

  return _G.CreateFrame("Frame", MENU_FRAME_NAME, _G.UIParent, "UIDropDownMenuTemplate")
end

function ContextMenu.CopyText(text)
  if type(ManualCopy) ~= "table" or type(ManualCopy.CopyText) ~= "function" then
    return false
  end

  return ManualCopy.CopyText(text)
end

function ContextMenu.Open(text, anchorFrame)
  local normalized = type(ManualCopy) == "table"
      and type(ManualCopy.NormalizeText) == "function"
      and ManualCopy.NormalizeText(text)
    or nil
  if normalized == nil then
    return false
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

  if type(_G.EasyMenu) == "function" then
    _G.EasyMenu(menu, menuFrame, menuAnchor, 0, 0, "MENU")
    return true
  end

  if
    type(_G.UIDropDownMenu_Initialize) ~= "function"
    or type(_G.UIDropDownMenu_CreateInfo) ~= "function"
    or type(_G.UIDropDownMenu_AddButton) ~= "function"
    or type(_G.ToggleDropDownMenu) ~= "function"
  then
    return false
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

  pcall(_G.UIDropDownMenu_Initialize, menuFrame, initializeMenu, "MENU")

  _G.ToggleDropDownMenu(1, nil, menuFrame, menuAnchor, 0, 0)
  return true
end

ns.ChatBubbleContextMenu = ContextMenu
return ContextMenu
