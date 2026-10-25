local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local OptionsPanelLayout = ns.MessengerWindowLayoutOptionsPanelLayout
  or require("WhisperMessenger.UI.MessengerWindow.LayoutBuilder.OptionsPanelLayout")
local PanelBadge = ns.PanelBadge or require("WhisperMessenger.UI.Shared.PanelBadge")

-- Hosts other addons' panels in the window: one hidden frame per panel,
-- placed like the options pane, plus its tab in the strip. The caller's
-- callbacks run under pcall, so a broken panel cannot break the window.
local PanelHost = {}

local function isOptionalFunction(value)
  return value == nil or type(value) == "function"
end

local function isValidPanel(panel)
  return type(panel) == "table"
    and type(panel.title) == "string"
    and type(panel.onShow) == "function"
    and isOptionalFunction(panel.onHide)
    and isOptionalFunction(panel.onSplit)
    and isOptionalFunction(panel.badge)
end

-- options: factory, parent, nativeChrome, theme, listWidth (the divider's x
-- from the left edge, the seed for onSplit), addTab(key, title, onClick)
-- -> { setBadge(n) }, onTabClick(key).
function PanelHost.Create(options)
  local factory = options.factory
  local parent = options.parent
  local theme = options.theme or Theme
  local nativeChrome = options.nativeChrome == true
  local addTab = options.addTab
  local onTabClick = options.onTabClick
  local entries = {}
  local lastWidth = options.listWidth

  local function refreshBadge(key)
    local entry = entries[key]
    if entry == nil then
      return
    end
    entry.tab.setBadge(PanelBadge.Read(entry.panel.badge))
  end

  local function register(key, panel)
    if entries[key] ~= nil or not isValidPanel(panel) then
      return false
    end
    local frame = factory.CreateFrame("Frame", nil, parent)
    OptionsPanelLayout.AnchorPanel(frame, parent, nativeChrome, theme)
    frame:Hide()
    local tab = addTab(key, panel.title, function()
      onTabClick(key)
    end)
    entries[key] = { panel = panel, frame = frame, tab = tab, shown = false }
    refreshBadge(key)
    return true
  end

  local function show(key)
    local entry = entries[key]
    if entry == nil then
      return false
    end
    entry.frame:Show()
    entry.shown = true
    pcall(entry.panel.onShow, entry.frame)
    if entry.panel.onSplit then
      pcall(entry.panel.onSplit, entry.frame, lastWidth)
    end
    refreshBadge(key)
    return true
  end

  local function hide(key)
    local entry = entries[key]
    if entry == nil or not entry.shown then
      return
    end
    entry.shown = false
    entry.frame:Hide()
    if entry.panel.onHide then
      pcall(entry.panel.onHide)
    end
  end

  -- The divider moved: remember where, and tell the open panel.
  local function setSplit(width)
    lastWidth = width
    for _, entry in pairs(entries) do
      if entry.shown and entry.panel.onSplit then
        pcall(entry.panel.onSplit, entry.frame, width)
      end
    end
  end

  return {
    register = register,
    setSplit = setSplit,
    show = show,
    hide = hide,
    refreshBadge = refreshBadge,
    has = function(key)
      return entries[key] ~= nil
    end,
    frameOf = function(key)
      return entries[key] and entries[key].frame
    end,
  }
end

ns.MessengerWindowPanelHost = PanelHost
return PanelHost
