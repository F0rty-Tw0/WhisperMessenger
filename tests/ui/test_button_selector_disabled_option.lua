-- A single ButtonSelector option can be unavailable: dimmed, unclickable,
-- and explaining why on hover, while the other options keep working.
local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local ButtonSelector = require("WhisperMessenger.UI.MessengerWindow.AppearanceSettings.ButtonSelector")

local function options(reason)
  return {
    { key = "on", label = "On", tooltip = "On tip" },
    { key = "new", label = "New", tooltip = "New tip", disabled = true, disabledReason = reason },
  }
end

local function build()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  local changes = {}
  local selector = ButtonSelector.Create(factory, parent, {
    labelText = "Mode",
    optionsList = options("Not here."),
    fallbackKey = "on",
    initial = "on",
    onChange = function(key)
      changes[#changes + 1] = key
    end,
  })
  return selector, changes
end

local function withTooltip(fn)
  local saved = rawget(_G, "GameTooltip")
  local tip = {}
  rawset(_G, "GameTooltip", {
    SetOwner = function() end,
    SetText = function(_self, text)
      tip.text = text
    end,
    Show = function() end,
    Hide = function() end,
  })
  local ok, err = pcall(fn, tip)
  rawset(_G, "GameTooltip", saved)
  if not ok then
    error(err, 0)
  end
end

return function()
  -- test_disabled_option_is_dimmed
  do
    local selector = build()
    assert(selector.buttons[2]:GetAlpha() == 0.4, "unavailable option is dimmed")
    assert(selector.buttons[1]:GetAlpha() == 1, "available option is not dimmed")
  end

  -- test_disabled_option_ignores_clicks
  do
    local selector, changes = build()
    FindUI.click(selector.buttons[2])
    assert(#changes == 0, "clicking an unavailable option fires nothing")
    assert(selector.buttons[2]._selected ~= true, "unavailable option is not selected")
    FindUI.click(selector.buttons[1])
    assert(changes[1] == "on", "other options still work")
  end

  -- test_disabled_option_explains_on_hover
  withTooltip(function(tip)
    local selector = build()
    local cover = FindUI.disabledCover(selector.buttons[2])
    assert(cover, "unavailable option has a hover cover")
    cover:GetScript("OnEnter")(cover)
    assert(tip.text == "Not here.", "hover shows the reason, got " .. tostring(tip.text))
  end)

  -- test_relabel_updates_the_reason
  withTooltip(function(tip)
    local selector = build()
    selector.setOptionsList(options("Nicht hier."))
    local cover = assert(FindUI.disabledCover(selector.buttons[2]), "unavailable option keeps its cover")
    cover:GetScript("OnEnter")(cover)
    assert(tip.text == "Nicht hier.", "relabelled reason shows, got " .. tostring(tip.text))
  end)
end
