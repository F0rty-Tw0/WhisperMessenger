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
  local savedDB = _G.WhisperMessengerDB
  local savedCharacterDB = _G.WhisperMessengerCharacterDB
  local savedApi = _G.WhisperMessengerAPI

  local createdFrames = {}
  local factory = FakeUI.NewFactory()

  _G.require = nil
  _G.WhisperMessengerDB = nil
  _G.WhisperMessengerCharacterDB = nil
  _G.WhisperMessengerAPI = nil
  rawset(_G, "CreateFrame", function(frameType, name, parent)
    local frame = factory.CreateFrame(frameType, name, parent)
    table.insert(createdFrames, frame)
    return frame
  end)

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

  local api = _G.WhisperMessengerAPI
  local version = api and api.version
  local missing = {}
  for _, name in ipairs({
    "OpenConversation",
    "ShowPreview",
    "HidePreview",
    "IsPreviewShown",
    "RegisterPanel",
    "ShowPanel",
    "TogglePanel",
    "IsPanelShown",
    "RefreshPanelBadge",
    "SetContactInfo",
    "IsBlocked",
    "Block",
    "Unblock",
    "GetUnreadCount",
  }) do
    if not (api and type(api[name]) == "function") then
      missing[#missing + 1] = name
    end
  end

  _G.require = savedRequire
  rawset(_G, "CreateFrame", savedCreateFrame)
  _G.WhisperMessengerDB = savedDB
  _G.WhisperMessengerCharacterDB = savedCharacterDB
  _G.WhisperMessengerAPI = savedApi

  assert(version == 1, "expected WhisperMessengerAPI.version == 1")
  assert(#missing == 0, "expected WhisperMessengerAPI functions: " .. table.concat(missing, ", "))
end
