local KeybindHints = require("WhisperMessenger.UI.Shared.KeybindHints")
local Localization = require("WhisperMessenger.Locale.Localization")

-- Icon tooltips list the keys that open WhisperMessenger: the toggle binding
-- always, the reply key only while it is routed to the messenger.

local function newTooltip()
  local tooltip = { lines = {} }
  function tooltip:AddLine(text, r, g, b)
    self.lines[#self.lines + 1] = { text = text, r = r, g = g, b = b }
  end
  return tooltip
end

local function stubBindings(map)
  rawset(_G, "GetBindingKey", function(action)
    local keys = map[action] or {}
    return keys[1], keys[2]
  end)
  rawset(_G, "GetBindingText", function(key)
    return "<" .. key .. ">"
  end)
end

return function()
  Localization.Configure({ language = "enUS" })

  -- test_toggle_binding_shown_with_display_text_in_grey
  stubBindings({ WHISPERMESSENGER_TOGGLE = { "CTRL-O" }, REPLY = { "R" } })
  local tooltip = newTooltip()
  KeybindHints.AddToTooltip(tooltip, false)
  assert(#tooltip.lines == 1, "only the toggle line without reply routing, got " .. #tooltip.lines)
  assert(tooltip.lines[1].text == "Open/close: <CTRL-O>", "toggle hint, got " .. tostring(tooltip.lines[1].text))
  local line = tooltip.lines[1]
  assert(line.r == line.g and line.g == line.b and line.r < 1, "hint line is grey")

  -- test_reply_binding_shown_when_routed_to_messenger
  tooltip = newTooltip()
  KeybindHints.AddToTooltip(tooltip, true)
  assert(tooltip.lines[2] and tooltip.lines[2].text == "Reply: <R>", "reply hint when routed")

  -- test_multiple_keys_joined
  stubBindings({ WHISPERMESSENGER_TOGGLE = { "CTRL-O", "ALT-W" } })
  tooltip = newTooltip()
  KeybindHints.AddToTooltip(tooltip, true)
  assert(tooltip.lines[1].text == "Open/close: <CTRL-O>, <ALT-W>", "keys joined, got " .. tostring(tooltip.lines[1].text))

  -- test_unbound_actions_add_no_lines
  stubBindings({})
  tooltip = newTooltip()
  KeybindHints.AddToTooltip(tooltip, true)
  assert(#tooltip.lines == 0, "unbound actions omitted")

  -- test_raw_key_without_binding_text_api
  stubBindings({ WHISPERMESSENGER_TOGGLE = { "CTRL-O" } })
  rawset(_G, "GetBindingText", nil)
  tooltip = newTooltip()
  KeybindHints.AddToTooltip(tooltip, false)
  assert(tooltip.lines[1].text == "Open/close: CTRL-O", "raw key fallback")

  rawset(_G, "GetBindingKey", nil)
end
