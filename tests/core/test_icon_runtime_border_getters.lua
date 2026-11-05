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
  local runtimes = { toggle = toggleOptions, minimap = minimapOptions }

  -- Calls check(label, getterFn, key) for both getters of both runtimes.
  local function eachGetter(check)
    for name, options in pairs(runtimes) do
      for getter, key in pairs(getters) do
        check(name .. " " .. getter, options[getter], key)
      end
    end
  end

  -- test_runtime_passes_the_border_getters
  do
    eachGetter(function(label, getterFn)
      assert(type(getterFn) == "function", "test_runtime_passes_the_border_getters: " .. label .. " is passed")
    end)
  end

  -- test_unset_border_setting_reads_on
  do
    eachGetter(function(label, getterFn, key)
      settings[key] = nil
      assert(getterFn() == true, "test_unset_border_setting_reads_on: " .. label .. " reads on when unset")
    end)
  end

  -- test_border_getter_follows_the_live_setting
  do
    eachGetter(function(label, getterFn, key)
      settings[key] = false
      assert(getterFn() == false, "test_border_getter_follows_the_live_setting: " .. label .. " off")
      settings[key] = true
      assert(getterFn() == true, "test_border_getter_follows_the_live_setting: " .. label .. " on")
    end)
  end
end
