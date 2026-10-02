-- DisabledState: a target can be shown unavailable — dimmed, covered so it
-- catches no clicks, and explaining why on hover.
local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local DisabledState = require("WhisperMessenger.UI.Helpers.DisabledState")

local REASON = "Not used right now."

local function withTooltip(fn)
  local saved = rawget(_G, "GameTooltip")
  local tip = { shown = false }
  rawset(_G, "GameTooltip", {
    SetOwner = function() end,
    SetText = function(_self, text)
      tip.text = text
    end,
    Show = function()
      tip.shown = true
    end,
    Hide = function()
      tip.shown = false
    end,
  })
  local ok, err = pcall(fn, tip)
  rawset(_G, "GameTooltip", saved)
  if not ok then
    error(err, 0)
  end
end

local function build()
  local factory = FakeUI.NewFactory()
  local target = factory.CreateFrame("Button", nil, factory.CreateFrame("Frame", "UIParent", nil))
  return target, DisabledState.Attach(factory, target)
end

return function()
  -- test_enabled_by_default
  do
    local target, state = build()
    assert(state.isEnabled() == true, "starts enabled")
    assert(FindUI.disabledCover(target) == nil, "no cover while enabled")
  end

  -- test_disabled_target_is_dimmed_and_covered
  do
    local target, state = build()
    state.set(false, REASON)
    assert(state.isEnabled() == false, "reports disabled")
    assert(target:GetAlpha() == DisabledState.ALPHA, "dimmed, got " .. tostring(target:GetAlpha()))
    assert(FindUI.disabledCover(target), "a cover catches the mouse")
  end

  -- test_disabled_target_explains_on_hover
  withTooltip(function(tip)
    local target, state = build()
    state.set(false, REASON)
    local cover = assert(FindUI.disabledCover(target))
    cover:GetScript("OnEnter")(cover)
    assert(tip.shown and tip.text == REASON, "hover shows the reason, got " .. tostring(tip.text))
    cover:GetScript("OnLeave")(cover)
    assert(tip.shown == false, "leaving hides the tooltip")
  end)

  -- test_reenabled_target_is_restored
  do
    local target, state = build()
    state.set(false, REASON)
    state.set(true)
    assert(target:GetAlpha() == 1, "full alpha again")
    assert(FindUI.disabledCover(target) == nil, "cover removed")
  end
end
