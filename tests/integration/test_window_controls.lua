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
  local savedUISpecialFrames = _G.UISpecialFrames
  local factory = FakeUI.NewFactory()
  local accountState = { conversations = {}, contacts = {}, pendingHydration = {}, schemaVersion = 1 }
  local characterState = {
    window = {
      anchorPoint = "CENTER",
      relativePoint = "CENTER",
      x = 0,
      y = 0,
      width = 900,
      height = 560,
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

  _G.UISpecialFrames = {}

  local runtime = Bootstrap.Initialize(factory, {
    accountState = accountState,
    characterState = characterState,
    localProfileId = "current",
  })

  runtime.toggle()
  assert(runtime.window.frame.shown == true)
  assert(_G.UISpecialFrames[1] == "WhisperMessengerWindow")

  assert(runtime.window.closeButton.template == "UIPanelButtonTemplate")
  assert(runtime.window.optionsButton ~= nil, "expected an Options button")
  assert(runtime.window.optionsButton.template == "UIPanelButtonTemplate")
  assert(runtime.window.optionsPanel ~= nil, "expected an Options panel")
  assert(runtime.window.resetWindowButton.template == "UIPanelButtonTemplate")
  assert(runtime.window.resetIconButton.template == "UIPanelButtonTemplate")
  assert(runtime.window.composer.sendButton.template == "UIPanelButtonTemplate")
  assert(runtime.window.optionsPanel.shown == false)

  runtime.window.optionsButton.scripts.OnClick(runtime.window.optionsButton)
  assert(runtime.window.optionsPanel.shown == true)

  runtime.window.optionsButton.scripts.OnClick(runtime.window.optionsButton)
  assert(runtime.window.optionsPanel.shown == false)

  assert(runtime.window.closeButton.scripts.OnClick ~= nil, "expected the Close button to be wired")
  assert(runtime.window.composer.input.scripts.OnEscapePressed ~= nil, "expected composer Esc to be wired")
  runtime.window.composer.input.scripts.OnEscapePressed(runtime.window.composer.input)
  assert(runtime.window.frame.shown == false)

  runtime.icon.frame.scripts.OnClick(runtime.icon.frame)
  assert(runtime.window.frame.shown == true)

  _G.UISpecialFrames = savedUISpecialFrames
end
