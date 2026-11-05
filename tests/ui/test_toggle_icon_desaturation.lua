local Desaturation = require("WhisperMessenger.UI.ToggleIcon.Desaturation")

local function createDesaturation(setting)
  return Desaturation.Create({
    getIconDesaturated = function()
      return setting.enabled
    end,
  })
end

return function()
  -- test_idle_with_the_setting_on_and_nothing_unread
  do
    local desaturation = createDesaturation({ enabled = true })

    assert(desaturation.isActive() == true, "idle with the setting on")
  end

  -- test_not_idle_with_unread
  do
    local desaturation = createDesaturation({ enabled = true })

    desaturation.update(2)

    assert(desaturation.isActive() == false, "not idle with unread")
  end

  -- test_unread_count_stays_until_the_next_update
  do
    local desaturation = createDesaturation({ enabled = true })
    desaturation.update(2)
    desaturation.isActive()

    assert(desaturation.isActive() == false, "reading keeps the unread count")

    desaturation.update(0)

    assert(desaturation.isActive() == true, "idle again once the count is zero")
  end

  -- test_not_idle_with_the_setting_off
  do
    local setting = { enabled = true }
    local desaturation = createDesaturation(setting)
    desaturation.update(0)

    setting.enabled = false

    assert(not desaturation.isActive(), "setting off")
  end
end
