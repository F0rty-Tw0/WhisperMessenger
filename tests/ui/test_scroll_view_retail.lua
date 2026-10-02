local FakeUI = require("tests.helpers.fake_ui")
local RetailHud = require("tests.helpers.retail_hud")
local Theme = require("WhisperMessenger.UI.Theme")
local ScrollView = require("WhisperMessenger.UI.ScrollView")

local KNOB = "Interface\\Buttons\\UI-ScrollBar-Knob"
local TRACK_TOP = "minimal-scrollbar-track-top"
local TRACK_MIDDLE = "!minimal-scrollbar-track-middle"
local TRACK_BOTTOM = "minimal-scrollbar-track-bottom"
local THUMB = { top = "minimal-scrollbar-thumb-top", middle = "minimal-scrollbar-thumb-middle", bottom = "minimal-scrollbar-thumb-bottom" }
local VIEW_WIDTH = 200
local VIEW_HEIGHT = 100

local function build(factory)
  local parent = factory.CreateFrame("Frame", nil, nil)
  parent:SetSize(VIEW_WIDTH, VIEW_HEIGHT)
  return ScrollView.Create(factory, parent, { width = VIEW_WIDTH, height = VIEW_HEIGHT, step = 10 })
end

local function newView(factory)
  local view
  RetailHud.With(function()
    view = build(factory or FakeUI.NewFactory())
  end)
  return view
end

local function fire(scrollBar, event)
  local script = scrollBar:GetScript(event)
  assert(script ~= nil, "retail: slider handles " .. event)
  script(scrollBar)
end

local function retailWidth()
  local width = Theme.LAYOUT.SCROLLBAR_WIDTH_RETAIL
  assert(type(width) == "number" and width > Theme.LAYOUT.SCROLLBAR_WIDTH, "retail scrollbar width is set, got " .. tostring(width))
  return width
end

local function assertThumbAtlases(pieces, suffix, label)
  for _, part in ipairs({ "top", "middle", "bottom" }) do
    local expected = THUMB[part] .. suffix
    assert(pieces[part].atlas == expected, label .. ": thumb " .. part .. " is " .. expected .. ", got " .. tostring(pieces[part].atlas))
  end
end

return function()
  -- test_retail_track_is_the_minimal_scrollbar_atlases
  do
    local scrollBar = newView().scrollBar
    local track = scrollBar.retailTrack
    assert(track ~= nil, "retail: track pieces exist")
    assert(track.top.atlas == TRACK_TOP and track.top.useAtlasSize == true, "retail: top cap at atlas size")
    assert(track.bottom.atlas == TRACK_BOTTOM and track.bottom.useAtlasSize == true, "retail: bottom cap at atlas size")
    assert(track.middle.atlas == TRACK_MIDDLE, "retail: middle is the tiling atlas, got " .. tostring(track.middle.atlas))
    assert(scrollBar.track == track.middle, "retail: the slider's track is the middle piece")
    assert(track.middle.points[1][2] == track.top and track.middle.points[2][2] == track.bottom, "retail: middle stretches between the caps")
    assert(track.middle.color == nil, "retail: track is not a flat colour")
  end

  -- test_retail_thumb_is_three_atlas_pieces_on_an_invisible_carrier
  do
    local scrollBar = newView().scrollBar
    local carrier = scrollBar.thumb
    assert(scrollBar.thumbTexture == carrier, "retail: carrier is the slider's thumb texture")
    assert(carrier.alpha == 0, "retail: carrier is invisible, alpha " .. tostring(carrier.alpha))
    assert(carrier.atlas == nil and carrier.texturePath == nil and carrier.color == nil, "retail: carrier has no art")
    assert(carrier.width == retailWidth() and carrier.height > 0, "retail: carrier spans the bar width")
    local pieces = scrollBar.retailThumb
    assertThumbAtlases(pieces, "", "retail")
    assert(pieces.top.points[1][2] == carrier and pieces.bottom.points[1][2] == carrier, "retail: caps ride the carrier")
    assert(pieces.middle.points[1][2] == pieces.top and pieces.middle.points[2][2] == pieces.bottom, "retail: middle sits between the caps")
    assert(pieces.top.blendMode ~= "ADD", "retail: thumb art is not additive")
  end

  -- test_retail_hover_swaps_to_the_over_atlases_and_back
  do
    local scrollBar = newView().scrollBar
    fire(scrollBar, "OnEnter")
    assertThumbAtlases(scrollBar.retailThumb, "-over", "retail hover")
    fire(scrollBar, "OnLeave")
    assertThumbAtlases(scrollBar.retailThumb, "", "retail leave")
    assert(scrollBar.thumb.width == retailWidth(), "retail: hover does not widen the carrier")
  end

  -- test_retail_scrollbar_has_no_arrow_buttons
  do
    local factory = FakeUI.NewFactory()
    local buttons = 0
    local create = factory.CreateFrame
    factory.CreateFrame = function(frameType, ...)
      if frameType == "Button" then
        buttons = buttons + 1
      end
      return create(frameType, ...)
    end
    newView(factory)
    assert(buttons == 0, "retail: no arrow buttons, got " .. buttons)
  end

  -- test_retail_overflow_reserves_the_slim_gutter
  do
    local view = newView()
    assert(view.scrollBar.width == retailWidth(), "retail: scrollbar is the retail width, got " .. tostring(view.scrollBar.width))
    ScrollView.RefreshMetrics(view, 500)
    local expected = VIEW_WIDTH - retailWidth()
    assert(view.scrollFrame.width == expected, "retail: viewport leaves room for the bar, got " .. tostring(view.scrollFrame.width))
    assert(view.content.width == expected, "retail: content reflows to the viewport, got " .. tostring(view.content.width))
    assert(view.scrollBar.width == retailWidth(), "retail: relayout keeps the retail width")
  end

  -- test_retail_width_follows_the_thumb_atlas_when_the_client_reports_it
  do
    local saved = rawget(_G, "C_Texture")
    rawset(_G, "C_Texture", {
      GetAtlasInfo = function(atlas)
        return atlas == THUMB.top and { width = 11, height = 6 } or nil
      end,
    })
    local ok, view = pcall(newView)
    rawset(_G, "C_Texture", saved)
    assert(ok, view)
    assert(view.scrollBar.width == 11, "retail: width is the atlas width, got " .. tostring(view.scrollBar.width))
  end

  -- test_retail_width_falls_back_when_the_atlas_lookup_throws
  do
    local saved = rawget(_G, "C_Texture")
    rawset(_G, "C_Texture", {
      GetAtlasInfo = function()
        error("unknown atlas")
      end,
    })
    local ok, view = pcall(newView)
    rawset(_G, "C_Texture", saved)
    assert(ok, view)
    assert(view.scrollBar.width == retailWidth(), "retail: width falls back to the layout width, got " .. tostring(view.scrollBar.width))
  end

  -- test_retail_theme_refresh_keeps_the_atlases
  do
    local view = newView()
    view.refreshSkin()
    assert(view.scrollBar.track.atlas == TRACK_MIDDLE and view.scrollBar.track.color == nil, "retail: refresh keeps the track atlas")
    assertThumbAtlases(view.scrollBar.retailThumb, "", "retail refresh")
    assert(view.scrollBar.thumb.alpha == 0, "retail: refresh keeps the carrier invisible")
  end

  -- test_retail_without_set_atlas_falls_back_to_the_classic_knob
  do
    local factory = RetailHud.Factory(FakeUI, {
      decorate = function(frame)
        if frame.frameType ~= "Slider" then
          return
        end
        local createTexture = frame.CreateTexture
        frame.CreateTexture = function(...)
          local texture = createTexture(...)
          texture.SetAtlas = nil
          return texture
        end
      end,
    })
    local scrollBar = newView(factory).scrollBar
    assert(scrollBar.thumb.texturePath == KNOB, "no SetAtlas: thumb is the classic knob, got " .. tostring(scrollBar.thumb.texturePath))
    assert(scrollBar.retailThumb == nil, "no SetAtlas: no retail pieces")
    assert(scrollBar.width == Theme.LAYOUT.SCROLLBAR_WIDTH_HUD, "no SetAtlas: classic HUD width, got " .. tostring(scrollBar.width))
  end
end
