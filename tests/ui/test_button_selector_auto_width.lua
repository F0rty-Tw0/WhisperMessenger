local FakeUI = require("tests.helpers.fake_ui")
local ButtonSelector = require("WhisperMessenger.UI.MessengerWindow.AppearanceSettings.ButtonSelector")

return function()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)

  -- -----------------------------------------------------------------------
  -- test_buttons_distribute_evenly_across_row
  -- -----------------------------------------------------------------------
  do
    local selector = ButtonSelector.Create(factory, parent, {
      labelText = "Test",
      optionsList = {
        { key = "a", label = "Alpha" },
        { key = "b", label = "Beta" },
        { key = "c", label = "Gamma" },
      },
      fallbackKey = "a",
      initial = "a",
      rowWidth = 280,
      buttonSpacing = 8,
    })

    -- 3 buttons, 2 gaps of 8 = 16px spacing, (280 - 16) / 3 = 88
    local expected = math.floor((280 - 2 * 8) / 3)
    for i, btn in ipairs(selector.buttons) do
      assert(
        btn.width == expected,
        "test_even_distribute: button " .. i .. " should be " .. expected .. "px, got: " .. tostring(btn.width)
      )
    end
  end

  -- -----------------------------------------------------------------------
  -- test_two_buttons_fill_row
  -- -----------------------------------------------------------------------
  do
    local selector = ButtonSelector.Create(factory, parent, {
      labelText = "Test",
      optionsList = {
        { key = "a", label = "Yes" },
        { key = "b", label = "No" },
      },
      fallbackKey = "a",
      initial = "a",
      rowWidth = 280,
      buttonSpacing = 8,
    })

    -- 2 buttons, 1 gap of 8, (280 - 8) / 2 = 136
    local expected = math.floor((280 - 8) / 2)
    assert(
      selector.buttons[1].width == expected,
      "test_two_buttons: should be " .. expected .. "px, got: " .. tostring(selector.buttons[1].width)
    )
  end

  -- -----------------------------------------------------------------------
  -- test_five_buttons_fill_row
  -- -----------------------------------------------------------------------
  do
    local selector = ButtonSelector.Create(factory, parent, {
      labelText = "Test",
      optionsList = {
        { key = "a", label = "One" },
        { key = "b", label = "Two" },
        { key = "c", label = "Three" },
        { key = "d", label = "Four" },
        { key = "e", label = "Five" },
      },
      fallbackKey = "a",
      initial = "a",
      rowWidth = 280,
      buttonSpacing = 8,
    })

    -- 5 buttons, 4 gaps of 8 = 32, (280 - 32) / 5 = 49
    local expected = math.floor((280 - 4 * 8) / 5)
    assert(
      selector.buttons[1].width == expected,
      "test_five_buttons: should be " .. expected .. "px, got: " .. tostring(selector.buttons[1].width)
    )
  end

  -- -----------------------------------------------------------------------
  -- test_explicit_button_width_overrides_distribution
  -- -----------------------------------------------------------------------
  do
    local selector = ButtonSelector.Create(factory, parent, {
      labelText = "Test",
      optionsList = {
        { key = "a", label = "Alpha" },
        { key = "b", label = "Beta" },
      },
      fallbackKey = "a",
      initial = "a",
      buttonWidth = 50,
    })

    assert(
      selector.buttons[1].width == 50,
      "test_explicit_width: should be 50, got: " .. tostring(selector.buttons[1].width)
    )
    assert(
      selector.buttons[2].width == 50,
      "test_explicit_width: should be 50, got: " .. tostring(selector.buttons[2].width)
    )
  end

  -- -----------------------------------------------------------------------
  -- test_max_per_row_wraps_to_second_row
  -- -----------------------------------------------------------------------
  do
    local selector = ButtonSelector.Create(factory, parent, {
      labelText = "Colors",
      optionsList = {
        { key = "a", label = "Default" },
        { key = "b", label = "White" },
        { key = "c", label = "Gold" },
        { key = "d", label = "Blue" },
        { key = "e", label = "Green" },
      },
      fallbackKey = "a",
      initial = "a",
      rowWidth = 280,
      buttonSpacing = 8,
      maxPerRow = 3,
    })

    -- Row 1: 3 buttons sized to (280 - 2*8) / 3 = 88
    local row1Width = math.floor((280 - 2 * 8) / 3)
    for i = 1, 3 do
      assert(
        selector.buttons[i].width == row1Width,
        "test_max_per_row: row1 button "
          .. i
          .. " should be "
          .. row1Width
          .. ", got: "
          .. tostring(selector.buttons[i].width)
      )
    end

    -- Row 2: 2 buttons sized to (280 - 1*8) / 2 = 136
    local row2Width = math.floor((280 - 1 * 8) / 2)
    for i = 4, 5 do
      assert(
        selector.buttons[i].width == row2Width,
        "test_max_per_row: row2 button "
          .. i
          .. " should be "
          .. row2Width
          .. ", got: "
          .. tostring(selector.buttons[i].width)
      )
    end

    -- Row 2 buttons should be anchored below row 1 (TOPLEFT of first row2 button)
    local btn4 = selector.buttons[4]
    assert(btn4.point ~= nil, "test_max_per_row: button 4 should have an anchor point")
    assert(
      btn4.point[1] == "TOPLEFT",
      "test_max_per_row: button 4 anchor should be TOPLEFT, got: " .. tostring(btn4.point[1])
    )
  end

  -- -----------------------------------------------------------------------
  -- test_max_per_row_row_height_includes_both_rows
  -- -----------------------------------------------------------------------
  do
    local selector = ButtonSelector.Create(factory, parent, {
      labelText = "Colors",
      optionsList = {
        { key = "a", label = "A" },
        { key = "b", label = "B" },
        { key = "c", label = "C" },
        { key = "d", label = "D" },
      },
      fallbackKey = "a",
      initial = "a",
      maxPerRow = 3,
    })

    -- 4 items with maxPerRow=3 → 2 rows. Row height should be taller than single-row.
    local singleRowSelector = ButtonSelector.Create(factory, parent, {
      labelText = "Single",
      optionsList = {
        { key = "a", label = "A" },
        { key = "b", label = "B" },
      },
      fallbackKey = "a",
      initial = "a",
    })

    assert(
      selector.row.height > singleRowSelector.row.height,
      "test_row_height: multi-row ("
        .. tostring(selector.row.height)
        .. ") should be taller than single-row ("
        .. tostring(singleRowSelector.row.height)
        .. ")"
    )
  end

  print("  All button selector auto-width tests passed")
end
