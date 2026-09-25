local IconRuntime = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.IconRuntime")
local MinimapIconRuntime = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.MinimapIconRuntime")

-- Both icon runtimes hand the icons a live hide-from-default-chat getter so
-- the tooltip reply hint tracks the setting.
return function()
  local settings = { hideFromDefaultChat = false }
  local accountState = { settings = settings }
  local toggleOptions, minimapOptions
  IconRuntime.Create({
    accountState = accountState,
    characterState = { icon = {} },
    toggleIcon = {
      Create = function(_, options)
        toggleOptions = options
        return {}
      end,
    },
  })
  MinimapIconRuntime.Create({
    accountState = accountState,
    characterState = {},
    minimapIcon = {
      Create = function(_, options)
        minimapOptions = options
        return {}
      end,
    },
    dataBroker = { Register = function() end },
  })

  for name, options in pairs({ toggle = toggleOptions, minimap = minimapOptions }) do
    -- test_runtime_passes_hide_from_default_chat_getter
    assert(type(options.getHideFromDefaultChat) == "function", name .. " gets the getter")
    settings.hideFromDefaultChat = false
    assert(options.getHideFromDefaultChat() == false, name .. " off")
    settings.hideFromDefaultChat = true
    assert(options.getHideFromDefaultChat() == true, name .. " follows the live setting")
  end
end
