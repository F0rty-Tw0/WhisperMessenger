local MessengerWindow = require("WhisperMessenger.UI.MessengerWindow")
local ContactsList = require("WhisperMessenger.UI.ContactsList")
local FakeUI = require("tests.helpers.fake_ui")

local function newStrictFactory()
  local base = FakeUI.NewFactory()
  local originalCreateFrame = base.CreateFrame

  base.CreateFrame = function(frameType, name, parent, template)
    local frame = originalCreateFrame(frameType, name, parent, template)
    local width, height = frame.width, frame.height

    local originalSetSize = frame.SetSize
    frame.SetSize = function(self, nextWidth, nextHeight)
      assert(type(nextWidth) == "number", "expected numeric width")
      assert(type(nextHeight) == "number", "expected numeric height")
      width = nextWidth
      height = nextHeight
      originalSetSize(self, nextWidth, nextHeight)
      self.width = nil
      self.height = nil
    end

    frame.GetWidth = function()
      return width
    end

    frame.GetHeight = function()
      return height
    end

    return frame
  end

  return base
end

return function()
  local items = ContactsList.BuildItems({
    ["me::WOW::jaina-proudmoore"] = {
      displayName = "Jaina-Proudmoore",
      unreadCount = 2,
      lastActivityAt = 20,
      channel = "WOW",
    },
  })

  local factory = newStrictFactory()
  local ok, window = pcall(MessengerWindow.Create, factory, {
    title = "WhisperMessenger",
    contacts = items,
  })

  assert(ok == true, tostring(window))
  assert(window.threadPane ~= nil)
  assert(window.composerPane ~= nil)
end
