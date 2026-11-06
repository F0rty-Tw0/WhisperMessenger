local FakeUI = require("tests.helpers.fake_ui")
local Bootstrap = require("WhisperMessenger.Bootstrap")
local Theme = require("WhisperMessenger.UI.Theme")
local EventBridge = require("WhisperMessenger.Core.Bootstrap.EventBridge")

-- Boots the real runtime on the phone layout for the integration tests.
local PhoneRuntime = {}

PhoneRuntime.KEY = "wow::WOW::arthas-area52"
PhoneRuntime.OTHER = "wow::WOW::jaina-area52"

local SLIDE = Theme.LAYOUT.PHONE_SLIDE_SECONDS + 0.01

local function conversation(name, unread)
  return {
    displayName = name,
    channel = "WOW",
    lastActivityAt = os.time(),
    unreadCount = unread,
    messages = { { direction = "in", kind = "user", playerName = name, text = "Need help?", sentAt = os.time() } },
  }
end

local function boot(settings)
  local factory = FakeUI.NewFactory()
  local saved = { uiParent = _G.UIParent, slash = _G.SlashCmdList }
  _G.UIParent = factory.CreateFrame("Frame", "UIParent", nil)
  _G.UIParent:SetSize(1920, 1080)
  _G.UIParent:Show()
  _G.SlashCmdList = {}
  local accountSettings = { phoneLayout = true }
  for key, value in pairs(settings or {}) do
    accountSettings[key] = value
  end
  local runtime = Bootstrap.Initialize(factory, {
    localProfileId = "me",
    accountState = {
      schemaVersion = 1,
      conversations = {
        [PhoneRuntime.KEY] = conversation("Arthas-Area52", 2),
        [PhoneRuntime.OTHER] = conversation("Jaina-Area52", 0),
      },
      contacts = {},
      pendingHydration = {},
      settings = accountSettings,
    },
    characterState = { window = { x = 0, y = 0, width = 900, height = 560 }, icon = {} },
  })
  return runtime, function()
    _G.UIParent = saved.uiParent
    _G.SlashCmdList = saved.slash
  end
end

-- body(runtime) runs on a fresh boot; settings add to { phoneLayout = true }.
function PhoneRuntime.Run(settings, body)
  local runtime, restore = boot(settings)
  local ok, err = pcall(body, runtime)
  restore()
  assert(ok, err)
end

function PhoneRuntime.FinishSlide(runtime)
  local viewport = runtime.window.phoneViewport
  if viewport.scripts and viewport.scripts.OnUpdate then
    viewport.scripts.OnUpdate(viewport, SLIDE)
  end
end

function PhoneRuntime.ClickRow(runtime, key)
  for _, row in ipairs(runtime.window.contacts.rows) do
    if row.item and row.item.conversationKey == key then
      row.scripts.OnClick(row, "LeftButton")
      PhoneRuntime.FinishSlide(runtime)
      return
    end
  end
  error("no row for " .. key)
end

function PhoneRuntime.ClickBack(runtime)
  local back = runtime.window.backButton
  back.scripts.OnClick(back)
  PhoneRuntime.FinishSlide(runtime)
end

-- One live whisper from Arthas-Area52, then the slide it may start.
function PhoneRuntime.ReceiveWhisper(runtime)
  local saved = rawget(_G, "InCombatLockdown")
  rawset(_G, "InCombatLockdown", function()
    return false
  end)
  EventBridge.RouteLiveEvent(
    runtime,
    runtime.refreshWindow,
    "CHAT_MSG_WHISPER",
    "hello",
    "Arthas-Area52",
    "",
    "",
    "",
    0,
    0,
    "",
    0,
    999,
    1001,
    "Player-1-0ABC"
  )
  rawset(_G, "InCombatLockdown", saved)
  PhoneRuntime.FinishSlide(runtime)
end

return PhoneRuntime
