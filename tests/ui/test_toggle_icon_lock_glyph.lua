local FakeUI = require("tests.helpers.fake_ui")
local LockGlyph = require("WhisperMessenger.UI.ToggleIcon.LockGlyph")

return function()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)

  local function build(locked)
    local frame = factory.CreateFrame("Button", nil, parent)
    local state = { locked = locked }
    local hover = { active = false }
    local lock = LockGlyph.Create(frame, 40, {
      isLocked = function()
        return state.locked
      end,
      hover = hover,
    })
    return frame, lock, hover, state
  end

  -- test_glyph_shows_only_while_hovered_and_locked

  do
    local _, lock, hover = build(true)
    assert(lock.texture.shown == false, "test_glyph_shows_only_while_hovered_and_locked: hidden before hover")

    hover.active = true
    lock.syncVisibility()
    assert(lock.texture.shown == true, "test_glyph_shows_only_while_hovered_and_locked: shown while hovered and locked")

    hover.active = false
    lock.syncVisibility()
    assert(lock.texture.shown == false, "test_glyph_shows_only_while_hovered_and_locked: hidden after hover ends")
  end

  -- test_refresh_toggles_movable_with_lock

  do
    local frame, lock, _, state = build(true)
    lock.refresh()
    assert(frame:IsMovable() == false, "test_refresh_toggles_movable_with_lock: locked icon should not be movable")

    state.locked = false
    lock.refresh()
    assert(frame:IsMovable() == true, "test_refresh_toggles_movable_with_lock: unlocked icon should be movable")
  end

  -- test_apply_layout_scales_with_minimum_size

  do
    local _, lock = build(false)
    assert(lock.texture.width == 18, "test_apply_layout_scales_with_minimum_size: 40 * 0.45 should floor to 18, got " .. tostring(lock.texture.width))

    lock.applyLayout(10)
    assert(
      lock.texture.width == 8,
      "test_apply_layout_scales_with_minimum_size: glyph should never shrink below 8, got " .. tostring(lock.texture.width)
    )
  end
end
