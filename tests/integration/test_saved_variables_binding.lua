local FakeUI = require("tests.helpers.fake_ui")

local function loadAddonFromToc(addonName, ns)
  for line in io.lines("WhisperMessenger.toc") do
    if line ~= "" and string.sub(line, 1, 2) ~= "##" then
      local chunk = assert(loadfile(line))
      chunk(addonName, ns)
    end
  end
end

return function()
  local savedRequire = require
  local savedCreateFrame = _G.CreateFrame
  local savedDB = _G.WhisperMessengerDB
  local savedCharacterDB = _G.WhisperMessengerCharacterDB

  local createdFrames = {}
  local factory = FakeUI.NewFactory()

  _G.require = nil
  _G.WhisperMessengerDB = nil
  _G.WhisperMessengerCharacterDB = nil
  _G.CreateFrame = function(frameType, name, parent)
    local frame = factory.CreateFrame(frameType, name, parent)
    table.insert(createdFrames, frame)

    function frame:RegisterEvent(eventName)
      self.events = self.events or {}
      self.events[eventName] = true
    end

    function frame:UnregisterEvent(eventName)
      if self.events then
        self.events[eventName] = nil
      end
    end

    return frame
  end

  local ns = {}
  loadAddonFromToc("WhisperMessenger", ns)

  local eventFrame
  for _, frame in ipairs(createdFrames) do
    if frame.scripts and frame.scripts.OnEvent then
      eventFrame = frame
      break
    end
  end

  assert(eventFrame ~= nil, "expected addon load event frame")
  eventFrame.scripts.OnEvent(eventFrame, "ADDON_LOADED", "WhisperMessenger")

  assert(type(_G.WhisperMessengerDB) == "table", "expected bootstrap to bind account saved variables")
  assert(type(_G.WhisperMessengerCharacterDB) == "table", "expected bootstrap to bind character saved variables")

  _G.WhisperMessengerDB.conversations["current::WOW::arthas-area52"] = {
    displayName = "Arthas-Area52",
    unreadCount = 1,
    lastPreview = "hi",
    lastActivityAt = 1,
    channel = "WOW",
    messages = {
      { text = "hi" },
    },
  }

  assert(ns.Bootstrap.runtime.accountState == _G.WhisperMessengerDB)
  assert(ns.Bootstrap.runtime.characterState == _G.WhisperMessengerCharacterDB)

  _G.require = savedRequire
  _G.CreateFrame = savedCreateFrame
  _G.WhisperMessengerDB = savedDB
  _G.WhisperMessengerCharacterDB = savedCharacterDB
end
