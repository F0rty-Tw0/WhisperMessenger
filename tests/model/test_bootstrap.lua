local FakeUI = require("tests.helpers.fake_ui")
local Bootstrap = require("WhisperMessenger.Bootstrap")

return function()
  assert(type(Bootstrap.Initialize) == "function", "Bootstrap.Initialize should exist")

  local savedTheme = package.loaded["UI.Theme"]
  local savedFonts = package.loaded["UI.Theme.Fonts"]
  local savedWindowRuntime = package.loaded["Core.Bootstrap.WindowRuntime"]
  local savedUIParent = _G.UIParent
  local windowCreateScale

  package.loaded["UI.Theme"] = {
    DEFAULT_PRESET = "wow_default",
    ResolvePreset = function(key)
      return key, true
    end,
  }
  package.loaded["UI.Theme.Fonts"] = {
    Initialize = function() end,
    SetFontSize = function() end,
    SetOutline = function() end,
    SetFontColor = function() end,
    SetLanguage = function() end,
  }
  package.loaded["Core.Bootstrap.WindowRuntime"] = {
    Create = function(options)
      windowCreateScale = options.accountState.settings.windowScale
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
    settings = { windowScale = "invalid", hideFromDefaultChat = false },
  }

  local ok, err = pcall(Bootstrap.Initialize, factory, {
    accountState = accountState,
    characterState = { window = {}, icon = {} },
  })

  package.loaded["UI.Theme"] = savedTheme
  package.loaded["UI.Theme.Fonts"] = savedFonts
  package.loaded["Core.Bootstrap.WindowRuntime"] = savedWindowRuntime
  _G.UIParent = savedUIParent

  if not ok then
    error(err, 0)
  end

  assert(accountState.settings.windowScale == 1.00, "Bootstrap persists normalized window scale")
  assert(windowCreateScale == 1.00, "window creation receives normalized window scale")
end
