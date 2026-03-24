local FakeUI = require("tests.helpers.fake_ui")

local function loadAddonFromToc(addonName, ns)
  for line in io.lines("WhisperMessenger.toc") do
    if line ~= "" and string.sub(line, 1, 2) ~= "##" and not string.match(line, "%.xml$") then
      local chunk = assert(loadfile(line))
      chunk(addonName, ns)
    end
  end
end

return function()
  local savedRequire = require
  local savedPrint = _G.print
  local savedCreateFrame = _G.CreateFrame
  local savedUIParent = _G.UIParent
  local savedSlashCmdList = _G.SlashCmdList
  local savedSlash1 = _G.SLASH_WHISPERMESSENGER1
  local savedSlash2 = _G.SLASH_WHISPERMESSENGER2

  local traces = {}
  local createdFrames = {}
  local factory = FakeUI.NewFactory()

  _G.require = nil
  _G.print = function(...)
    local parts = {}
    for index = 1, select("#", ...) do
      parts[index] = tostring(select(index, ...))
    end
    table.insert(traces, table.concat(parts, " "))
  end
  _G.UIParent = factory.CreateFrame("Frame", "UIParent", nil)
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

  -- Enable tracing so lifecycle trace() calls produce output captured by the
  -- overridden _G.print above. Tracing is off by default; the test verifies
  -- that the trace calls are wired up correctly when tracing is enabled.
  if ns.trace and ns.trace.enable then
    ns.trace.enable()
  end

  local eventFrame
  for _, frame in ipairs(createdFrames) do
    if frame.scripts and frame.scripts.OnEvent then
      eventFrame = frame
      break
    end
  end

  assert(eventFrame ~= nil, "expected addon load event frame")
  eventFrame.scripts.OnEvent(eventFrame, "ADDON_LOADED", "WhisperMessenger")
  _G.SlashCmdList.WHISPERMESSENGER()

  local joined = table.concat(traces, "\n")
  assert(string.find(joined, "ADDON_LOADED", 1, true) ~= nil)
  assert(string.find(joined, "slash registered /wmsg /whispermessenger", 1, true) ~= nil)
  assert(string.find(joined, "window created", 1, true) ~= nil)
  assert(string.find(joined, "slash invoked", 1, true) ~= nil)
  assert(string.find(joined, "set visible=true", 1, true) ~= nil)

  _G.require = savedRequire
  _G.print = savedPrint
  _G.CreateFrame = savedCreateFrame
  _G.UIParent = savedUIParent
  _G.SlashCmdList = savedSlashCmdList
  _G.SLASH_WHISPERMESSENGER1 = savedSlash1
  _G.SLASH_WHISPERMESSENGER2 = savedSlash2
end
