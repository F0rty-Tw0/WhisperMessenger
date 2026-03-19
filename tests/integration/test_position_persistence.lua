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
  local factory = FakeUI.NewFactory()
  local accountState = { conversations = {}, contacts = {}, pendingHydration = {}, schemaVersion = 1 }
  local characterState = {
    window = {
      anchorPoint = "TOPLEFT",
      relativePoint = "TOPLEFT",
      x = 111,
      y = -222,
      width = 900,
      height = 560,
      minimized = false,
    },
    icon = {
      anchorPoint = "BOTTOMRIGHT",
      relativePoint = "BOTTOMRIGHT",
      x = -20,
      y = 40,
    },
  }

  local ns = {}
  loadAddonFromToc("WhisperMessenger", ns)
  local Bootstrap = ns.Bootstrap

  local runtime = Bootstrap.Initialize(factory, {
    accountState = accountState,
    characterState = characterState,
    localProfileId = "current",
  })

  local windowPoint, _, windowRelative, windowX, windowY = runtime.window.frame:GetPoint()
  assert(windowPoint == "TOPLEFT")
  assert(windowRelative == "TOPLEFT")
  assert(windowX == 111)
  assert(windowY == -222)

  local iconPoint, _, iconRelative, iconX, iconY = runtime.icon.frame:GetPoint()
  assert(iconPoint == "BOTTOMRIGHT")
  assert(iconRelative == "BOTTOMRIGHT")
  assert(iconX == -20)
  assert(iconY == 40)

  runtime.window.frame:SetPoint("BOTTOMLEFT", nil, "BOTTOMLEFT", 55, 66)
  runtime.window.frame.scripts.OnDragStop(runtime.window.frame)
  assert(characterState.window.anchorPoint == "BOTTOMLEFT")
  assert(characterState.window.relativePoint == "BOTTOMLEFT")
  assert(characterState.window.x == 55)
  assert(characterState.window.y == 66)

  runtime.icon.frame:SetPoint("TOPRIGHT", nil, "TOPRIGHT", -12, -18)
  runtime.icon.frame.scripts.OnDragStop(runtime.icon.frame)
  assert(characterState.icon.anchorPoint == "TOPRIGHT")
  assert(characterState.icon.relativePoint == "TOPRIGHT")
  assert(characterState.icon.x == -12)
  assert(characterState.icon.y == -18)

  local reloaded = Bootstrap.Initialize(factory, {
    accountState = accountState,
    characterState = characterState,
    localProfileId = "current",
  })

  local reloadedWindowPoint, _, reloadedWindowRelative, reloadedWindowX, reloadedWindowY = reloaded.window.frame:GetPoint()
  assert(reloadedWindowPoint == "BOTTOMLEFT")
  assert(reloadedWindowRelative == "BOTTOMLEFT")
  assert(reloadedWindowX == 55)
  assert(reloadedWindowY == 66)
end
