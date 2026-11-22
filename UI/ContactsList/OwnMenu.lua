local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- stylua: ignore start
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local MenuPopup = ns.MenuPopup or require("WhisperMessenger.UI.Shared.MenuPopup")
local ProtectedMenuEntries = ns.ContactsListProtectedMenuEntries or require("WhisperMessenger.UI.ContactsList.ProtectedMenuEntries")
-- stylua: ignore end

-- The contact row's right-click popup on WoW: Forever, drawn by MenuPopup
-- because the game's player menus taint when addon code opens them. Rows
-- follow the game's FRIEND menu: title, Open chat, Copy name, the WM
-- section, then Report.
local OwnMenu = {}

-- A check that throws counts as no.
local function safely(fn, ...)
  local ok, result = pcall(fn, ...)
  return ok and result or nil
end

local function chatLocation(item)
  local chatInfo = _G.C_ChatInfo
  if item.lineID == nil or type(chatInfo) ~= "table" or type(chatInfo.IsValidChatLine) ~= "function" then
    return nil
  end
  if safely(chatInfo.IsValidChatLine, item.lineID) ~= true then
    return nil
  end
  return safely(_G.PlayerLocation.CreateFromChatLineID, _G.PlayerLocation, item.lineID)
end

-- Same order as the game's player menu: the chat line first, else the GUID.
local function playerLocation(item)
  local playerLocationApi = _G.PlayerLocation
  if type(playerLocationApi) ~= "table" then
    return nil
  end
  if type(playerLocationApi.CreateFromChatLineID) == "function" then
    local location = chatLocation(item)
    if location ~= nil then
      return location, "Chat"
    end
  end
  if item.guid ~= nil and type(playerLocationApi.CreateFromGUID) == "function" then
    return safely(playerLocationApi.CreateFromGUID, playerLocationApi, item.guid), "Friend"
  end
  return nil
end

local function reportApisExist(kind)
  local reportFrame, reportInfo, enum = _G.ReportFrame, _G.ReportInfo, _G.Enum
  return type(reportFrame) == "table"
    and type(reportFrame.InitiateReport) == "function"
    and type(reportInfo) == "table"
    and type(reportInfo.CreateReportInfoFromType) == "function"
    and type(enum) == "table"
    and type(enum.ReportType) == "table"
    and enum.ReportType[kind] ~= nil
end

local function canReport(location)
  local reportSystem = _G.C_ReportSystem
  if type(location) ~= "table" or type(location.IsValid) ~= "function" then
    return false
  end
  if safely(location.IsValid, location) ~= true then
    return false
  end
  if type(reportSystem) ~= "table" or type(reportSystem.CanReportPlayer) ~= "function" then
    return false
  end
  return safely(reportSystem.CanReportPlayer, location) == true
end

-- The Report click, or nil when the game would not offer Report.
local function reportHandler(item, name)
  local location, kind = playerLocation(item)
  if location == nil or not reportApisExist(kind) or not canReport(location) then
    return nil
  end
  return function()
    local info = _G.ReportInfo:CreateReportInfoFromType(_G.Enum.ReportType[kind])
    _G.ReportFrame:InitiateReport(info, name, location, item.channel == "BN")
  end
end

local function addChatRows(root, item, rowActions)
  if type(rowActions) == "table" and type(rowActions.onSelect) == "function" then
    root:CreateButton(Localization.Text("Open chat"), function()
      rowActions.onSelect(item)
    end)
  end
  local onCopy = item.channel == "WOW" and ProtectedMenuEntries.CopyNameHandler(item) or nil
  if onCopy ~= nil then
    root:CreateButton(Localization.Text("Copy name"), onCopy)
  end
end

-- addWmSection(root) adds the divider, the gold title and the WM entries,
-- or nothing. options (optional) goes to MenuPopup.Open as is.
function OwnMenu.Open(item, anchorFrame, name, rowActions, addWmSection, options)
  if type(item) ~= "table" then
    return false
  end
  return MenuPopup.Open(anchorFrame, function(root)
    root:CreateTitle(name)
    addChatRows(root, item, rowActions)
    if type(addWmSection) == "function" then
      addWmSection(root)
    end
    local onReport = reportHandler(item, name)
    if onReport ~= nil then
      root:CreateDivider()
      root:CreateButton(Localization.Text("Report"), onReport)
    end
  end, options)
end

ns.ContactsListOwnMenu = OwnMenu
return OwnMenu
