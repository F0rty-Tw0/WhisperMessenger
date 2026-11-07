local MessengerWindow = require("WhisperMessenger.UI.MessengerWindow")
local ContactsList = require("WhisperMessenger.UI.ContactsList")
local Hud = require("WhisperMessenger.UI.Theme.Hud")
local FakeUI = require("tests.helpers.fake_ui")

-- A real phone-layout window with a recording stand-in for the button.
local PhoneWindow = {}

local SLIDE_FRAMES = 60

local function contacts()
  return ContactsList.BuildItems({
    ["me::WOW::jaina"] = { displayName = "Jaina", channel = "WOW", lastActivityAt = 2, unreadCount = 1 },
    ["guild::me"] = { displayName = "Guild", channel = "GUILD", lastActivityAt = 1, unreadCount = 0 },
  })
end

function PhoneWindow.Build(extra)
  Hud.Configure("off")
  local factory = FakeUI.NewFactory()
  local savedUIParent = _G.UIParent
  _G.UIParent = factory.CreateFrame("Frame", "UIParent", nil)
  _G.UIParent:SetSize(1920, 1080)
  local case = { saved = {}, selections = {} }
  local fab = factory.CreateFrame("Button", "Fab", _G.UIParent)
  rawset(fab, "GetCenter", function()
    return 800, 500
  end)
  case.fab = fab
  case.rides, case.homes, case.adopted = 0, 0, 0
  case.icon = {
    frame = fab,
    isRiding = function()
      return case.rides > case.homes
    end,
    rideTo = function(target, onStep)
      case.rides = case.rides + 1
      case.rodeTo = target
      case.step = onStep
    end,
    rideHome = function(onStep)
      case.homes = case.homes + 1
      case.step = onStep
    end,
    adoptRidePosition = function()
      case.adopted = case.adopted + 1
    end,
    setRideHandlers = function(handlers)
      case.rideHandlers = handlers
    end,
    setRideStrata = function(strata)
      case.rideStrata = strata
    end,
  }
  local options = {
    contacts = contacts(),
    state = {},
    phoneLayout = true,
    settingsConfig = { showGroupChats = true },
    getDockIcon = function()
      return case.icon
    end,
    onPositionChanged = function(state)
      case.saved.state = state
    end,
    onSelectConversation = function(key)
      case.selections[#case.selections + 1] = key == nil and "none" or key
      return nil
    end,
  }
  for key, value in pairs(extra or {}) do
    options[key] = value
  end
  case.window = MessengerWindow.Create(factory, options)
  rawset(case.window.frame, "GetEffectiveScale", function()
    return 1
  end)
  _G.UIParent = savedUIParent
  return case
end

function PhoneWindow.Select(case, key)
  local item = { conversationKey = key, displayName = key, channel = "WOW" }
  case.window.refreshSelection({ selectedContact = item })
end

function PhoneWindow.FinishSlide(case)
  local viewport = case.window.phoneViewport
  -- The slide clamps one tick to 1/30 s, so a slow frame cannot skip it.
  for _ = 1, SLIDE_FRAMES do
    if not (viewport.scripts and viewport.scripts.OnUpdate) then
      return
    end
    viewport.scripts.OnUpdate(viewport, 1 / 60)
  end
end

return PhoneWindow
