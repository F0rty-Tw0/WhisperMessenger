local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- One glow, two reasons for it: unread whispers, and an external preview that
-- asked to pulse. Each call recomputes the whole rule, so stopping one source
-- never stops the other. The external glow obeys the pulse setting only.
local PulseState = {}

function PulseState.New(options)
  local unreadWants = false
  local external = false
  local state = {}

  local function externalWants()
    if not external or (options.getBadgePulse and not options.getBadgePulse()) then
      return false
    end
    return options.isExternalShown() == true
  end

  function state.refresh()
    if unreadWants or externalWants() then
      options.start()
    else
      options.stop()
    end
  end

  function state.setUnreadWants(wants)
    unreadWants = wants and true or false
    state.refresh()
  end

  function state.setExternal(on)
    external = on == true
    state.refresh()
  end

  return state
end

ns.ToggleIconPulseState = PulseState
return PulseState
