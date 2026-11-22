local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local UIHelpers = require("WhisperMessenger.UI.Helpers")
local ScreenEdgeBorder = require("WhisperMessenger.UI.MessengerWindow.ChromeBuilder.ScreenEdgeBorder")

local function build()
  local factory = FakeUI.NewFactory()
  local frame = factory.CreateFrame("Frame", "Window", nil)
  return factory, frame
end

local function piece(frame, owner, key)
  local tex = frame:CreateTexture(nil, "BORDER")
  tex:Show()
  owner[key] = tex
  return tex
end

local function shown(...)
  for _, p in ipairs({ ... }) do
    if not p:IsShown() then
      return false
    end
  end
  return true
end

local function hidden(...)
  for _, p in ipairs({ ... }) do
    if p:IsShown() then
      return false
    end
  end
  return true
end

local CLASSIC = { "TopLeftCorner", "TopRightCorner", "BotLeftCorner", "BotRightCorner", "BottomBorder", "LeftBorder", "RightBorder", "TopBorder" }
local RETAIL = { "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner", "BottomEdge", "LeftEdge", "RightEdge", "TopEdge" }

local function withPieces(frame, owner, keys)
  local pieces = {}
  for _, key in ipairs(keys) do
    pieces[key] = piece(frame, owner, key)
  end
  return pieces
end

return function()
  -- test_modern_left_keeps_only_the_right_edge
  do
    local factory, frame = build()
    local edges = UIHelpers.createBorderBox(frame, { 1, 1, 1, 1 }, 1)
    for _, e in pairs(edges) do
      e:Show()
    end
    local border = ScreenEdgeBorder.Create(factory, frame, edges)
    border.apply("left")
    assert(shown(edges.right) and hidden(edges.left, edges.top, edges.bottom), "only the inner (right) edge stays")

    -- test_modern_off_shows_every_edge_again
    border.apply(nil)
    assert(shown(edges.top, edges.left, edges.right, edges.bottom), "every edge is back")

    border.apply("right")
    assert(shown(edges.left) and hidden(edges.right, edges.top, edges.bottom), "right edge keeps the left one")
  end

  -- test_classic_left_hides_corners_bottom_and_left_tile_keeps_the_right_tile
  do
    local factory, frame = build()
    local p = withPieces(frame, frame, CLASSIC)
    ScreenEdgeBorder.Create(factory, frame, nil).apply("left")
    assert(hidden(p.TopLeftCorner, p.TopRightCorner, p.BotLeftCorner, p.BotRightCorner, p.BottomBorder, p.LeftBorder), "screen-side pieces hidden")
    assert(shown(p.RightBorder), "right tile stays")
  end

  -- test_classic_right_hides_the_right_tile_not_the_left
  do
    local factory, frame = build()
    local p = withPieces(frame, frame, CLASSIC)
    ScreenEdgeBorder.Create(factory, frame, nil).apply("right")
    assert(hidden(p.RightBorder) and shown(p.LeftBorder), "right tile hidden, left stays")
  end

  -- test_retail_left_hides_nine_slice_corners_bottom_and_left_edge
  do
    local factory, frame = build()
    frame.NineSlice = factory.CreateFrame("Frame", nil, frame)
    local p = withPieces(frame.NineSlice, frame.NineSlice, RETAIL)
    local border = ScreenEdgeBorder.Create(factory, frame, nil)
    border.apply("left")
    assert(hidden(p.TopLeftCorner, p.TopRightCorner, p.BottomLeftCorner, p.BottomRightCorner, p.BottomEdge, p.LeftEdge), "hidden")
    assert(shown(p.RightEdge), "right edge stays")
    border.apply(nil)
    assert(shown(p.TopLeftCorner, p.LeftEdge, p.BottomEdge), "restored")
  end

  -- test_classic_inset_border_hides_on_the_screen_side_and_bottom
  do
    local factory, frame = build()
    local p = withPieces(frame, frame, {
      "InsetBorderTopLeft",
      "InsetBorderTopRight",
      "InsetBorderTop",
      "InsetBorderLeft",
      "InsetBorderRight",
      "InsetBorderBottom",
      "InsetBorderBottomLeft",
      "InsetBorderBottomRight",
    })
    local border = ScreenEdgeBorder.Create(factory, frame, nil)
    border.apply("left")
    assert(hidden(p.InsetBorderLeft, p.InsetBorderTopLeft, p.InsetBorderBottom, p.InsetBorderBottomLeft, p.InsetBorderBottomRight), "left: hidden")
    assert(shown(p.InsetBorderRight), "left: inner side stays")
    assert(hidden(p.InsetBorderTop, p.InsetBorderTopRight), "left: the inset top row goes (the title divider replaces it)")
    border.apply("right")
    assert(hidden(p.InsetBorderRight, p.InsetBorderTopRight, p.InsetBorderBottom), "right: hidden")
    assert(shown(p.InsetBorderLeft), "right: left side back")
    border.apply(nil)
    assert(shown(p.InsetBorderRight, p.InsetBorderTopRight, p.InsetBorderTop, p.InsetBorderBottom, p.InsetBorderBottomLeft), "off: all back")
  end

  -- test_backgrounds_reach_the_screen_side_top_and_bottom_and_come_back
  do
    local factory, frame = build()
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -21)
    bg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
    frame.Bg = bg
    local insetBg = frame:CreateTexture(nil, "BACKGROUND")
    insetBg:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -24)
    insetBg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, 4)
    frame.InsetBg = insetBg
    local function pointsAre(region, want, label)
      assert(region:GetNumPoints() == #want, label .. ": point count " .. region:GetNumPoints())
      for i, w in ipairs(want) do
        local point, rel, relPoint, x, y = region:GetPoint(i)
        assert(
          point == w[1] and rel == frame and relPoint == w[1] and x == w[2] and y == w[3],
          label .. ": point " .. i .. " " .. point .. " " .. x .. "," .. y
        )
      end
    end
    local border = ScreenEdgeBorder.Create(factory, frame, nil)
    border.apply("right")
    pointsAre(bg, { { "TOPLEFT", 2, 0 }, { "BOTTOMRIGHT", 0, 0 } }, "Bg right")
    pointsAre(insetBg, { { "TOPLEFT", 4, 0 }, { "BOTTOMRIGHT", 0, 0 } }, "InsetBg right")
    border.apply("left")
    pointsAre(bg, { { "TOPLEFT", 0, 0 }, { "BOTTOMRIGHT", -2, 0 } }, "Bg left")
    pointsAre(insetBg, { { "TOPLEFT", 0, 0 }, { "BOTTOMRIGHT", -6, 0 } }, "InsetBg left")
    border.apply(nil)
    pointsAre(bg, { { "TOPLEFT", 2, -21 }, { "BOTTOMRIGHT", -2, 2 } }, "Bg off")
    pointsAre(insetBg, { { "TOPLEFT", 4, -24 }, { "BOTTOMRIGHT", -6, 4 } }, "InsetBg off")
  end

  -- test_retail_panel_insets_hide_their_screen_side_and_bottom
  do
    local factory, frame = build()
    local insets = {}
    for _, key in ipairs({ "Inset", "contactsInset" }) do
      frame[key] = factory.CreateFrame("Frame", nil, frame)
      frame[key].NineSlice = factory.CreateFrame("Frame", nil, frame[key])
      insets[key] = withPieces(frame[key].NineSlice, frame[key].NineSlice, RETAIL)
    end
    local border = ScreenEdgeBorder.Create(factory, frame, nil)
    border.apply("right")
    for key, p in pairs(insets) do
      assert(hidden(p.TopRightCorner, p.RightEdge, p.BottomLeftCorner, p.BottomRightCorner, p.BottomEdge), key .. ": hidden")
      assert(shown(p.TopLeftCorner, p.LeftEdge, p.TopEdge), key .. ": inner side and top stay")
    end
    border.apply(nil)
    for key, p in pairs(insets) do
      assert(shown(p.TopRightCorner, p.RightEdge, p.BottomEdge), key .. ": back")
    end
  end

  -- test_retail_portrait_and_its_ring_hide_on_either_side
  do
    local factory, frame = build()
    frame.NineSlice = factory.CreateFrame("Frame", nil, frame)
    local p = withPieces(frame.NineSlice, frame.NineSlice, RETAIL)
    frame.PortraitContainer = factory.CreateFrame("Frame", nil, frame)
    frame.PortraitContainer:Show()
    local border = ScreenEdgeBorder.Create(factory, frame, nil)
    for _, side in ipairs({ "left", "right" }) do
      border.apply(side)
      assert(hidden(frame.PortraitContainer, p.TopLeftCorner), side .. ": portrait and its ring corner hidden")
      border.apply(nil)
      assert(shown(frame.PortraitContainer, p.TopLeftCorner), side .. ": both back when off")
    end
  end

  -- test_off_restores_only_what_it_hid
  do
    local factory, frame = build()
    local p = withPieces(frame, frame, CLASSIC)
    p.BottomBorder:Hide()
    local border = ScreenEdgeBorder.Create(factory, frame, nil)
    border.apply("left")
    border.apply(nil)
    assert(hidden(p.BottomBorder), "a piece hidden before stays hidden")
    assert(shown(p.TopLeftCorner, p.LeftBorder), "the others come back")
  end

  -- test_shade_sits_on_the_screen_side_above_the_panes
  do
    local factory, frame = build()
    frame:SetFrameLevel(5)
    local border = ScreenEdgeBorder.Create(factory, frame, nil)
    border.apply("left")
    local shade = frame.children[#frame.children]
    assert(shade:IsShown() and shade.mouseEnabled == false, "shown, no mouse")
    assert(shade.width == Theme.LAYOUT.SCREEN_EDGE_SHADE_WIDTH, "width")
    assert(shade.points[1][1] == "TOPLEFT" and shade.points[1][2] == frame, "left anchor")
    assert(shade:GetFrameLevel() == 30, "level is frame + 25")
    border.apply("right")
    assert(shade.points[1][1] == "TOPRIGHT" and shade.points[2][1] == "BOTTOMRIGHT", "right anchor")
    border.apply(nil)
    assert(not shade:IsShown(), "hidden when off")
  end

  -- test_shade_level_follows_a_raised_window
  do
    local factory, frame = build()
    frame:SetFrameLevel(5)
    local border = ScreenEdgeBorder.Create(factory, frame, nil)
    border.apply("left")
    local shade = frame.children[#frame.children]
    frame:SetFrameLevel(40)
    border.apply("left")
    assert(shade:GetFrameLevel() == 65, "level re-set to frame + 25, got " .. tostring(shade:GetFrameLevel()))
  end

  -- test_missing_pieces_are_skipped
  do
    local factory, frame = build()
    local border = ScreenEdgeBorder.Create(factory, frame, nil)
    border.apply("left")
    border.apply(nil)
  end

  -- test_inner_inset_line_runs_frame_top_to_bottom_while_docked
  do
    local factory, frame = build()
    local insetBg = frame:CreateTexture(nil, "BACKGROUND")
    insetBg:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -24)
    insetBg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, 4)
    frame.InsetBg = insetBg
    local p = withPieces(frame, frame, {
      "InsetBorderTopLeft",
      "InsetBorderTopRight",
      "InsetBorderBottomLeft",
      "InsetBorderBottomRight",
      "InsetBorderLeft",
      "InsetBorderRight",
    })
    -- BasicFrameTemplateWithInset's anchors (UIPanelTemplates.xml, forever).
    p.InsetBorderLeft:SetPoint("TOPLEFT", p.InsetBorderTopLeft, "BOTTOMLEFT", 0, 0)
    p.InsetBorderLeft:SetPoint("BOTTOMLEFT", p.InsetBorderBottomLeft, "TOPLEFT", 0, 0)
    p.InsetBorderRight:SetPoint("TOPRIGHT", p.InsetBorderTopRight, "BOTTOMRIGHT", 0, 0)
    p.InsetBorderRight:SetPoint("BOTTOMRIGHT", p.InsetBorderBottomRight, "TOPRIGHT", 0, 0)
    local function pointsAre(region, want, label)
      assert(region:GetNumPoints() == #want, label .. ": point count")
      for i, w in ipairs(want) do
        local point, rel, relPoint, x, y = region:GetPoint(i)
        assert(point == w[1] and rel == w[2] and relPoint == w[3] and x == 0 and y == 0, label .. ": point " .. i .. " " .. tostring(relPoint))
      end
    end
    local border = ScreenEdgeBorder.Create(factory, frame, nil)
    border.apply("right")
    assert(shown(p.InsetBorderLeft) and hidden(p.InsetBorderTopLeft, p.InsetBorderBottomLeft), "right: inner line stays, its corners go")
    pointsAre(p.InsetBorderLeft, { { "TOPLEFT", insetBg, "TOPLEFT" }, { "BOTTOMLEFT", insetBg, "BOTTOMLEFT" } }, "right: inner line full height")
    local _, _, _, _, top = insetBg:GetPoint(1)
    local _, _, _, _, bottom = insetBg:GetPoint(2)
    assert(top == 0 and bottom == 0, "the inset background spans frame top to bottom")
    border.apply("left")
    assert(shown(p.InsetBorderRight) and hidden(p.InsetBorderTopRight, p.InsetBorderBottomRight), "left: inner line stays, its corners go")
    pointsAre(p.InsetBorderRight, { { "TOPRIGHT", insetBg, "TOPRIGHT" }, { "BOTTOMRIGHT", insetBg, "BOTTOMRIGHT" } }, "left: inner line full height")
    pointsAre(
      p.InsetBorderLeft,
      { { "TOPLEFT", p.InsetBorderTopLeft, "BOTTOMLEFT" }, { "BOTTOMLEFT", p.InsetBorderBottomLeft, "TOPLEFT" } },
      "left: the other line back on its corners"
    )
    border.apply(nil)
    pointsAre(
      p.InsetBorderRight,
      { { "TOPRIGHT", p.InsetBorderTopRight, "BOTTOMRIGHT" }, { "BOTTOMRIGHT", p.InsetBorderBottomRight, "TOPRIGHT" } },
      "off: line back on its corners"
    )
    assert(shown(p.InsetBorderTopLeft, p.InsetBorderTopRight, p.InsetBorderBottomLeft, p.InsetBorderBottomRight), "off: corners back")
  end
end
