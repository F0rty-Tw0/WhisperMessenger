-- Patch-notes "?" button lives in the title bar of both chrome paths.
local FakeUI = require("tests.helpers.fake_ui")
local ChromeBuilder = require("WhisperMessenger.UI.MessengerWindow.ChromeBuilder")
local Localization = require("WhisperMessenger.Locale.Localization")

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

local function findGlowFrame(button)
  for _, child in ipairs(button.children or {}) do
    if child.frameType == "Frame" then
      return child
    end
  end
  return nil
end

local function assertTooltipTitle(button, expectedTitle, label)
  local onEnter = button.GetScript and button:GetScript("OnEnter") or nil
  local onLeave = button.GetScript and button:GetScript("OnLeave") or nil
  assert(type(onEnter) == "function", label .. ": expected OnEnter script")
  assert(type(onLeave) == "function", label .. ": expected OnLeave script")

  local originalGameTooltip = _G.GameTooltip
  local tooltipState = { shown = false, hidden = false }
  _G.GameTooltip = {
    SetOwner = function(_, owner)
      tooltipState.owner = owner
    end,
    SetText = function(_, text)
      tooltipState.text = text
    end,
    AddLine = function(_, text)
      tooltipState.line = text
    end,
    Show = function()
      tooltipState.shown = true
    end,
    Hide = function()
      tooltipState.hidden = true
    end,
  }

  local ok, err = pcall(function()
    onEnter(button)
    assert(tooltipState.text == expectedTitle, label .. ": expected tooltip title " .. expectedTitle .. ", got " .. tostring(tooltipState.text))
    assert(tooltipState.shown == true, label .. ": expected tooltip shown on enter")
    assert(tooltipState.line == "See what changed in the latest update.", label .. ": expected tooltip body line")
    onLeave(button)
    assert(tooltipState.hidden == true, label .. ": expected tooltip hidden on leave")
  end)

  _G.GameTooltip = originalGameTooltip
  assert(ok, err)
end

return function()
  Localization.Configure({ language = "enUS" })

  for _, case in ipairs({
    { name = "modern chrome", useNativeChrome = false },
    { name = "native chrome", useNativeChrome = true },
  }) do
    local factory = newAnimatedFactory()
    local parent = factory.CreateFrame("Frame", "UIParent", nil)
    local chrome = ChromeBuilder.Build(factory, parent, { width = 920, height = 580 }, {
      useNativeChrome = case.useNativeChrome,
    })

    local button = chrome.patchNotesButton
    assert(button ~= nil, case.name .. ": expected a patch notes button")

    local point, relativeTo, relativePoint = button:GetPoint()
    assert(point == "LEFT", case.name .. ": expected LEFT anchor, got " .. tostring(point))
    assert(relativeTo == chrome.newConversationButton, case.name .. ": expected anchoring to the New Whisper button")
    assert(relativePoint == "RIGHT", case.name .. ": expected RIGHT relative point, got " .. tostring(relativePoint))

    assertTooltipTitle(button, "What's New", case.name .. " patch notes button")

    assert(type(chrome.setPatchNotesGlow) == "function", case.name .. ": expected setPatchNotesGlow")
    local glowFrame = findGlowFrame(button)
    assert(glowFrame ~= nil, case.name .. ": expected a glow frame parented to the button")

    chrome.setPatchNotesGlow(true)
    assert(glowFrame:IsShown() == true, case.name .. ": expected glow shown after setPatchNotesGlow(true)")

    chrome.setPatchNotesGlow(false)
    assert(glowFrame:IsShown() == false, case.name .. ": expected glow hidden after setPatchNotesGlow(false)")
  end
end
