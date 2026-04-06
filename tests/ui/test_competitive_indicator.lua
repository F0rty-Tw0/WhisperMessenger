local FakeUI = require("tests.helpers.fake_ui")
local CompetitiveIndicator = require("WhisperMessenger.UI.ToggleIcon.CompetitiveIndicator")

return function()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)

  -- -----------------------------------------------------------------------
  -- test_indicator_hidden_by_default
  -- -----------------------------------------------------------------------
  do
    local result = CompetitiveIndicator.Create(factory, parent)

    assert(result.frame ~= nil, "test_indicator_hidden_by_default: frame should exist")
    assert(
      result.frame.shown == false,
      "test_indicator_hidden_by_default: indicator should be hidden by default, got shown="
        .. tostring(result.frame.shown)
    )
  end

  -- -----------------------------------------------------------------------
  -- test_indicator_shown_when_set_active_true
  -- -----------------------------------------------------------------------
  do
    local result = CompetitiveIndicator.Create(factory, parent)

    result.setActive(true)

    assert(result.frame.shown == true, "test_indicator_shown_when_set_active_true: indicator should be visible")
  end

  -- -----------------------------------------------------------------------
  -- test_indicator_hidden_when_set_active_false
  -- -----------------------------------------------------------------------
  do
    local result = CompetitiveIndicator.Create(factory, parent)

    result.setActive(true)
    result.setActive(false)

    assert(
      result.frame.shown == false,
      "test_indicator_hidden_when_set_active_false: indicator should be hidden after deactivation"
    )
  end

  -- -----------------------------------------------------------------------
  -- test_indicator_has_lock_texture
  -- -----------------------------------------------------------------------
  do
    local result = CompetitiveIndicator.Create(factory, parent)

    assert(result.icon ~= nil, "test_indicator_has_lock_texture: icon texture should exist")
    assert(result.icon.texturePath ~= nil, "test_indicator_has_lock_texture: icon should have a texture set")
  end

  -- -----------------------------------------------------------------------
  -- test_indicator_has_background
  -- -----------------------------------------------------------------------
  do
    local result = CompetitiveIndicator.Create(factory, parent)

    assert(result.background ~= nil, "test_indicator_has_background: background texture should exist")
  end

  -- -----------------------------------------------------------------------
  -- test_set_active_is_idempotent
  -- -----------------------------------------------------------------------
  do
    local result = CompetitiveIndicator.Create(factory, parent)

    result.setActive(true)
    result.setActive(true)
    assert(result.frame.shown == true, "test_set_active_is_idempotent: repeated true should keep indicator visible")

    result.setActive(false)
    result.setActive(false)
    assert(result.frame.shown == false, "test_set_active_is_idempotent: repeated false should keep indicator hidden")
  end
end
