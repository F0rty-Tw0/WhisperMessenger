-- The docked window's top: title art, inner tile, close button, title divider.
local ROW = require("WhisperMessenger.UI.Theme").LAYOUT.SCREEN_EDGE_TITLE_ROW_HEIGHT
local GAP = require("WhisperMessenger.UI.Theme").LAYOUT.SCREEN_EDGE_TITLE_GAP
local FakeUI = require("tests.helpers.fake_ui")
local BevelAtlas = require("tests.helpers.bevel_atlas")
local Theme = require("WhisperMessenger.UI.Theme")
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
  -- test_title_art_hides_while_docked_and_comes_back
  do
    local factory, frame = build()
    local p = withPieces(frame, frame, { "TopBorder", "TitleBg", "TopTileStreaks" })
    frame.NineSlice = factory.CreateFrame("Frame", nil, frame)
    local n = withPieces(frame.NineSlice, frame.NineSlice, RETAIL)
    local border = ScreenEdgeBorder.Create(factory, frame, nil)
    for _, side in ipairs({ "left", "right" }) do
      border.apply(side)
      assert(hidden(p.TopBorder, p.TitleBg, p.TopTileStreaks, n.TopEdge), side .. ": title art hidden")
      border.apply(nil)
      assert(shown(p.TopBorder, p.TitleBg, p.TopTileStreaks, n.TopEdge), side .. ": title art back")
    end
  end

  -- test_inner_side_tile_runs_full_height_while_docked
  do
    local factory, frame = build()
    local p = withPieces(frame, frame, CLASSIC)
    p.LeftBorder:SetPoint("TOPLEFT", p.TopLeftCorner, "BOTTOMLEFT", 0, 0)
    p.LeftBorder:SetPoint("BOTTOMLEFT", p.BotLeftCorner, "TOPLEFT", 0, 0)
    p.RightBorder:SetPoint("TOPRIGHT", p.TopRightCorner, "BOTTOMRIGHT", 1, 0)
    p.RightBorder:SetPoint("BOTTOMRIGHT", p.BotRightCorner, "TOPRIGHT", 0, 0)
    local border = ScreenEdgeBorder.Create(factory, frame, nil)
    local function pointsAre(region, want, label)
      assert(region:GetNumPoints() == #want, label .. ": point count")
      for i, w in ipairs(want) do
        local point, rel, relPoint, x, y = region:GetPoint(i)
        assert(point == w[1] and rel == w[2] and relPoint == w[3] and x == w[4] and y == 0, label .. ": point " .. i .. " " .. relPoint)
      end
    end
    border.apply("right")
    assert(p.LeftBorder:IsShown(), "inner tile stays")
    pointsAre(p.LeftBorder, { { "TOPLEFT", p.TopLeftCorner, "TOPLEFT", 0 }, { "BOTTOMLEFT", p.BotLeftCorner, "BOTTOMLEFT", 0 } }, "right: left tile")
    border.apply("left")
    pointsAre(
      p.LeftBorder,
      { { "TOPLEFT", p.TopLeftCorner, "BOTTOMLEFT", 0 }, { "BOTTOMLEFT", p.BotLeftCorner, "TOPLEFT", 0 } },
      "left: left tile back"
    )
    pointsAre(
      p.RightBorder,
      { { "TOPRIGHT", p.TopRightCorner, "TOPRIGHT", 1 }, { "BOTTOMRIGHT", p.BotRightCorner, "BOTTOMRIGHT", 0 } },
      "left: right tile"
    )
    border.apply(nil)
    pointsAre(
      p.RightBorder,
      { { "TOPRIGHT", p.TopRightCorner, "BOTTOMRIGHT", 1 }, { "BOTTOMRIGHT", p.BotRightCorner, "TOPRIGHT", 0 } },
      "off: right tile back"
    )
  end

  -- test_template_close_button_sits_inside_while_docked
  do
    local factory, frame = build()
    local close = factory.CreateFrame("Button", nil, frame)
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 5, 6)
    frame.CloseButton = close
    local border = ScreenEdgeBorder.Create(factory, frame, nil)
    for _, side in ipairs({ "left", "right" }) do
      border.apply(side)
      local point, rel, relPoint, x, y = close:GetPoint(1)
      assert(
        close:GetNumPoints() == 1 and point == "RIGHT" and rel == frame and relPoint == "TOPRIGHT" and x == -4 and y == -ROW / 2,
        side .. ": inside, centred in the title row"
      )
      border.apply(nil)
      point, _, _, x, y = close:GetPoint(1)
      assert(close:GetNumPoints() == 1 and point == "TOPRIGHT" and x == 5 and y == 6, side .. ": template anchor back")
    end
  end

  -- test_title_divider_under_the_title_row
  BevelAtlas.With(function()
    local factory, frame = build()
    local close = factory.CreateFrame("Button", nil, frame)
    close:SetSize(24, 24)
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 1, 0)
    frame.CloseButton = close
    local border = ScreenEdgeBorder.Create(factory, frame, nil, { titleHeight = ROW + GAP, hud = true })
    border.apply("right")
    local divider = border.titleDivider
    assert(divider and divider:IsShown(), "divider shown")
    assert(divider.color == nil, "no colour line over the bevel")
    assert(divider.atlas == "_UI-Frame-InnerTopTile" and divider.height == 3, "HUD: the inset top bevel at its 3 px, got " .. tostring(divider.atlas))
    local point, rel, relPoint, x, y = divider:GetPoint(1)
    assert(point == "TOPLEFT" and rel == frame and relPoint == "TOPLEFT" and x == 0 and y == -(ROW + GAP), "under the title row")
    -- test_close_button_sits_fully_above_the_divider
    local closeBottom = ROW / 2 + close.height / 2
    assert(closeBottom < ROW + GAP, "X bottom " .. closeBottom .. " above the divider top " .. (ROW + GAP))
    border.apply(nil)
    assert(not divider:IsShown(), "hidden when off")
    local custom = ScreenEdgeBorder.Create(factory, frame, nil, { titleHeight = 25, hud = false })
    custom.apply("left")
    assert(custom.titleDivider.color[1] == Theme.COLORS.window_border[1], "custom: window border colour")
  end)

  -- test_title_divider_falls_back_to_a_line_without_the_atlas
  do
    local factory, frame = build()
    local border = ScreenEdgeBorder.Create(factory, frame, nil, { titleHeight = ROW + GAP, hud = true })
    border.apply("left")
    local divider = border.titleDivider
    assert(divider.atlas == nil and divider.height == 1, "no atlas: a 1 px line")
    assert(divider.color[1] == Theme.COLORS.window_border[1], "window border colour")
  end
end
