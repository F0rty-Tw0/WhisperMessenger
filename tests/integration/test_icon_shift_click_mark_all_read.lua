local Bootstrap = require("WhisperMessenger.Bootstrap")
local FakeUI = require("tests.helpers.fake_ui")

-- Shift + left-click on either icon runs the same mark-all-read path as the
-- title-bar button: every conversation is read, the badge clears, and the
-- window stays closed.
local function conversation(name, unread)
  return {
    displayName = name,
    unreadCount = unread,
    lastPreview = "Hi",
    lastActivityAt = 10,
    channel = "WOW",
    messages = {},
  }
end

local function unreadTotal(runtime)
  local total = 0
  for _, convo in pairs(runtime.store.conversations) do
    total = total + (convo.unreadCount or 0)
  end
  return total
end

return function()
  local factory = FakeUI.NewFactory()
  local framesByName = {}
  local innerCreateFrame = factory.CreateFrame
  factory.CreateFrame = function(frameType, name, parent, template)
    local frame = innerCreateFrame(frameType, name, parent, template)
    if name then
      framesByName[name] = frame
    end
    return frame
  end

  local saved = {
    UIParent = _G.UIParent,
    SlashCmdList = _G.SlashCmdList,
    IsShiftKeyDown = _G.IsShiftKeyDown,
  }
  _G.UIParent = factory.CreateFrame("Frame", "UIParent", nil)
  _G.SlashCmdList = {}
  _G.IsShiftKeyDown = function()
    return true
  end

  local runtime = Bootstrap.Initialize(factory, {
    accountState = {
      schemaVersion = 1,
      settings = { iconMode = "both" },
      conversations = {
        ["me::WOW::arthas-area52"] = conversation("Arthas-Area52", 2),
        ["me::WOW::jaina-proudmoore"] = conversation("Jaina-Proudmoore", 3),
      },
      contacts = {},
      pendingHydration = {},
    },
    characterState = {
      window = { x = 0, y = 0, width = 900, height = 560, minimized = false },
      icon = { anchorPoint = "CENTER", relativePoint = "CENTER", x = 0, y = 0 },
    },
    localProfileId = "me",
  })

  -- test_widget_shift_click_marks_all_read_and_clears_badge
  assert(runtime.icon.badge.shown == true, "widget badge starts shown")
  runtime.icon.frame.scripts.OnClick(runtime.icon.frame, "LeftButton")
  assert(unreadTotal(runtime) == 0, "widget shift-click clears every unread count")
  assert(runtime.icon.badge.shown == false, "widget badge clears")
  assert(runtime.window == nil, "widget shift-click does not open the window")

  -- test_minimap_shift_click_marks_all_read_and_clears_badge
  local _, anyConversation = next(runtime.store.conversations)
  anyConversation.unreadCount = 4
  runtime.refreshWindow()
  local minimapFrame = framesByName.WhisperMessengerMinimapIcon
  assert(minimapFrame ~= nil, "minimap icon exists in 'both' icon mode")
  assert(runtime.icon.badge.shown == true, "badge shows the new unread")
  minimapFrame.scripts.OnClick(minimapFrame, "LeftButton")
  assert(unreadTotal(runtime) == 0, "minimap shift-click clears every unread count")
  assert(runtime.icon.badge.shown == false, "badges clear")
  assert(runtime.window == nil, "minimap shift-click does not open the window")

  _G.UIParent = saved.UIParent
  _G.SlashCmdList = saved.SlashCmdList
  _G.IsShiftKeyDown = saved.IsShiftKeyDown
end
