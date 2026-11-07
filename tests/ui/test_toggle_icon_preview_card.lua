-- The preview card builds its widgets next to the icon frame, hidden.
local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local PreviewMetrics = require("WhisperMessenger.UI.ToggleIcon.PreviewMetrics")
local PreviewCard = require("WhisperMessenger.UI.ToggleIcon.PreviewCard")

-- WoW shows a frame as soon as it is created; the fake factory does not.
local function shownFactory()
  local factory = FakeUI.NewFactory()
  local create = factory.CreateFrame
  factory.CreateFrame = function(...)
    local frame = create(...)
    frame:Show()
    return frame
  end
  return factory
end

local function build(getPreviewPosition)
  local factory = shownFactory()
  local icon = factory.CreateFrame("Button", nil, nil)
  icon:SetFrameLevel(7)
  return PreviewCard.Create(factory, icon, Theme, getPreviewPosition), icon
end

return function()
  -- test_card_starts_hidden
  do
    local card = build()
    assert(card.frame:IsShown() == false, "card hidden until a whisper arrives")
  end

  -- test_class_icon_starts_hidden
  do
    local card = build()
    assert(card.classIconFrame:IsShown() == false, "class icon hidden until a sender is known")
  end

  -- test_card_sits_one_level_above_the_icon_in_high_strata
  do
    local card, icon = build()
    assert(card.frame:GetFrameLevel() == icon:GetFrameLevel() + 1, "card one level above the icon")
    assert(card.frame:GetFrameStrata() == "HIGH", "card in HIGH strata")
    assert(card.frame.fixedFrameStrata == true, "strata pinned")
  end

  -- test_card_has_the_preview_size
  do
    local width, height = build().frame:GetSize()
    assert(width == PreviewMetrics.MAX_WIDTH and height == PreviewMetrics.HEIGHT, "card sized to the preview metrics")
  end

  -- test_card_anchors_on_the_side_the_settings_choose
  do
    local card, icon = build(function()
      return "left"
    end)
    local anchor = PreviewMetrics.ResolveAnchor("left")
    local point, relativeTo, relativePoint = card.frame:GetPoint()
    assert(point == anchor.selfPoint and relativeTo == icon and relativePoint == anchor.target, "card anchored to the icon's left")
  end
end
