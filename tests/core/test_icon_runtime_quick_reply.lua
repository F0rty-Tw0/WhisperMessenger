local IconRuntime = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.IconRuntime")
local MinimapIconRuntime = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.MinimapIconRuntime")

-- Both icon runtimes hand their icon the shared quickReply table, and the
-- widget's first preview carries the preview table as meta.
return function()
  local quickReply = {}
  local preview = { senderName = "Jaina", messageText = "hi", classTag = "MAGE", conversationKey = "wow::jaina", sentAt = 500 }
  local toggleOptions, minimapOptions, initialMeta
  IconRuntime.Create({
    accountState = { settings = {} },
    characterState = { icon = {} },
    quickReply = quickReply,
    buildLatestIncomingPreview = function()
      return preview
    end,
    toggleIcon = {
      Create = function(_, options)
        toggleOptions = options
        return {
          setIncomingPreview = function(_sender, _text, _class, meta)
            initialMeta = meta
          end,
        }
      end,
    },
  })
  MinimapIconRuntime.Create({
    accountState = { settings = {} },
    characterState = {},
    quickReply = quickReply,
    minimapIcon = {
      Create = function(_, options)
        minimapOptions = options
        return {}
      end,
    },
    dataBroker = { Register = function() end },
  })

  -- test_widget_icon_gets_the_quick_reply_table
  assert(toggleOptions.quickReply == quickReply, "widget icon gets the quickReply table")
  -- test_widget_initial_preview_carries_meta
  assert(initialMeta == preview, "the widget's first preview gets the preview table 4th")
  -- test_minimap_icon_gets_the_quick_reply_table
  assert(minimapOptions.quickReply == quickReply, "minimap icon gets the quickReply table")
end
