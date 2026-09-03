-- Patch-notes glow tracks the seen version and clears when the page opens.
local FakeUI = require("tests.helpers.fake_ui")
local PatchNotesRuntime = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.PatchNotesRuntime")
local SettingsPanels = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.SettingsPanels")
local MessengerWindow = require("WhisperMessenger.UI.MessengerWindow")

local NOTES = {
  version = "v9.9.9",
  date = "2026-01-02",
  lines = { "Something new happened." },
}

local function makeAnimationGroup()
  local ag = { playing = false, scripts = {} }
  function ag:SetLooping(mode)
    self.looping = mode
  end
  function ag:SetScript(event, handler)
    self.scripts[event] = handler
  end
  function ag:Play()
    self.playing = true
    if self.scripts.OnPlay then
      self.scripts.OnPlay(self)
    end
  end
  function ag:Stop()
    self.playing = false
    if self.scripts.OnStop then
      self.scripts.OnStop(self)
    end
  end
  function ag:CreateAnimation(_kind)
    local anim = {}
    function anim:SetFromAlpha(_) end
    function anim:SetToAlpha(_) end
    function anim:SetDuration(_) end
    function anim:SetOrder(_) end
    function anim:SetScaleFrom(_, _) end
    function anim:SetScaleTo(_, _) end
    return anim
  end
  return ag
end

local function newAnimatedFactory()
  local raw = FakeUI.NewFactory()
  local function CreateFrame(...)
    local frame = raw.CreateFrame(...)
    if type(frame) == "table" and frame.frameType == "Frame" then
      function frame:CreateAnimationGroup()
        return makeAnimationGroup()
      end
    end
    return frame
  end
  return { CreateFrame = CreateFrame }
end

-- WoW runs the SetScript handler and every HookScript hook on a click.
local function fireClick(widget)
  local handler = widget:GetScript("OnClick")
  if handler then
    handler(widget)
  end
  for _, hook in ipairs(widget._hookScripts and widget._hookScripts.OnClick or {}) do
    hook(widget)
  end
end

local function newHarness(settingsConfig)
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  local frame = factory.CreateFrame("Frame", "WhisperMessengerWindow", parent)
  local button = factory.CreateFrame("Button", nil, frame)
  local tab = factory.CreateFrame("Button", nil, frame)

  local calls = { glow = {}, opened = 0 }
  local runtime = PatchNotesRuntime.Wire({
    button = button,
    tab = tab,
    setGlowing = function(glowing)
      calls.glow[#calls.glow + 1] = glowing
    end,
    settingsConfig = settingsConfig,
    patchNotes = NOTES,
    openPage = function()
      calls.opened = calls.opened + 1
    end,
  })

  return { button = button, tab = tab, frame = frame, factory = factory, calls = calls, runtime = runtime }
end

return function()
  -- A fresh install has no stored version, so the button glows immediately.

  do
    local settingsConfig = {}
    local harness = newHarness(settingsConfig)
    assert(#harness.calls.glow == 1, "expected one initial glow call, got " .. #harness.calls.glow)
    assert(harness.calls.glow[1] == true, "expected the button to glow when no version has been seen")
    assert(harness.runtime.isUnseen() == true, "expected isUnseen to be true on a fresh install")
  end

  -- Clicking opens the page once, records the version, and stops the glow.

  do
    local settingsConfig = {}
    local harness = newHarness(settingsConfig)
    local onClick = harness.button:GetScript("OnClick")
    assert(type(onClick) == "function", "expected an OnClick handler on the patch notes button")

    onClick(harness.button)

    assert(harness.calls.opened == 1, "expected the page to be opened once, got " .. harness.calls.opened)
    assert(settingsConfig.patchNotesSeenVersion == NOTES.version, "expected the seen version to be persisted")
    assert(harness.calls.glow[#harness.calls.glow] == false, "expected the glow to stop after opening the page")
    assert(harness.runtime.isUnseen() == false, "expected isUnseen to be false once the version was seen")
  end

  -- Opening the page from the sidebar tab clears the glow too.

  do
    local settingsConfig = {}
    local harness = newHarness(settingsConfig)
    local hooks = harness.tab._hookScripts and harness.tab._hookScripts.OnClick
    assert(hooks ~= nil and #hooks == 1, "expected the sidebar tab's OnClick to be hooked")

    fireClick(harness.tab)

    assert(harness.calls.opened == 0, "expected the sidebar tab not to re-open the page")
    assert(settingsConfig.patchNotesSeenVersion == NOTES.version, "expected the sidebar tab to record the seen version")
    assert(harness.calls.glow[#harness.calls.glow] == false, "expected the sidebar tab to stop the glow")
  end

  -- A stored version matching the shipped notes means no glow at all.

  do
    local settingsConfig = { patchNotesSeenVersion = NOTES.version }
    local harness = newHarness(settingsConfig)
    assert(harness.calls.glow[1] == false, "expected no glow when the shipped version was already seen")
  end

  -- End to end: a fresh window glows its patch-notes button.

  do
    local factory = newAnimatedFactory()
    local window = MessengerWindow.Create(factory, { settingsConfig = {} })
    assert(window.patchNotesButton ~= nil, "expected the window to expose its patch notes button")

    local glowFrame = nil
    for _, child in ipairs(window.patchNotesButton.children or {}) do
      if child.frameType == "Frame" then
        glowFrame = child
      end
    end
    assert(glowFrame ~= nil, "expected a glow frame on the patch notes button")
    assert(glowFrame:IsShown() == true, "expected a fresh install to glow the patch notes button")
  end

  -- End to end: clicking "?" opens options on the What's New page.

  do
    local factory = newAnimatedFactory()
    local settingsConfig = {}
    local window = MessengerWindow.Create(factory, { settingsConfig = settingsConfig })
    assert(window.whatsNewTab ~= nil, "expected the window to expose a What's New sidebar tab")

    local onClick = window.patchNotesButton:GetScript("OnClick")
    assert(type(onClick) == "function", "expected an OnClick handler on the patch notes button")
    onClick(window.patchNotesButton)

    assert(window.optionsPanel:IsShown() == true, "expected the '?' button to open the options panel")
    local index = SettingsPanels.PATCH_NOTES_INDEX
    local page = window.settingsPanels[index]
    assert(page ~= nil, "expected the What's New page to be created at index " .. index)
    assert(page:IsShown() == true, "expected the What's New page to be the selected options page")
    assert(settingsConfig.patchNotesSeenVersion ~= nil, "expected opening the page to record the seen version")
  end
end
