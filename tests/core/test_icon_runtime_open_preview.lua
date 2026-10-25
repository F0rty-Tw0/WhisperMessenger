local IconRuntime = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.IconRuntime")
local MinimapIconRuntime = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.MinimapIconRuntime")

-- Both icon runtimes hand their icon the open-the-previewed-whisper callback.
return function()
  local function onOpenPreview() end
  local toggleOptions, minimapOptions
  IconRuntime.Create({
    accountState = { settings = {} },
    characterState = { icon = {} },
    onOpenPreview = onOpenPreview,
    toggleIcon = {
      Create = function(_, options)
        toggleOptions = options
        return {}
      end,
    },
  })
  MinimapIconRuntime.Create({
    accountState = { settings = {} },
    characterState = {},
    onOpenPreview = onOpenPreview,
    minimapIcon = {
      Create = function(_, options)
        minimapOptions = options
        return {}
      end,
    },
    dataBroker = { Register = function() end },
  })

  -- test_widget_icon_gets_the_open_preview_callback
  assert(toggleOptions.onOpenPreview == onOpenPreview, "widget icon opens the previewed whisper")
  -- test_minimap_icon_gets_the_open_preview_callback
  assert(minimapOptions.onOpenPreview == onOpenPreview, "minimap icon opens the previewed whisper")
end
