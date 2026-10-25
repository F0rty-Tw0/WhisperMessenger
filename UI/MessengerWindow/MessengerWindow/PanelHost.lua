local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local OptionsPanelLayout = ns.MessengerWindowLayoutOptionsPanelLayout
  or require("WhisperMessenger.UI.MessengerWindow.LayoutBuilder.OptionsPanelLayout")

-- Hosts other addons' panels in the window: one hidden frame per panel,
-- placed like the options pane, plus its title-bar button. The caller's
-- callbacks run under pcall, so a broken panel cannot break the window.
local PanelHost = {}

local function isOptionalFunction(value)
  return value == nil or type(value) == "function"
end

local function isValidPanel(panel)
  return type(panel) == "table"
    and type(panel.title) == "string"
    and (type(panel.icon) == "string" or type(panel.icon) == "number")
    and type(panel.onShow) == "function"
    and isOptionalFunction(panel.onHide)
    and isOptionalFunction(panel.badge)
end

-- options: factory, parent, chrome (addPanelButton), nativeChrome, theme,
-- onButtonClick(key).
function PanelHost.Create(options)
  local factory = options.factory
  local parent = options.parent
  local chrome = options.chrome
  local theme = options.theme or Theme
  local nativeChrome = options.nativeChrome == true
  local onButtonClick = options.onButtonClick
  local entries = {}

  local function refreshBadge(key)
    local entry = entries[key]
    if entry == nil then
      return
    end
    local count = 0
    if entry.panel.badge then
      local ok, value = pcall(entry.panel.badge)
      if ok and type(value) == "number" then
        count = value
      end
    end
    entry.button.setBadge(count)
  end

  local function register(key, panel)
    if entries[key] ~= nil or not isValidPanel(panel) then
      return false
    end
    local frame = factory.CreateFrame("Frame", nil, parent)
    OptionsPanelLayout.AnchorPanel(frame, parent, nativeChrome, theme)
    frame:Hide()
    local button = chrome.addPanelButton(key, panel, onButtonClick)
    entries[key] = { panel = panel, frame = frame, button = button, shown = false }
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

  return {
    register = register,
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
