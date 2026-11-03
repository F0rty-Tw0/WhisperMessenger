local FakeUI = require("tests.helpers.fake_ui")
local Bootstrap = require("WhisperMessenger.Bootstrap")

-- Addon greeting announcements only arrive once the robots.txt prefix is
-- registered, so boot registers it next to WM's own prefixes.
return function()
  local savedTheme = package.loaded["UI.Theme"]
  local savedFonts = package.loaded["UI.Theme.Fonts"]
  local savedWindowRuntime = package.loaded["Core.Bootstrap.WindowRuntime"]
  local savedUIParent = _G.UIParent
  local savedChatInfo = _G.C_ChatInfo

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

  local registered = {}
  _G.C_ChatInfo = {
    RegisterAddonMessagePrefix = function(prefix)
      registered[prefix] = true
      return true
    end,
  }

  local factory = FakeUI.NewFactory()
  _G.UIParent = factory.CreateFrame("Frame", "UIParent", nil)
  local ok, err = pcall(Bootstrap.Initialize, factory, {
    accountState = { schemaVersion = 1, conversations = {}, contacts = {}, pendingHydration = {}, settings = {} },
    characterState = { window = {}, icon = {} },
  })

  package.loaded["UI.Theme"] = savedTheme
  package.loaded["UI.Theme.Fonts"] = savedFonts
  package.loaded["Core.Bootstrap.WindowRuntime"] = savedWindowRuntime
  _G.UIParent = savedUIParent
  _G.C_ChatInfo = savedChatInfo

  if not ok then
    error(err, 0)
  end
  assert(registered["robots.txt"] == true, "boot registers the robots.txt addon greeting prefix")
end
