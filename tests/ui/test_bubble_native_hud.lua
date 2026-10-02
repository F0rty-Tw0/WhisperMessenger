local FakeUI = require("tests.helpers.fake_ui")
local TemplateFactory = require("tests.helpers.template_factory")
local Hud = require("WhisperMessenger.UI.Theme.Hud")
local Theme = require("WhisperMessenger.UI.Theme")
local BubbleColors = require("WhisperMessenger.UI.Theme.BubbleColors")
local BubbleFrame = require("WhisperMessenger.UI.ChatBubble.BubbleFrame")
local FramePool = require("WhisperMessenger.UI.ChatBubble.FramePool")

-- Under the Native WoW HUD a chat bubble sits on Blizzard's tooltip border,
-- filled with the same theme colour the modern rounded bubble uses.

local TOOLTIP_BACKGROUND = "Interface\\Tooltips\\UI-Tooltip-Background"
local TOOLTIP_BORDER = "Interface\\Tooltips\\UI-Tooltip-Border"
local UNSENT_ALPHA = 0.55

local function scaled(color, alphaScale)
  return { color[1], color[2], color[3], (color[4] or 1) * (alphaScale or 1) }
end

local function sameColor(a, b)
  return a ~= nil and a[1] == b[1] and a[2] == b[2] and a[3] == b[3] and a[4] == b[4]
end

local function textInset(bubble)
  local point = bubble.text.point
  return point[4], -point[5]
end

return function()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", nil, nil)
  parent:SetSize(400, 600)
  local noTooltipTemplate = TemplateFactory.missing(factory, "TooltipBackdropTemplate")

  local function bubble(message, bubbleFactory)
    return BubbleFrame.CreateBubble(bubbleFactory or factory, parent, message)
  end

  local modernUser = bubble({ text = "hi", kind = "user", direction = "in" })
  local modernSystem = bubble({ text = "joined", kind = "system" })

  Hud.Configure("classic")

  -- test_hud_bubble_has_tooltip_backdrop_frame
  do
    local backdrop = bubble({ text = "hi", kind = "user", direction = "in" }).frame._nativeBackdrop
    assert(backdrop ~= nil, "HUD bubble has a backdrop frame")
    assert(backdrop.template == "TooltipBackdropTemplate", "backdrop template, got " .. tostring(backdrop.template))
  end

  -- test_hud_bubble_falls_back_to_tooltip_backdrop
  do
    local backdrop = bubble({ text = "hi", kind = "user", direction = "in" }, noTooltipTemplate).frame._nativeBackdrop
    assert(backdrop.template == "BackdropTemplate", "fallback template, got " .. tostring(backdrop.template))
    assert(backdrop.backdrop.bgFile == TOOLTIP_BACKGROUND, "fallback background art")
    assert(backdrop.backdrop.edgeFile == TOOLTIP_BORDER, "fallback border art")
    assert(backdrop.backdropBorderColor ~= nil, "fallback border colour set")
  end

  -- test_hud_bubble_creates_no_rounded_background
  do
    local result = bubble({ text = "hi", kind = "user", direction = "in" })
    assert(#result.bgFills == 0 and #result.bgCorners == 0, "HUD bubble has no rounded fill")
  end

  -- test_hud_backdrop_sits_below_the_bubble
  do
    local frame = bubble({ text = "hi", kind = "user", direction = "in" }).frame
    local backdrop = frame._nativeBackdrop
    assert(backdrop.parent == frame, "backdrop hides with its bubble")
    assert(backdrop.allPoints == frame, "backdrop covers the bubble")
    assert(backdrop:GetFrameLevel() < frame:GetFrameLevel(), "backdrop draws below the bubble's text")
  end

  -- test_hud_fill_matches_the_modern_colour_for_every_kind
  do
    local cases = {
      { { text = "a", kind = "user", direction = "in" }, scaled(Theme.COLORS.bg_bubble_in) },
      { { text = "a", kind = "user", direction = "out" }, scaled(Theme.COLORS.bg_bubble_out) },
      { { text = "a", kind = "system" }, scaled(Theme.COLORS.bg_bubble_system) },
      { { text = "a", kind = "user", direction = "in", mention = true }, scaled(BubbleColors.MentionColor()) },
      { { text = "a", kind = "user", direction = "out", delivery = "queued" }, scaled(Theme.COLORS.bg_bubble_out, UNSENT_ALPHA) },
      { { text = "a", kind = "channel_context", direction = "in" }, scaled(Theme.COLORS.bg_bubble_in, UNSENT_ALPHA) },
    }
    for index, case in ipairs(cases) do
      local backdrop = bubble(case[1]).frame._nativeBackdrop
      assert(sameColor(backdrop.backdropColor, case[2]), "fill colour for case " .. index)
    end
  end

  -- test_hud_border_is_the_fill_lightened_not_stock_white
  -- In game the stock near-white tooltip edge glared around every bubble.
  do
    local fill = scaled(Theme.COLORS.bg_bubble_out)
    local border = bubble({ text = "a", kind = "user", direction = "out" }).frame._nativeBackdrop.backdropBorderColor
    assert(border, "HUD bubble sets its own border colour")
    for channel = 1, 3 do
      local expected = fill[channel] + (1 - fill[channel]) * 0.35
      assert(math.abs(border[channel] - expected) < 1e-6, "border channel " .. channel .. " is the fill lightened, got " .. border[channel])
    end
    assert(border[4] == fill[4], "border fades with the fill (unsent bubbles dim both)")
  end

  -- test_hud_rerender_after_preset_change_repaints_the_fill
  do
    local previousPreset = Theme.GetPreset()
    local content = factory.CreateFrame("Frame", nil, parent)
    FramePool.initPool(content)
    local pooled = FramePool.getFactory(factory, content)
    local message = { text = "hi", kind = "user", direction = "in" }
    local options = { persistentFactory = factory }
    local first = BubbleFrame.CreateBubble(pooled, content, message, options).frame
    FramePool.releaseAll(content)
    assert(not first._nativeBackdrop:IsShown(), "released bubble hides its backdrop")

    Theme.SetPreset("elvui_dark")
    local again = BubbleFrame.CreateBubble(pooled, content, message, options).frame
    assert(again == first, "pooled bubble reused")
    assert(again._nativeBackdrop:IsShown(), "reused bubble shows its backdrop again")
    assert(sameColor(again._nativeBackdrop.backdropColor, scaled(Theme.COLORS.bg_bubble_in)), "fill follows the new preset")
    Theme.SetPreset(previousPreset)

    -- test_hud_rerender_keeps_backdrop_below_a_relevelled_bubble
    FramePool.releaseAll(content)
    first:SetFrameLevel(7)
    BubbleFrame.CreateBubble(pooled, content, message, options)
    assert(first._nativeBackdrop:GetFrameLevel() == 6, "backdrop follows the bubble's new level")
  end

  -- test_hud_text_inset_clears_the_tooltip_border
  do
    local userX, userY = textInset(bubble({ text = "hi", kind = "user", direction = "in" }))
    local systemX, systemY = textInset(bubble({ text = "joined", kind = "system" }))
    local modernUserX, modernUserY = textInset(modernUser)
    local modernSystemX, modernSystemY = textInset(modernSystem)
    assert(userX > modernUserX and userY > modernUserY, "HUD user bubble text sits further in")
    assert(systemX > modernSystemX and systemY > modernSystemY, "HUD system bubble text sits further in")
  end

  Hud.Configure("off")

  -- test_modern_bubble_has_no_backdrop_frame
  do
    assert(modernUser.frame._nativeBackdrop == nil, "modern bubble has no backdrop frame")
    assert(#modernUser.bgFills == 5 and #modernUser.bgCorners == 4, "modern bubble keeps its rounded fill")
  end
end
