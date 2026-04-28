local FakeUI = require("tests.helpers.fake_ui")

local function loadAddonFromToc(addonName, ns)
  for line in io.lines("WhisperMessenger.toc") do
    local trimmed = line:match("^%s*(.-)%s*$")
    if trimmed ~= "" and trimmed:sub(1, 2) ~= "##" and not trimmed:match("%.xml$") then
      local chunk = assert(loadfile(trimmed))
      chunk(addonName, ns)
    end
  end
end

return function()
  local factory = FakeUI.NewFactory()
  local accountState = { conversations = {}, contacts = {}, pendingHydration = {}, schemaVersion = 1 }
  local characterState = {
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

  local ns = {}
  loadAddonFromToc("WhisperMessenger", ns)
  local Bootstrap = ns.Bootstrap

  -- 1. Binding name is set at file-load time (before Initialize)
  assert(_G.BINDING_NAME_WHISPERMESSENGER_TOGGLE == "Toggle Window", "expected BINDING_NAME_WHISPERMESSENGER_TOGGLE to be 'Toggle Window'")

  -- 2. Global toggle function exists at file-load time (before Initialize)
  assert(type(_G.WhisperMessenger_Toggle) == "function", "expected global WhisperMessenger_Toggle function")

  _G.UISpecialFrames = {}
  local runtime = Bootstrap.Initialize(factory, {
    accountState = accountState,
    characterState = characterState,
    localProfileId = "current",
  })
  -- Mimic initializeRuntime() so the keybind can find the toggle
  Bootstrap.runtime = runtime

  -- 3. Calling the global toggle opens the window
  _G.WhisperMessenger_Toggle()
  assert(runtime.window.frame.shown == true, "expected window to be visible after keybind toggle")

  -- 4. Calling it again closes the window
  _G.WhisperMessenger_Toggle()
  assert(runtime.window.frame.shown == false, "expected window to be hidden after second keybind toggle")
end
