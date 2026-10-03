local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local Hud = require("WhisperMessenger.UI.Theme.Hud")
local ScrollView = require("WhisperMessenger.UI.ScrollView")

local KNOB = "Interface\\Buttons\\UI-ScrollBar-Knob"
local VIEW_WIDTH = 200
local VIEW_HEIGHT = 100

local RIGHT_GUTTER = 16

local function newView(style, rightGutter)
  Hud.Configure(style)
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", nil, nil)
  parent:SetSize(VIEW_WIDTH, VIEW_HEIGHT)
  local view = ScrollView.Create(factory, parent, { width = VIEW_WIDTH, height = VIEW_HEIGHT, step = 10, rightGutter = rightGutter })
  Hud.Configure("off")
  return view
end

local function hover(scrollBar, event)
  local script = scrollBar:GetScript(event)
  if script then
    script(scrollBar)
  end
end

local function hudWidth()
  local width = Theme.LAYOUT.SCROLLBAR_WIDTH_HUD
  assert(type(width) == "number" and width > Theme.LAYOUT.SCROLLBAR_WIDTH, "HUD scrollbar is wider than the modern bar, got " .. tostring(width))
  return width
end

return function()
  -- test_hud_thumb_uses_the_blizzard_scroll_knob
  do
    local view = newView("classic")
    local thumb = view.scrollBar.thumb
    assert(view.scrollBar.thumbTexture == thumb, "HUD: thumb is the slider's thumb texture")
    assert(thumb.texturePath == KNOB, "HUD: thumb uses the scroll knob art, got " .. tostring(thumb.texturePath))
    assert(thumb.color == nil, "HUD: thumb is not a flat colour")
    assert(thumb.blendMode ~= "ADD", "HUD: knob is opaque art, not additive")
  end

  -- test_hud_theme_refresh_keeps_the_knob
  do
    local view = newView("classic")
    view.refreshSkin()
    assert(view.scrollBar.thumb.color == nil, "HUD: refresh does not repaint the knob flat")
    assert(view.scrollBar.thumb.texturePath == KNOB, "HUD: refresh keeps the knob art")
  end

  -- test_hud_knob_has_no_trough_behind_it
  do
    local view = newView("classic")
    view.refreshSkin()
    local color = view.scrollBar.track.color
    assert(color == nil or color[4] == 0, "HUD: no trough behind the knob")
  end

  -- test_hud_knob_is_slim_and_keeps_its_proportions
  do
    -- Blizzard's knob is 18x24; ours is scaled down whole so it never squashes.
    local view = newView("classic")
    local thumb = view.scrollBar.thumb
    assert(thumb.width <= 12, "HUD: knob at most 12px wide, got " .. tostring(thumb.width))
    assert(
      thumb.width * 24 == thumb.height * 18,
      "HUD: knob keeps the 18:24 art ratio, got " .. tostring(thumb.width) .. "x" .. tostring(thumb.height)
    )
  end

  -- test_hud_thumb_does_not_widen_on_hover
  do
    local view = newView("classic")
    local thumb = view.scrollBar.thumb
    local width = thumb.width
    hover(view.scrollBar, "OnEnter")
    assert(thumb.width == width, "HUD: hover keeps the knob width, got " .. tostring(thumb.width))
    assert(thumb.color == nil, "HUD: hover does not tint the knob flat")
    hover(view.scrollBar, "OnLeave")
    assert(thumb.width == width, "HUD: leave keeps the knob width")
  end

  -- test_hud_scrollbar_uses_the_wide_width
  do
    local view = newView("classic")
    assert(view.scrollBar.width == hudWidth(), "HUD: scrollbar is the HUD width, got " .. tostring(view.scrollBar.width))
  end

  -- test_hud_overflow_reserves_the_wide_gutter
  do
    local view = newView("classic")
    ScrollView.RefreshMetrics(view, 500)
    local expected = VIEW_WIDTH - hudWidth()
    assert(view.scrollFrame.width == expected, "HUD: viewport leaves room for the knob, got " .. tostring(view.scrollFrame.width))
    assert(view.content.width == expected, "HUD: content reflows to the viewport, got " .. tostring(view.content.width))
    assert(view.scrollBar.width == hudWidth(), "HUD: relayout keeps the HUD width")
  end

  -- test_hud_bar_spends_the_right_gutter_to_sit_flush
  do
    local view = newView("classic", RIGHT_GUTTER)
    ScrollView.RefreshMetrics(view, 500)
    local expected = VIEW_WIDTH - math.max(0, hudWidth() - RIGHT_GUTTER)
    assert(view.scrollFrame.width == expected, "HUD: viewport only gives up what the gutter can't hold, got " .. tostring(view.scrollFrame.width))
    assert(view.scrollFrame.width + view.scrollBar.width <= VIEW_WIDTH + RIGHT_GUTTER, "HUD: knob stays inside the gutter")
  end

  -- test_modern_bar_ignores_the_right_gutter
  do
    local view = newView("off", RIGHT_GUTTER)
    ScrollView.RefreshMetrics(view, 500)
    assert(
      view.scrollFrame.width == VIEW_WIDTH - Theme.LAYOUT.SCROLLBAR_WIDTH,
      "modern: thin bar stays inside the view, got " .. tostring(view.scrollFrame.width)
    )
  end

  -- test_hud_scrollbar_still_scrolls
  do
    local view = newView("classic")
    ScrollView.RefreshMetrics(view, 500)
    ScrollView.SetVerticalScroll(view, 50)
    assert(view.scrollBar.value == 50, "HUD: slider follows the scroll offset, got " .. tostring(view.scrollBar.value))
    ScrollView.ScrollBy(view, 10)
    assert(view.scrollBar.value == 60, "HUD: scroll by moves the slider, got " .. tostring(view.scrollBar.value))
    assert(view.scrollBar.shown ~= false, "HUD: slider shows on overflow")
  end

  -- test_hud_dragging_the_knob_scrolls_the_view
  do
    local view = newView("classic")
    ScrollView.RefreshMetrics(view, 500)
    view.scrollBar:SetValue(30)
    assert(ScrollView.GetOffset(view) == 30, "HUD: knob drag scrolls the view, got " .. tostring(ScrollView.GetOffset(view)))
  end

  -- test_modern_thumb_keeps_the_flat_bar
  do
    local view = newView("off")
    ScrollView.RefreshMetrics(view, 500)
    assert(view.scrollBar.thumb.texturePath == nil, "modern: thumb has no art")
    assert(view.scrollBar.thumb.color ~= nil, "modern: thumb is a flat colour")
    assert(view.scrollBar.width == Theme.LAYOUT.SCROLLBAR_WIDTH, "modern: scrollbar keeps the thin width")
    assert(view.scrollFrame.width == VIEW_WIDTH - Theme.LAYOUT.SCROLLBAR_WIDTH, "modern: viewport keeps the thin gutter")
  end
end
