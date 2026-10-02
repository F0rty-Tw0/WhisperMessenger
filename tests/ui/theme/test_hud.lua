local Hud = require("WhisperMessenger.UI.Theme.Hud")
local Flavor = require("tests.helpers.flavor")

local RETAIL_TEMPLATES = { PortraitFrameTemplate = true, MinimalSliderWithSteppersTemplate = true }

local function withXmlUtil(xmlUtil, fn)
  local saved = rawget(_G, "C_XMLUtil")
  rawset(_G, "C_XMLUtil", xmlUtil)
  local ok, err = pcall(fn)
  rawset(_G, "C_XMLUtil", saved)
  Hud.Configure("off")
  if not ok then
    error(err, 0)
  end
end

local function retailClient()
  return {
    GetTemplateInfo = function(name)
      return RETAIL_TEMPLATES[name] and { type = "Frame" } or nil
    end,
  }
end

return function()
  -- test_default_style_is_modern_on_retail
  Flavor.With(true, false, function()
    assert(Hud.DefaultStyle() == "retail", "Retail defaults to Modern, got " .. tostring(Hud.DefaultStyle()))
  end)

  -- test_default_style_is_modern_on_forever
  Flavor.With(false, true, function()
    assert(Hud.DefaultStyle() == "retail", "Forever defaults to Modern, got " .. tostring(Hud.DefaultStyle()))
  end)

  -- test_default_preset_is_azeroth_with_modern
  Flavor.With(true, false, function()
    assert(Hud.DefaultPreset() == "wow_native", "Modern pairs with Azeroth, got " .. tostring(Hud.DefaultPreset()))
  end)

  -- test_default_preset_is_midnight_without_the_hud
  Flavor.With(false, false, function()
    assert(Hud.DefaultPreset() == "wow_default", "Classic flavors keep Midnight, got " .. tostring(Hud.DefaultPreset()))
  end)

  -- test_default_style_is_off_on_classic
  Flavor.With(false, false, function()
    assert(Hud.DefaultStyle() == "off", "Classic flavors default to Off, got " .. tostring(Hud.DefaultStyle()))
  end)

  -- test_unknown_style_turns_the_hud_off
  withXmlUtil(nil, function()
    Hud.Configure("classic")
    Hud.Configure("fancy")
    assert(Hud.Style() == "off", "unknown style should be off, got " .. tostring(Hud.Style()))
    assert(Hud.IsOn() == false, "off HUD is not on")
  end)

  -- test_nil_style_turns_the_hud_off
  withXmlUtil(nil, function()
    Hud.Configure("classic")
    Hud.Configure(nil)
    assert(Hud.Style() == "off", "nil style should be off")
  end)

  -- test_classic_style_is_on_but_not_retail
  withXmlUtil(nil, function()
    Hud.Configure("classic")
    assert(Hud.Style() == "classic", "classic stays classic")
    assert(Hud.IsOn() == true, "classic HUD is on")
    assert(Hud.IsRetail() == false, "classic HUD is not retail")
  end)

  -- test_retail_without_xml_util_falls_back_to_classic
  withXmlUtil(nil, function()
    assert(Hud.RetailAvailable() == false, "no C_XMLUtil means no retail templates")
    Hud.Configure("retail")
    assert(Hud.Style() == "classic", "retail without C_XMLUtil should be classic, got " .. tostring(Hud.Style()))
    assert(Hud.IsRetail() == false, "fallback is not retail")
  end)

  -- test_retail_without_templates_falls_back_to_classic
  withXmlUtil({
    GetTemplateInfo = function()
      return nil
    end,
  }, function()
    assert(Hud.RetailAvailable() == false, "missing templates mean retail unavailable")
    Hud.Configure("retail")
    assert(Hud.Style() == "classic", "retail without templates should be classic")
  end)

  -- test_retail_needs_every_template
  withXmlUtil({
    GetTemplateInfo = function(name)
      return name == "PortraitFrameTemplate" and {} or nil
    end,
  }, function()
    assert(Hud.RetailAvailable() == false, "one missing template means retail unavailable")
  end)

  -- test_retail_with_templates_is_retail
  withXmlUtil(retailClient(), function()
    assert(Hud.RetailAvailable() == true, "both templates present means retail available")
    Hud.Configure("retail")
    assert(Hud.Style() == "retail", "retail with templates stays retail, got " .. tostring(Hud.Style()))
    assert(Hud.IsOn() == true, "retail HUD is on")
    assert(Hud.IsRetail() == true, "retail HUD is retail")
  end)

  -- test_template_lookup_error_counts_as_missing
  withXmlUtil({
    GetTemplateInfo = function(name)
      if name == "MinimalSliderWithSteppersTemplate" then
        error("lookup failed")
      end
      return {}
    end,
  }, function()
    local ok, available = pcall(Hud.RetailAvailable)
    assert(ok, "a failing template lookup must not escape: " .. tostring(available))
    assert(available == false, "a failing template lookup counts as missing")
  end)

  -- test_non_function_lookup_is_unavailable
  withXmlUtil({ GetTemplateInfo = true }, function()
    assert(Hud.RetailAvailable() == false, "non-function GetTemplateInfo means unavailable")
  end)
  -- test_classic_content_insets_clear_the_basic_frame_border
  withXmlUtil(nil, function()
    local L = require("WhisperMessenger.UI.Theme.Layout")
    Hud.Configure("classic")
    local insets = Hud.ContentInsets(L)
    local pad = L.HUD_CONTENT_INSET
    assert(insets.left == L.HUD_INSET_LEFT + pad and insets.right == L.HUD_INSET_RIGHT + pad, "classic: side insets")
    assert(insets.top == L.TOP_BAR_HEIGHT + L.HUD_CONTENT_TOP_INSET, "classic: top inset clears the title bar")
    assert(insets.bottom == L.HUD_INSET_BOTTOM + pad, "classic: bottom inset")
  end)

  -- test_retail_content_insets_use_the_retail_constants
  withXmlUtil(retailClient(), function()
    local L = require("WhisperMessenger.UI.Theme.Layout")
    Hud.Configure("retail")
    local insets = Hud.ContentInsets(L)
    assert(insets.left == L.RETAIL_HUD_INSET_LEFT and insets.right == L.RETAIL_HUD_INSET_RIGHT, "retail: side insets")
    assert(insets.top == L.RETAIL_HUD_INSET_TOP and insets.bottom == L.RETAIL_HUD_INSET_BOTTOM, "retail: top and bottom insets")
    assert(type(insets.top) == "number" and insets.top > L.TOP_BAR_HEIGHT, "retail: content starts below the portrait, under the title bar")
  end)
end
