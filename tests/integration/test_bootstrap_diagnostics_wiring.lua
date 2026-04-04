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
  local savedCreateFrame = _G.CreateFrame
  local savedUIParent = _G.UIParent
  local savedSlashCmdList = _G.SlashCmdList
  local savedSlash1 = _G.SLASH_WHISPERMESSENGER1
  local savedSlash2 = _G.SLASH_WHISPERMESSENGER2
  local savedUnitFullName = _G.UnitFullName
  local savedGetNormalizedRealmName = _G.GetNormalizedRealmName
  local savedTime = _G.time
  local savedAccountDb = _G.WhisperMessengerDB
  local savedCharacterDb = _G.WhisperMessengerCharacterDB

  local createdFrames = {}
  local diagnosticsCreateCalls = 0
  local debugCalls = {}
  local memoryReportCalls = 0
  local factory = FakeUI.NewFactory()
  local conversationKey = "wow::WOW::jaina-proudmoore"

  _G.require = nil
  _G.UIParent = factory.CreateFrame("Frame", "UIParent", nil)
  _G.SlashCmdList = {}
  _G.SLASH_WHISPERMESSENGER1 = nil
  _G.SLASH_WHISPERMESSENGER2 = nil
  rawset(_G, "UnitFullName", function(unit)
    assert(unit == "player")
    return "Arthas", "Area52"
  end)
  rawset(_G, "GetNormalizedRealmName", function()
    return "Area52"
  end)
  rawset(_G, "time", function()
    return 12345
  end)
  _G.WhisperMessengerDB = {
    conversations = {
      [conversationKey] = {
        displayName = "Jaina-Proudmoore",
        channel = "WOW",
        messages = {
          { text = "hello" },
        },
        unreadCount = 0,
        lastActivityAt = 10,
        conversationKey = conversationKey,
      },
    },
    contacts = {},
    pendingHydration = {},
    schemaVersion = 1,
  }
  _G.WhisperMessengerCharacterDB = {
    window = {
      anchorPoint = "CENTER",
      relativePoint = "CENTER",
      x = 0,
      y = 0,
      width = 920,
      height = 580,
      minimized = false,
    },
    icon = {
      anchorPoint = "CENTER",
      relativePoint = "CENTER",
      x = 0,
      y = 0,
    },
  }
  rawset(_G, "CreateFrame", function(frameType, name, parent, template)
    local frame = factory.CreateFrame(frameType, name, parent, template)
    createdFrames[#createdFrames + 1] = frame

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
  end)

  local ns = {}
  loadAddonFromToc("WhisperMessenger", ns)
  ns.BootstrapDiagnostics = {
    Create = function()
      diagnosticsCreateCalls = diagnosticsCreateCalls + 1
      return {
        debugContact = function(key)
          debugCalls[#debugCalls + 1] = key
        end,
        memoryReport = function()
          memoryReportCalls = memoryReportCalls + 1
        end,
      }
    end,
  }

  local eventFrame = nil
  for _, frame in ipairs(createdFrames) do
    if frame.scripts and frame.scripts.OnEvent then
      eventFrame = frame
      break
    end
  end

  assert(eventFrame ~= nil, "expected addon load event frame")
  eventFrame.scripts.OnEvent(eventFrame, "ADDON_LOADED", "WhisperMessenger")

  local runtime = ns.Bootstrap.runtime
  assert(runtime ~= nil, "expected runtime after addon load")
  assert(diagnosticsCreateCalls == 1, "expected Bootstrap to construct diagnostics exactly once")

  runtime.toggle()
  assert(runtime.window ~= nil, "expected runtime.toggle to create the messenger window")
  assert(runtime.window.contacts.rows[1] ~= nil, "expected a contact row for the preloaded conversation")

  runtime.window.contacts.rows[1].scripts.OnClick()
  assert(#debugCalls == 1, "expected selecting a conversation to call diagnostics.debugContact")
  assert(debugCalls[1] == conversationKey, "expected diagnostics.debugContact to receive the selected conversation key")

  _G.SlashCmdList.WHISPERMESSENGER("mem")
  assert(memoryReportCalls == 1, "expected slash mem to route to diagnostics.memoryReport")

  _G.require = savedRequire
  rawset(_G, "CreateFrame", savedCreateFrame)
  _G.UIParent = savedUIParent
  _G.SlashCmdList = savedSlashCmdList
  _G.SLASH_WHISPERMESSENGER1 = savedSlash1
  _G.SLASH_WHISPERMESSENGER2 = savedSlash2
  rawset(_G, "UnitFullName", savedUnitFullName)
  rawset(_G, "GetNormalizedRealmName", savedGetNormalizedRealmName)
  rawset(_G, "time", savedTime)
  _G.WhisperMessengerDB = savedAccountDb
  _G.WhisperMessengerCharacterDB = savedCharacterDb
end
