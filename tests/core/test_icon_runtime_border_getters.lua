local IconRuntime = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.IconRuntime")
local MinimapIconRuntime = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.MinimapIconRuntime")

-- Both icon runtimes hand the icons live border getters; an unset setting
-- reads on.
return function()
  local settings = {}
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

  local getters = { getIconBorder = "iconBorder", getIconBorderThemed = "iconBorderThemed" }
  for name, options in pairs({ toggle = toggleOptions, minimap = minimapOptions }) do
    for getter, key in pairs(getters) do
      local label = name .. " " .. getter
      -- test_runtime_passes_the_border_getters
      assert(type(options[getter]) == "function", label .. " is passed")

      -- test_unset_border_setting_reads_on
      settings[key] = nil
      assert(options[getter]() == true, label .. " reads on when unset")

      -- test_border_getter_follows_the_live_setting
      settings[key] = false
      assert(options[getter]() == false, label .. " off")
      settings[key] = true
      assert(options[getter]() == true, label .. " on")
    end
  end
end
