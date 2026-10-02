local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local NativeArt = ns.UIHelpersNativeArt or require("WhisperMessenger.UI.Helpers.NativeArt")

-- Native WoW HUD, Retail style: the minimal scrollbar from the professions
-- recipe list. Slim rounded track, three-piece thumb, no arrow buttons.
-- The atlases are drawn untinted.
local RetailSkin = {}

-- The slider moves one thumb texture. It stays invisible and carries the
-- three visible pieces. Fixed height, like the other scrollbar skins.
local THUMB_HEIGHT = 32
local PARTS = { "top", "middle", "bottom" }

function RetailSkin.Supported(texture)
  return type(texture.SetAtlas) == "function"
end

-- The thumb atlas's own width when the client reports it.
function RetailSkin.Width()
  local info = NativeArt.AtlasInfo(NativeArt.SCROLL_THUMB.top)
  if info and type(info.width) == "number" and info.width > 0 then
    return info.width
  end
  return Theme.LAYOUT.SCROLLBAR_WIDTH_RETAIL
end

-- Caps on the ends of `anchor`, the middle stretched between them.
local function threeSlice(top, middle, bottom, anchor)
  top:SetPoint("TOP", anchor, "TOP", 0, 0)
  bottom:SetPoint("BOTTOM", anchor, "BOTTOM", 0, 0)
  middle:SetPoint("TOPLEFT", top, "BOTTOMLEFT", 0, 0)
  middle:SetPoint("BOTTOMRIGHT", bottom, "TOPRIGHT", 0, 0)
end

local function paintThumb(pieces, atlases)
  for _, part in ipairs(PARTS) do
    NativeArt.SetAtlas(pieces[part], atlases[part], part ~= "middle")
  end
end

local function buildTrack(scrollBar, track)
  local top = scrollBar:CreateTexture(nil, "BACKGROUND")
  local bottom = scrollBar:CreateTexture(nil, "BACKGROUND")
  NativeArt.SetAtlas(top, NativeArt.SCROLL_TRACK_TOP, true)
  NativeArt.SetAtlas(track, NativeArt.SCROLL_TRACK_MIDDLE, false)
  NativeArt.SetAtlas(bottom, NativeArt.SCROLL_TRACK_BOTTOM, true)
  track:ClearAllPoints()
  threeSlice(top, track, bottom, scrollBar)
  scrollBar.retailTrack = { top = top, middle = track, bottom = bottom }
end

local function buildThumb(scrollBar, carrier, width)
  carrier:SetSize(width, THUMB_HEIGHT)
  carrier:SetAlpha(0)
  local pieces = {}
  for _, part in ipairs(PARTS) do
    pieces[part] = scrollBar:CreateTexture(nil, "ARTWORK")
  end
  threeSlice(pieces.top, pieces.middle, pieces.bottom, carrier)
  paintThumb(pieces, NativeArt.SCROLL_THUMB)
  scrollBar.retailThumb = pieces
  return pieces
end

-- Dresses the slider; `track` becomes the track's middle and `thumb` the
-- invisible carrier. Returns the theme repaint, which has nothing to do.
function RetailSkin.Apply(scrollBar, track, thumb, width)
  buildTrack(scrollBar, track)
  local pieces = buildThumb(scrollBar, thumb, width)
  if scrollBar.SetScript then
    scrollBar:SetScript("OnEnter", function()
      paintThumb(pieces, NativeArt.SCROLL_THUMB_OVER)
    end)
    scrollBar:SetScript("OnLeave", function()
      paintThumb(pieces, NativeArt.SCROLL_THUMB)
    end)
  end
  return function() end
end

ns.ScrollViewRetailSkin = RetailSkin
return RetailSkin
