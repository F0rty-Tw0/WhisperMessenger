local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end
local function trace(...)
  if type(_G.print) == "function" then
    _G.print("[WM]", ...)
  end
end

local function loadModule(name, key)
  if ns[key] then
    return ns[key]
  end

  if type(require) == "function" then
    local ok, loaded = pcall(require, name)
    if ok then
      return loaded
    end
  end

  error(key .. " module not available")
end

local Bootstrap = {}
ns.Bootstrap = Bootstrap

function Bootstrap.Initialize(factory, options)
  options = options or {}
  trace("initialize start")

  local ContactsList = loadModule("WhisperMessenger.UI.ContactsList", "ContactsList")
  local MessengerWindow = loadModule("WhisperMessenger.UI.MessengerWindow", "MessengerWindow")
  local SavedState = loadModule("WhisperMessenger.Persistence.SavedState", "SavedState")
  local Schema = loadModule("WhisperMessenger.Persistence.Schema", "Schema")
  local SlashCommands = loadModule("WhisperMessenger.Core.SlashCommands", "SlashCommands")
  local ToggleIcon = loadModule("WhisperMessenger.UI.ToggleIcon", "ToggleIcon")
  local uiFactory = factory or _G
  local accountState, characterState = SavedState.Initialize(options.accountState, options.characterState)
  local defaultCharacterState = Schema.NewCharacterState()
  local localProfileId = options.localProfileId or "current"
  local contacts = ContactsList.BuildItemsForProfile(accountState, localProfileId)
  trace("initialize contacts=" .. tostring(#contacts))

  local function copyState(source)
    local copy = {}

    for key, value in pairs(source or {}) do
      copy[key] = value
    end

    return copy
  end

  local window
  local icon

  local function setWindowVisible(nextVisible)
    if window == nil or window.frame == nil then
      return
    end

    trace("set visible=" .. tostring(nextVisible))
    if nextVisible then
      window.frame:Show()
    else
      window.frame:Hide()
    end
  end

  local function isWindowVisible()
    if window == nil or window.frame == nil then
      return false
    end

    if window.frame.IsShown then
      return window.frame:IsShown()
    end

    return window.frame.shown == true
  end

  window = MessengerWindow.Create(uiFactory, {
    title = "WhisperMessenger",
    contacts = contacts,
    state = characterState.window,
    onPositionChanged = function(nextState)
      characterState.window = copyState(nextState)
    end,
    onClose = function()
      setWindowVisible(false)
    end,
    onResetWindowPosition = function()
      local nextState = copyState(defaultCharacterState.window)
      characterState.window = nextState
      return nextState
    end,
    onResetIconPosition = function()
      local nextState = copyState(defaultCharacterState.icon)
      characterState.icon = nextState

      if icon and icon.frame and icon.frame.SetPoint then
        local iconParent = icon.frame.parent or _G.UIParent
        icon.frame:SetPoint(nextState.anchorPoint, iconParent, nextState.relativePoint, nextState.x, nextState.y)
      end

      return nextState
    end,
  })

  if window.frame.Hide then
    window.frame:Hide()
  end

  local function toggle()
    setWindowVisible(not isWindowVisible())
  end

  icon = ToggleIcon.Create(uiFactory, {
    state = characterState.icon,
    onToggle = toggle,
    onPositionChanged = function(nextState)
      characterState.icon = copyState(nextState)
    end,
  })

  SlashCommands.Register({
    toggle = toggle,
  })

  trace("initialize complete")

  return {
    accountState = accountState,
    characterState = characterState,
    localProfileId = localProfileId,
    window = window,
    icon = icon,
    toggle = toggle,
  }
end

local function initializeRuntime()
  if Bootstrap.runtime ~= nil then
    trace("runtime already initialized")
    return Bootstrap.runtime
  end

  trace("runtime initialize")
  Bootstrap.runtime = Bootstrap.Initialize(_G, {
    accountState = _G.WhisperMessengerDB,
    characterState = _G.WhisperMessengerCharacterDB,
    localProfileId = "current",
  })

  return Bootstrap.runtime
end

if type(_G.CreateFrame) == "function" then
  local loadFrame = _G.CreateFrame("Frame", "WhisperMessengerLoadFrame")
  loadFrame:RegisterEvent("ADDON_LOADED")
  loadFrame:SetScript("OnEvent", function(_, event, loadedAddonName)
    if event ~= "ADDON_LOADED" or loadedAddonName ~= addonName then
      return
    end

    trace("ADDON_LOADED", loadedAddonName)
    initializeRuntime()

    if loadFrame.UnregisterEvent then
      loadFrame:UnregisterEvent("ADDON_LOADED")
    end
  end)
end

return Bootstrap
