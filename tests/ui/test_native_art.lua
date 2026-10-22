local FakeUI = require("tests.helpers.fake_ui")
local RetailHud = require("tests.helpers.retail_hud")
local NativeArt = require("WhisperMessenger.UI.Helpers.NativeArt")

local function newTexture()
  local frame = FakeUI.NewFactory().CreateFrame("Frame", nil, nil)
  return frame:CreateTexture(nil, "BACKGROUND")
end

return function()
  -- test_paint_panel_draws_the_panel_atlas_when_the_client_knows_it
  RetailHud.WithAtlas(true, function()
    local texture = newTexture()
    assert(NativeArt.PaintPanel(texture) == true, "known atlas: PaintPanel should report success")
    assert(texture.atlas == "Professions-background-summarylist", "known atlas: texture should carry the panel atlas")
    assert(texture.useAtlasSize == false, "known atlas: texture should stretch, not use the atlas size")
    assert(texture._wmNativeArt == true, "known atlas: texture should be flagged as native art")
  end)

  -- test_paint_panel_draws_the_given_atlas
  RetailHud.WithAtlas(true, function()
    local texture = newTexture()
    assert(NativeArt.PaintPanel(texture, NativeArt.WIDE_PANEL_BACKGROUND) == true, "wide atlas: PaintPanel should report success")
    assert(texture.atlas == "auctionhouse-background-index", "wide atlas: texture should carry the wide panel atlas")
  end)

  -- test_paint_panel_leaves_the_texture_alone_when_the_atlas_is_unknown
  RetailHud.WithAtlas(false, function()
    local texture = newTexture()
    assert(NativeArt.PaintPanel(texture) == false, "unknown atlas: PaintPanel should report failure")
    assert(texture.atlas == nil, "unknown atlas: texture should get no atlas")
    assert(texture._wmNativeArt == nil, "unknown atlas: texture should not be flagged")
  end)
end
