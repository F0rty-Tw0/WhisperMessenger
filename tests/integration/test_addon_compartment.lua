local Bootstrap = require("WhisperMessenger.Bootstrap")
local FakeUI = require("tests.helpers.fake_ui")

-- The Retail addon compartment entry through the real runtime: it registers
-- at startup in every icon mode, its text follows the unread number, and a
-- click opens the messenger like the minimap icon does.
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

local function fakeCompartment()
  local frame = { entries = {} }
  function frame:RegisterAddon(data)
    self.entries[#self.entries + 1] = data
  end
  return frame
end

local function boot(iconMode, unread)
  local factory = FakeUI.NewFactory()
  _G.UIParent = factory.CreateFrame("Frame", "UIParent", nil)
  return Bootstrap.Initialize(factory, {
    accountState = {
      schemaVersion = 1,
      settings = { iconMode = iconMode },
      conversations = { ["me::WOW::jaina-proudmoore"] = conversation("Jaina-Proudmoore", unread) },
      contacts = {},
      pendingHydration = {},
    },
    characterState = {
      window = { x = 0, y = 0, width = 900, height = 560, minimized = false },
      icon = { anchorPoint = "CENTER", relativePoint = "CENTER", x = 0, y = 0 },
    },
    localProfileId = "me",
  })
end

return function()
  local saved = {
    UIParent = _G.UIParent,
    SlashCmdList = _G.SlashCmdList,
    AddonCompartmentFrame = rawget(_G, "AddonCompartmentFrame"),
  }
  _G.SlashCmdList = {}

  -- test_entry_registers_with_the_stored_unread_count
  local compartment = fakeCompartment()
  rawset(_G, "AddonCompartmentFrame", compartment)
  local runtime = boot("minimap", 2)
  assert(#compartment.entries == 1, "one entry, got " .. #compartment.entries)
  local entry = compartment.entries[1]
  assert(entry.text == "Whisper Messenger (2)", "startup count, got " .. tostring(entry.text))

  -- test_entry_text_follows_a_refresh
  local _, stored = next(runtime.store.conversations)
  stored.unreadCount = 5
  runtime.refreshWindow()
  assert(entry.text == "Whisper Messenger (5)", "refreshed count, got " .. tostring(entry.text))

  -- test_entry_click_opens_the_window
  entry.func(entry, { buttonName = "LeftButton" }, {})
  assert(runtime.window ~= nil and runtime.window.frame:IsShown(), "click opens the messenger")

  -- test_entry_registers_with_no_icon_shown
  local bare = fakeCompartment()
  rawset(_G, "AddonCompartmentFrame", bare)
  boot("none", 0)
  assert(#bare.entries == 1, "registered with icon mode none")
  assert(bare.entries[1].text == "Whisper Messenger", "no count with nothing unread, got " .. tostring(bare.entries[1].text))

  -- test_no_compartment_boots_cleanly
  rawset(_G, "AddonCompartmentFrame", nil)
  assert(boot("minimap", 1) ~= nil, "boots without a compartment")

  rawset(_G, "AddonCompartmentFrame", saved.AddonCompartmentFrame)
  _G.UIParent = saved.UIParent
  _G.SlashCmdList = saved.SlashCmdList
end
