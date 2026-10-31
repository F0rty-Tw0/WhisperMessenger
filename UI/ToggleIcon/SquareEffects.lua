local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local Shapes = ns.UIHelpersShapes or require("WhisperMessenger.UI.Helpers.Shapes")
local applyVertexColor = UIHelpers.applyVertexColor

-- One layer of an EllesmereUI-style button drawn on the widget's square:
-- its border, or its hover or pushed effect. paint(spec, inset) takes an
-- EllesmereButtonLook spec: "tex" (a texture over the square, inset by the
-- border), "fill" (a flat color, inset the same), "edge" (a border `px`
-- screen pixels thick) or "none".
local SquareEffects = {}

local WHITE = "Interface\\Buttons\\WHITE8X8"

local function setShown(region, shown)
  if shown and region.Show then
    region:Show()
  elseif not shown and region.Hide then
    region:Hide()
  end
end

-- layer, sublevel: where the effect draws on `frame`.
function SquareEffects.Create(frame, layer, sublevel)
  local fill = frame:CreateTexture(nil, layer, nil, sublevel)
  local edges = {}
  for _, side in ipairs({ "top", "bottom", "left", "right" }) do
    edges[side] = frame:CreateTexture(nil, layer, nil, sublevel)
    edges[side]:SetTexture(WHITE)
    Shapes.snapToPixelGrid(edges[side])
  end
  local spec = { kind = "none" }
  local shown = false

  local function placeEdges(thickness)
    local t, b, l, r = edges.top, edges.bottom, edges.left, edges.right
    t:ClearAllPoints()
    t:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    t:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    t:SetHeight(thickness)
    b:ClearAllPoints()
    b:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    b:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    b:SetHeight(thickness)
    l:ClearAllPoints()
    l:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    l:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    l:SetWidth(thickness)
    r:ClearAllPoints()
    r:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    r:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    r:SetWidth(thickness)
  end

  local function refresh()
    local useFill = shown and (spec.kind == "tex" or spec.kind == "fill")
    local useEdges = shown and spec.kind == "edge" and (spec.px or 0) > 0
    setShown(fill, useFill)
    for _, edge in pairs(edges) do
      setShown(edge, useEdges)
    end
  end

  -- inset: the square's border, in screen pixels (fills sit inside it).
  local function paint(nextSpec, inset)
    spec = nextSpec or { kind = "none" }
    local px = Shapes.pixelSize(frame)
    if spec.kind == "tex" or spec.kind == "fill" then
      fill:SetTexture(spec.kind == "tex" and spec.path or WHITE)
      if fill.SetBlendMode then
        fill:SetBlendMode(spec.blend or "BLEND")
      end
      applyVertexColor(fill, spec.color)
      local d = (inset or 0) * px
      fill:ClearAllPoints()
      fill:SetPoint("TOPLEFT", frame, "TOPLEFT", d, -d)
      fill:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -d, d)
    elseif spec.kind == "edge" then
      placeEdges((spec.px or 1) * px)
      for _, edge in pairs(edges) do
        applyVertexColor(edge, spec.color)
      end
    end
    refresh()
  end

  local function show(on)
    shown = on == true
    refresh()
  end

  return { fill = fill, edges = edges, paint = paint, show = show }
end

ns.ToggleIconSquareEffects = SquareEffects
return SquareEffects
