local RelayoutController = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.RelayoutController")

local function build(overrides)
  local env = { widths = {} }
  local options = {
    layoutBuilder = {
      Relayout = function()
        return { contactsWidth = 50, expandedContactsWidth = 260, contentWidth = 600 }
      end,
    },
    layout = {},
    setContactsWidth = function(width)
      env.widths[#env.widths + 1] = width
    end,
  }
  for k, v in pairs(overrides or {}) do
    options[k] = v
  end
  env.controller = RelayoutController.Create(options)
  return env
end

return function()
  -- test_relayout_reports_the_live_contacts_width
  do
    local seen = {}
    local env = build({
      onContactsWidth = function(width)
        seen[#seen + 1] = width
      end,
    })
    env.controller.relayoutWindow(900, 560)
    assert(seen[1] == 50, "reports the live width (the rail), not the expanded one")
    assert(#seen == 1, "once per relayout")
  end

  -- test_relayout_without_the_callback_still_works
  do
    local env = build()
    env.controller.relayoutWindow(900, 560)
    assert(env.widths[1] == 260, "setContactsWidth still gets the expanded width")
  end
end
