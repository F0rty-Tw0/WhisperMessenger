local Competitive = require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers.Competitive")

-- Pop-up cards never stay up into combat.

return function()
  -- test_combat_start_clears_whisper_cards
  do
    local cleared = 0
    local Bootstrap = {
      runtime = {
        accountState = { settings = {} },
        clearWhisperToasts = function()
          cleared = cleared + 1
        end,
      },
    }
    Competitive.handleCombatStart(Bootstrap)
    assert(cleared == 1, "entering combat clears the cards, got " .. cleared)
  end

  -- test_combat_start_without_cards_is_harmless
  do
    Competitive.handleCombatStart({ runtime = { accountState = { settings = {} } } })
    Competitive.handleCombatStart({})
  end
end
