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
  local function boot(settings)
    local state = {
      schemaVersion = 1,
      conversations = {},
      contacts = {},
      pendingHydration = {},
      settings = settings,
    }
    local bootOk, bootErr = pcall(Bootstrap.Initialize, factory, {
      accountState = state,
      characterState = { window = {}, icon = {} },
    })
    return state, bootOk, bootErr
  end

  local accountState, ok, err = boot({
    windowScale = "invalid",
    hideFromDefaultChat = false,
    hideBattleTagNumbers = false,
    showPlayerLevels = true,
  })

  local DisplayName = require("WhisperMessenger.Util.DisplayName")
  local scaleAtCreate = windowCreateScale
  local formatAfterSavedOff = DisplayName.Format("Arthas#1234")
  local classColorsAfterUnsaved = DisplayName.ClassColorSenderNames()
  local levelsAfterSavedOn = DisplayName.ShowPlayerLevels()
  -- No saved choice: player levels stay off even if they were on before.
  local _, unsavedOk, unsavedErr = boot({})
  local levelsAfterUnsaved = DisplayName.ShowPlayerLevels()

  package.loaded["UI.Theme"] = savedTheme
  package.loaded["UI.Theme.Fonts"] = savedFonts
  package.loaded["Core.Bootstrap.WindowRuntime"] = savedWindowRuntime
  _G.UIParent = savedUIParent

  if not ok then
    error(err, 0)
  end
  if not unsavedOk then
    error(unsavedErr, 0)
  end

  assert(accountState.settings.windowScale == 1.00, "Bootstrap persists normalized window scale")
  assert(scaleAtCreate == 1.00, "window creation receives normalized window scale")
  assert(formatAfterSavedOff == "Arthas#1234", "a saved off choice shows full BattleTags after login")
  assert(classColorsAfterUnsaved == true, "no saved choice colours names after login")
  assert(levelsAfterSavedOn == true, "a saved on choice shows player levels after login")
  assert(levelsAfterUnsaved == false, "no saved choice keeps player levels off after login")
  DisplayName.Configure({ classColorSenderNames = false, showPlayerLevels = false })
end
