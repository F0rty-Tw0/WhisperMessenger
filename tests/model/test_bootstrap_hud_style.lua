-- Boot-time Native WoW HUD wiring: seeds the hudStyle setting, configures
-- the session's HUD, and keeps painting the player's own theme preset.
local FakeUI = require("tests.helpers.fake_ui")
local Bootstrap = require("WhisperMessenger.Bootstrap")
local Hud = require("WhisperMessenger.UI.Theme.Hud")
local Theme = require("WhisperMessenger.UI.Theme")
local Fonts = require("WhisperMessenger.UI.Theme.Fonts")
local Presets = require("WhisperMessenger.UI.Theme.Presets")
local BubbleColors = require("WhisperMessenger.UI.Theme.BubbleColors")
local Flavor = require("tests.helpers.flavor")

-- An account that already booted once, so fresh-install defaults skip it.
local UPGRADED = { firstRunTipShown = true }

local function sameColor(a, b)
  return a[1] == b[1] and a[2] == b[2] and a[3] == b[3] and a[4] == b[4]
end

local function boot(settings)
  local savedWindowRuntime = package.loaded["Core.Bootstrap.WindowRuntime"]
  local savedUIParent = _G.UIParent
  package.loaded["Core.Bootstrap.WindowRuntime"] = {
    Create = function()
      return {
        getIcon = function()
          return nil
        end,
        getWindow = function()
          return nil
        end,
        isWindowVisible = function()
          return false
        end,
      }
    end,
  }
  local factory = FakeUI.NewFactory()
  _G.UIParent = factory.CreateFrame("Frame", "UIParent", nil)
  local accountState = {
    schemaVersion = 1,
    conversations = {},
    contacts = {},
    pendingHydration = {},
    settings = settings,
  }

  local ok, err = pcall(Bootstrap.Initialize, factory, {
    accountState = accountState,
    characterState = { window = {}, icon = {} },
  })

  package.loaded["Core.Bootstrap.WindowRuntime"] = savedWindowRuntime
  _G.UIParent = savedUIParent
  if not ok then
    error(err, 0)
  end
  return accountState.settings
end

local function resetLooks()
  BubbleColors.SetPreset("default")
  Fonts.SetFontColor("default")
  Theme.SetPreset(Theme.DEFAULT_PRESET)
  Hud.Configure("off")
end

return function()
  -- test_fresh_install_on_retail_seeds_modern
  Flavor.With(true, false, function()
    local settings = boot({})
    assert(settings.hudStyle == "retail", "fresh Retail install seeds Modern, got " .. tostring(settings.hudStyle))
    resetLooks()
  end)

  -- test_fresh_install_on_forever_seeds_modern
  Flavor.With(false, true, function()
    local settings = boot({})
    assert(settings.hudStyle == "retail", "fresh Forever install seeds Modern, got " .. tostring(settings.hudStyle))
    resetLooks()
  end)

  -- test_fresh_install_on_classic_seeds_off
  Flavor.With(false, false, function()
    local settings = boot({})
    assert(settings.hudStyle == "off", "fresh Classic install keeps HUD off, got " .. tostring(settings.hudStyle))
    resetLooks()
  end)

  -- test_upgrade_on_retail_keeps_hud_off
  Flavor.With(true, false, function()
    local settings = boot({ firstRunTipShown = true })
    assert(settings.hudStyle == "off", "upgraders keep their look, got " .. tostring(settings.hudStyle))
    resetLooks()
  end)

  -- test_fresh_install_hides_whispers_from_default_chat
  Flavor.With(false, false, function()
    local settings = boot({})
    assert(settings.hideFromDefaultChat == true, "fresh install hides whispers from default chat on every flavor")
    resetLooks()
  end)

  -- test_upgrade_keeps_whispers_in_default_chat
  do
    local settings = boot({ firstRunTipShown = true })
    assert(settings.hideFromDefaultChat == nil, "upgraders keep whispers in default chat")
    resetLooks()
  end

  -- test_fresh_install_keeps_an_explicit_chat_choice
  do
    local settings = boot({ hideFromDefaultChat = false })
    assert(settings.hideFromDefaultChat == false, "a saved choice is never overwritten")
    resetLooks()
  end

  -- test_seed_classic_from_legacy_native_chrome
  do
    local settings = boot({ nativeChrome = true, firstRunTipShown = true })
    assert(settings.hudStyle == "classic", "nativeChrome=true seeds classic, got " .. tostring(settings.hudStyle))
    assert(settings.nativeChrome == true, "the legacy nativeChrome flag is kept for older versions")
    assert(Hud.Style() == "classic", "boot configures the session HUD from the seeded style")
    resetLooks()
  end

  -- test_seed_off_when_native_chrome_is_false
  do
    local settings = boot({ nativeChrome = false, firstRunTipShown = true })
    assert(settings.hudStyle == "off", "nativeChrome=false seeds off, got " .. tostring(settings.hudStyle))
    assert(settings.nativeChrome == false, "nativeChrome=false is kept")
    assert(Hud.IsOn() == false, "off HUD at boot")
    resetLooks()
  end

  -- test_seed_off_when_native_chrome_is_missing
  do
    local settings = boot(UPGRADED)
    assert(settings.hudStyle == "off", "missing nativeChrome seeds off, got " .. tostring(settings.hudStyle))
    resetLooks()
  end

  -- test_existing_hud_style_is_untouched
  do
    local settings = boot({ hudStyle = "retail", nativeChrome = false })
    assert(settings.hudStyle == "retail", "a saved hudStyle is never reseeded, got " .. tostring(settings.hudStyle))
    assert(Hud.Style() == "classic", "retail without game templates boots as classic")
    resetLooks()
  end

  -- test_hud_keeps_the_users_colours
  do
    local settings = boot({ hudStyle = "classic", themePreset = "elvui_dark", fontColor = "gold" })
    assert(sameColor(Theme.COLORS.bg_primary, assert(Presets.Get("elvui_dark")).bg_primary), "HUD paints the chosen theme")
    assert(Fonts.GetFontColorRGBA() ~= nil, "HUD applies the font colour")
    assert(settings.themePreset == "elvui_dark", "saved theme kept")
    resetLooks()
  end

  -- test_no_hud_keeps_the_users_colours
  do
    local settings = boot({ hudStyle = "off", themePreset = "elvui_dark", fontColor = "gold" })
    assert(sameColor(Theme.COLORS.bg_primary, assert(Presets.Get("elvui_dark")).bg_primary), "no HUD paints the chosen theme")
    assert(Fonts.GetFontColorRGBA() ~= nil, "no HUD applies the font colour")
    assert(settings.themePreset == "elvui_dark", "saved theme kept")
    resetLooks()
  end
end
