local LifecycleHandlers = require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers")
local Localization = require("WhisperMessenger.Locale.Localization")

-- The lock-state machinery announces waiting queued messages once, when a
-- PvP match / encounter / key restriction lifts.
return function()
  Localization.Configure({ language = "enUS" })
  local lines = {}
  rawset(_G, "DEFAULT_CHAT_FRAME", {
    AddMessage = function(_, text)
      lines[#lines + 1] = text
    end,
  })
  local Bootstrap = {}
  Bootstrap.runtime = {
    store = { conversations = { k = { messages = { { direction = "out", kind = "user", text = "gg", delivery = "queued" } } } } },
    isCompetitiveContent = function()
      return Bootstrap._inCompetitiveContent == true
    end,
    refreshWindow = function() end,
  }
  local PVP_MATCH, ACTIVE, INACTIVE = 3, 2, 0

  -- test_restriction_lift_prints_the_queued_notice_once
  LifecycleHandlers.Handle(Bootstrap, "ADDON_RESTRICTION_STATE_CHANGED", {}, PVP_MATCH, ACTIVE)
  assert(#lines == 0, "nothing while the match runs")
  LifecycleHandlers.Handle(Bootstrap, "ADDON_RESTRICTION_STATE_CHANGED", {}, PVP_MATCH, INACTIVE)
  assert(#lines == 1, "one line when the lock lifts, got " .. #lines)
  assert(string.find(lines[1], "1 queued message is waiting", 1, true), lines[1])
  LifecycleHandlers.Handle(Bootstrap, "ADDON_RESTRICTION_STATE_CHANGED", {}, PVP_MATCH, INACTIVE)
  assert(#lines == 1, "no repeat")
  rawset(_G, "DEFAULT_CHAT_FRAME", nil)
end
