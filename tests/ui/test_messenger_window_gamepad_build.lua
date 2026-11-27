-- With the gamepad UI on, the game re-scans the whole open window on every
-- CreateFrame under it: opening a chat or filling the contact list must not
-- create frames inside the window.
local FakeUI = require("tests.helpers.fake_ui")
local MessengerWindow = require("WhisperMessenger.UI.MessengerWindow")

local function isUnder(frame, ancestor)
  while frame do
    if frame == ancestor then
      return true
    end
    frame = frame.parent
  end
  return false
end

local function contact(index)
  return {
    conversationKey = "me::WOW::friend" .. index,
    displayName = "Friend" .. index,
    channel = "WOW",
    lastPreview = "hi",
    lastActivityAt = index,
    unreadCount = 1,
  }
end

local function message(index)
  return {
    direction = index % 2 == 0 and "in" or "out",
    kind = "user",
    text = "hello " .. index,
    sentAt = index,
    playerName = "Arthas",
    senderName = "Arthas",
  }
end

-- Calls fn(window, created) with the gamepad UI on; created.inside lists the
-- "type template" of each CreateFrame under the window since the build.
local function withWindow(fn)
  local savedInput, savedUIParent, savedCreate = _G.InputUtil, _G.UIParent, _G.CreateFrame
  local plain = FakeUI.NewFactory()
  _G.UIParent = plain.CreateFrame("Frame", "UIParent", nil)
  _G.UIParent:SetSize(1920, 1080)
  _G.InputUtil = {
    IsGamepadUIEnabled = function()
      return true
    end,
  }
  local created = { inside = {} }
  local window
  local function createFrame(kind, name, parent, template)
    if window and isUnder(parent, window.frame) then
      created.inside[#created.inside + 1] = kind .. " " .. tostring(template)
    end
    return plain.CreateFrame(kind, name, parent, template)
  end
  _G.CreateFrame = createFrame
  local spy = setmetatable({ CreateFrame = createFrame }, { __index = plain })
  local ok, err = pcall(function()
    window = MessengerWindow.Create(spy, {
      contacts = {},
      state = { width = 900, height = 560 },
    })
    fn(window, created)
  end)
  _G.InputUtil, _G.UIParent, _G.CreateFrame = savedInput, savedUIParent, savedCreate
  assert(ok, err)
end

return function()
  -- test_opening_a_chat_creates_no_frame_inside_the_window
  withWindow(function(window, created)
    local messages = {}
    for i = 1, 20 do
      messages[i] = message(i)
    end
    window.refreshSelection({
      selectedContact = contact(1),
      conversation = { messages = messages },
      status = nil,
    })
    assert(#created.inside == 0, "each one re-scans the window: " .. table.concat(created.inside, ", "))
  end)

  -- test_new_contact_rows_create_no_frame_inside_the_window
  withWindow(function(window, created)
    local contacts = {}
    for i = 1, 12 do
      contacts[i] = contact(i)
    end
    window.refreshSelection({ contacts = contacts })
    assert(#created.inside == 0, "each one re-scans the window: " .. table.concat(created.inside, ", "))
  end)
end
