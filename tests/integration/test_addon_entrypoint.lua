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
  local savedSlashCmdList = _G.SlashCmdList
  local savedSlash1 = _G.SLASH_WHISPERMESSENGER1
  local savedSlash2 = _G.SLASH_WHISPERMESSENGER2

  local createdFrames = {}
  local factory = FakeUI.NewFactory()

  _G.require = nil
  _G.SlashCmdList = {}
  _G.SLASH_WHISPERMESSENGER1 = nil
  _G.SLASH_WHISPERMESSENGER2 = nil
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

  assert(_G.SLASH_WHISPERMESSENGER1 == "/wmsg")
  assert(_G.SLASH_WHISPERMESSENGER2 == "/whispermessenger")
  assert(type(_G.SlashCmdList.WHISPERMESSENGER) == "function")

  local windowFrame
  for _, frame in ipairs(createdFrames) do
    if frame.name == "WhisperMessengerWindow" then
      windowFrame = frame
      break
    end
  end

  assert(windowFrame ~= nil, "expected messenger window frame")
  assert(windowFrame.shown == false)
  _G.SlashCmdList.WHISPERMESSENGER()
  assert(windowFrame.shown == true)

  _G.require = savedRequire
  _G.CreateFrame = savedCreateFrame
  _G.SlashCmdList = savedSlashCmdList
  _G.SLASH_WHISPERMESSENGER1 = savedSlash1
  _G.SLASH_WHISPERMESSENGER2 = savedSlash2
end
