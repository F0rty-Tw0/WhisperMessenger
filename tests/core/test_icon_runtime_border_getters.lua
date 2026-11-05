local IconRuntime = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.IconRuntime")

-- The widget runtime hands the widget live border getters; an unset setting
-- reads on. The minimap ring is always gold, so only the widget gets them.
return function()
  local settings = {}
  local toggleOptions
  IconRuntime.Create({
    accountState = { settings = settings },
    characterState = { icon = {} },
    toggleIcon = {
      Create = function(_, options)
        toggleOptions = options
        return {}
      end,
    },
  })

  local getters = { getIconBorder = "iconBorder", getIconBorderThemed = "iconBorderThemed" }

  -- test_runtime_passes_the_border_getters
  do
    for getter in pairs(getters) do
      assert(type(toggleOptions[getter]) == "function", "test_runtime_passes_the_border_getters: " .. getter .. " is passed")
    end
  end

  -- test_unset_border_setting_reads_on
  do
    for getter, key in pairs(getters) do
      settings[key] = nil
      assert(toggleOptions[getter]() == true, "test_unset_border_setting_reads_on: " .. getter .. " reads on when unset")
    end
  end

  -- test_border_getter_follows_the_live_setting
  do
    for getter, key in pairs(getters) do
      settings[key] = false
      assert(toggleOptions[getter]() == false, "test_border_getter_follows_the_live_setting: " .. getter .. " off")
      settings[key] = true
      assert(toggleOptions[getter]() == true, "test_border_getter_follows_the_live_setting: " .. getter .. " on")
    end
  end
end
