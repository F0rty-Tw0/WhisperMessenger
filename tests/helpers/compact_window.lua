local CompactSlideClock = require("tests.helpers.compact_slide_clock")
local MessengerWindow = require("WhisperMessenger.UI.MessengerWindow")
local ContactsList = require("WhisperMessenger.UI.ContactsList")
local Hud = require("WhisperMessenger.UI.Theme.Hud")
local FakeUI = require("tests.helpers.fake_ui")
local GrowRig = require("tests.helpers.grow_rig")
local WindowGrowAnimation = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.WindowGrowAnimation")

-- A real compact-layout window with a recording stand-in for the button.
local CompactWindow = {}

local function contacts()
  return ContactsList.BuildItems({
    ["me::WOW::jaina"] = { displayName = "Jaina", channel = "WOW", lastActivityAt = 2, unreadCount = 1 },
    ["guild::me"] = { displayName = "Guild", channel = "GUILD", lastActivityAt = 1, unreadCount = 0 },
  })
end

function CompactWindow.Build(extra)
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
  case.uiParent = _G.UIParent
  case.created = {}
  local createFrame = factory.CreateFrame
  factory.CreateFrame = function(...)
    local created = createFrame(...)
    case.created[#case.created + 1] = created
    return created
  end
  case.minimap = factory.CreateFrame("Button", "Mini", _G.UIParent)
  -- homeMoves: calls that would move the button's home (ToggleIcon's setRideHome).
  case.rides, case.homes, case.homeMoves = 0, 0, 0
  -- adopted: calls that would make the button's current spot its home (adoptRidePosition).
  case.adopted = 0
  case.icon = {
    frame = fab,
    isRiding = function()
      return case.rides > case.homes
    end,
    rideTo = function(target, onStep, instant)
      case.rides = case.rides + 1
      case.rodeTo = target
      case.step = onStep
      case.instant = instant
    end,
    rideHome = function(onStep, instant)
      case.homes = case.homes + 1
      case.step = onStep
      case.homeInstant = instant
    end,
    setRideHome = function()
      case.homeMoves = case.homeMoves + 1
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
    compactLayout = true,
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
  options.getGrowSource = function()
    local dock = options.getDockIcon and options.getDockIcon()
    return dock and dock.frame or nil
  end
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

function CompactWindow.Select(case, key)
  local item = { conversationKey = key, displayName = key, channel = "WOW" }
  case.window.refreshSelection({ selectedContact = item })
end

function CompactWindow.FinishSlide(case)
  CompactSlideClock.Finish(case.window.compactViewport)
end

-- Screen positions and visibility, which the fake client does not give.
-- Window 100..460 x 100..740; button centred on 800,500; minimap icon centred on 1516,116.
function CompactWindow.Lay(case)
  case.uiParent:Show()
  case.fab:Show()
  case.minimap:Show()
  GrowRig.rect(case.window.frame, 100, 100, 460, 740)
  GrowRig.rect(case.fab, 779, 479, 821, 521)
  GrowRig.rect(case.minimap, 1500, 100, 1532, 132)
end

-- The grow panel is the one frame built at the panel level.
function CompactWindow.Panel(case)
  local found
  for _, created in ipairs(case.created) do
    if created:GetFrameLevel() == WindowGrowAnimation.PANEL_LEVEL then
      assert(found == nil, "two frames at the panel level")
      found = created
    end
  end
  return assert(found, "no grow panel was built")
end

CompactWindow.HasClock = GrowRig.running

-- Ticks the frame's OnUpdate until the clock ends itself.
function CompactWindow.RunClock(frame)
  for _ = 1, 20 do
    if not CompactWindow.HasClock(frame) then
      return
    end
    frame.scripts.OnUpdate(frame, 0.05)
  end
  error("the clock never ended")
end

-- Runs a script's hooks without touching the frame's shown state (Alt+Z hides the parent only).
function CompactWindow.Fire(frame, name)
  for _, hook in ipairs(frame._hookScripts[name]) do
    hook(frame)
  end
end

-- Alt+Z again: the client shows the parent, so the window gets OnShow while it never stopped being shown.
function CompactWindow.ParentShows(frame)
  frame.shown = true
  if frame.scripts.OnShow then
    frame.scripts.OnShow(frame)
  end
  for _, hook in ipairs(frame._hookScripts.OnShow or {}) do
    hook(frame)
  end
end

return CompactWindow
