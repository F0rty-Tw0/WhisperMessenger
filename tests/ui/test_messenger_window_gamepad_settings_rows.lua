local FakeUI = require("tests.helpers.fake_ui")
local FakeGamepad = require("tests.helpers.fake_gamepad")
local GamepadNav = require("WhisperMessenger.UI.MessengerWindow.WindowScripts.Frame.GamepadNav")
local GamepadSettings = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.GamepadSettings")

local TOGGLE_EVENT = "INPUT_DEVICE_INTERFACE_TRANSITION"

-- Gives a fake frame a screen rect, y up as in WoW.
local function place(frame, left, top, width, height)
  local rect = { GetLeft = left, GetRight = left + width, GetTop = top, GetBottom = top - height }
  for method, value in pairs(rect) do
    rawset(frame, method, function()
      return value
    end)
  end
  return frame
end

-- A settings page in a 400-tall view (screen y 600 to 200): a checkbox, two
-- slider pairs, a dropdown and a second checkbox below the view. Left of it
-- the page list, its open page's tab scrolled out above that list's view.
local function page(fn)
  local env = FakeGamepad.New()
  local savedInputUtil = rawget(_G, "InputUtil")
  local state = { on = true, menuOpen = false }
  env.install()
  rawset(_G, "InputUtil", {
    IsGamepadUIEnabled = function()
      return state.on
    end,
  })
  local ok, err = pcall(function()
    local factory = FakeUI.NewFactory()
    local parent = factory.CreateFrame("Frame", "UIParent", nil)
    local scrollFrame = place(factory.CreateFrame("ScrollFrame", nil, parent), 360, 600, 320, 400)
    scrollFrame:SetSize(320, 400)
    local content = factory.CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(320, 1000)
    scrollFrame:SetScrollChild(content)
    local panel = factory.CreateFrame("Frame", nil, content)
    local menuFrame = place(factory.CreateFrame("ScrollFrame", nil, parent), 140, 600, 190, 400)
    menuFrame:SetSize(190, 400)
    local menuContent = factory.CreateFrame("Frame", nil, menuFrame)
    menuContent:SetSize(190, 1000)
    menuFrame:SetScrollChild(menuContent)
    local tab = place(factory.CreateFrame("Button", nil, menuContent), 150, 650, 170, 40)
    for _, frame in ipairs({ parent, scrollFrame, content, panel, menuFrame, menuContent, tab }) do
      frame:Show()
    end
    local function button(left, top, width, height)
      local made = place(factory.CreateFrame("Button", nil, panel), left, top, width, height)
      made:Show()
      return made
    end
    local ui = {
      -- Built out of screen order on purpose.
      dropdown = button(368, 350, 298, 32),
      check = button(640, 580, 24, 24),
      minus1 = button(368, 520, 20, 20),
      plus1 = button(644, 520, 20, 20),
      minus2 = button(368, 440, 20, 20),
      plus2 = button(644, 440, 20, 20),
      below = button(640, 190, 24, 24),
      panel = panel,
      scrollFrame = scrollFrame,
      tab = tab,
      menuFrame = menuFrame,
      newButton = button,
      newFrame = function(frameParent)
        local made = factory.CreateFrame("Frame", nil, frameParent or panel)
        made:Show()
        return made
      end,
      newButtonIn = function(frameParent, left, top, width, height)
        local made = place(factory.CreateFrame("Button", nil, frameParent), left, top, width, height)
        made:Show()
        return made
      end,
    }
    local window = factory.CreateFrame("Frame", "WhisperMessengerWindow", nil)
    local nav = GamepadNav.New(window, env.deps())
    local settings = {
      contentScrollView = { scrollFrame = scrollFrame, content = content, scrollBar = factory.CreateFrame("Slider", nil, parent) },
      menuScrollView = { scrollFrame = menuFrame, content = menuContent, scrollBar = factory.CreateFrame("Slider", nil, parent) },
      activeTab = function()
        return state.tab
      end,
      optionsPanel = factory.CreateFrame("Frame", nil, parent),
      panels = { panel, false },
      createFrame = env.createFrame,
      after = env.after,
      isMenuOpen = function()
        return state.menuOpen
      end,
    }
    state.tab = tab
    ui.onTargetsChanged, ui.onMenuToggled = GamepadSettings.Attach(nav, settings)
    ui.optionsPanel = settings.optionsPanel
    env.flush()
    fn(env, ui, state)
  end)
  rawset(_G, "InputUtil", savedInputUtil)
  env.uninstall()
  assert(ok, err)
end

return function()
  -- test_down_from_either_slider_button_reaches_the_dropdown
  page(function(env, ui)
    assert(env.overrideFor(ui.minus2, "DOWN") == ui.dropdown, "− goes down to the dropdown")
    assert(env.overrideFor(ui.plus2, "DOWN") == ui.dropdown, "+ goes down to the dropdown")
  end)

  -- test_up_and_down_between_slider_rows_keep_the_column
  page(function(env, ui)
    assert(env.overrideFor(ui.minus1, "DOWN") == ui.minus2 and env.overrideFor(ui.plus1, "DOWN") == ui.plus2, "down")
    assert(env.overrideFor(ui.minus2, "UP") == ui.minus1 and env.overrideFor(ui.plus2, "UP") == ui.plus1, "up")
  end)

  -- test_checkbox_and_the_row_under_it
  page(function(env, ui)
    assert(env.overrideFor(ui.check, "DOWN") == ui.plus1, "the + sits under the checkbox")
    assert(env.overrideFor(ui.minus1, "UP") == ui.check and env.overrideFor(ui.plus1, "UP") == ui.check, "both go up to it")
  end)

  -- test_dropdown_under_a_slider_pair_goes_up_to_the_left_button
  page(function(env, ui)
    assert(env.overrideFor(ui.dropdown, "UP") == ui.minus2, "leftmost of two equally near")
  end)

  -- test_a_row_scrolled_out_of_view_is_still_next
  page(function(env, ui)
    assert(env.overrideFor(ui.dropdown, "DOWN") == ui.below, "below the view")
  end)

  -- test_first_row_up_is_left_to_the_game
  page(function(env, ui)
    assert(env.overrideFor(ui.check, "UP") == nil, "up leaves the page, to the title bar")
  end)

  -- test_last_row_down_stays_put
  page(function(env, ui)
    assert(env.overrideFor(ui.below, "DOWN") == ui.below, "no jump to the buttons under the settings list")
  end)

  -- test_left_and_right_stay_in_the_row
  page(function(env, ui)
    assert(env.overrideFor(ui.plus1, "LEFT") == ui.minus1, "left on + goes to its −")
    assert(env.overrideFor(ui.minus1, "RIGHT") == ui.plus1, "right on − goes to its +")
  end)

  -- test_left_from_the_leftmost_control_goes_to_the_open_pages_tab
  page(function(env, ui)
    for _, name in ipairs({ "check", "minus1", "minus2", "dropdown", "below" }) do
      assert(env.overrideFor(ui[name], "LEFT") == ui.tab, name .. " goes to the open page in the list")
    end
  end)

  -- test_right_from_the_rightmost_control_stays_put
  page(function(env, ui)
    assert(env.overrideFor(ui.plus1, "RIGHT") == ui.plus1 and env.overrideFor(ui.check, "RIGHT") == ui.check, "never a control of another row")
  end)

  -- test_left_follows_the_open_page
  page(function(env, ui, state)
    state.tab = nil
    ui.onTargetsChanged()
    env.flush()
    assert(env.overrideFor(ui.check, "LEFT") == nil, "no open page known: the game's own search")
  end)

  -- test_a_jump_to_a_tab_out_of_view_scrolls_the_page_list
  page(function(env, ui)
    ui.menuFrame:SetVerticalScroll(300)
    env.left(ui.minus1, "LEFT")
    -- View middle 400, tab middle 630: 230 further up.
    assert(ui.menuFrame:GetVerticalScroll() == 70, "list scrolled, got " .. ui.menuFrame:GetVerticalScroll())
    assert(ui.scrollFrame:GetVerticalScroll() == 0, "the page stays")
  end)

  -- test_plain_frames_hidden_buttons_and_sliders_are_no_stops
  page(function(env, ui)
    place(ui.newFrame(), 368, 480, 298, 20)
    ui.newButton(368, 470, 298, 20):Hide()
    local slider = ui.newButton(400, 480, 200, 20)
    slider._wmPadStep = function() end
    ui.onTargetsChanged()
    env.flush()
    assert(env.overrideFor(ui.minus1, "DOWN") == ui.minus2, "still the next slider row")
  end)

  -- test_a_child_of_a_hidden_group_is_no_stop
  page(function(env, ui)
    local group = ui.newFrame()
    ui.newButtonIn(group, 368, 470, 298, 20)
    group:Hide()
    ui.onTargetsChanged()
    env.flush()
    assert(env.overrideFor(ui.minus1, "DOWN") == ui.minus2, "its group is hidden")
  end)

  -- test_a_button_without_a_rect_yet_is_skipped
  page(function(env, ui)
    local pending = ui.newButton(368, 470, 298, 20)
    rawset(pending, "GetTop", function()
      return nil
    end)
    ui.onTargetsChanged()
    env.flush()
    assert(env.overrideFor(ui.minus1, "DOWN") == ui.minus2, "not laid out yet")
  end)

  -- test_a_row_that_hides_leaves_the_chain
  page(function(env, ui)
    ui.minus2:Hide()
    ui.plus2:Hide()
    ui.onTargetsChanged()
    env.flush()
    assert(env.overrideFor(ui.minus1, "DOWN") == ui.dropdown, "jumped over")
    assert(env.overrideFor(ui.minus2, "DOWN") == nil and env.overrideFor(ui.minus2, "UP") == nil, "its own targets are cleared")
  end)

  -- test_an_open_drop_down_list_frees_the_chain
  page(function(env, ui, state)
    state.menuOpen = true
    ui.onMenuToggled()
    env.flush()
    assert(env.overrideFor(ui.dropdown, "DOWN") == nil, "down goes into the open list")
    state.menuOpen = false
    ui.onMenuToggled()
    env.flush()
    assert(env.overrideFor(ui.dropdown, "DOWN") == ui.below, "chained again once it closes")
  end)

  -- test_turning_the_pad_ui_off_frees_the_chain
  page(function(env, ui, state)
    state.on = false
    env.fire(TOGGLE_EVENT)
    env.flush()
    assert(env.overrideFor(ui.minus2, "DOWN") == nil and env.overrideFor(ui.minus2, "LEFT") == nil, "no chain with the pad UI off")
    assert(env.overrideFor(ui.minus2, "UP") == nil and env.overrideFor(ui.minus2, "RIGHT") == nil, "in any direction")
  end)

  -- test_showing_the_settings_pane_rechains
  page(function(env, ui)
    place(ui.dropdown, 368, 100, 298, 32)
    ui.optionsPanel:Hide()
    ui.optionsPanel:Show()
    env.flush()
    assert(env.overrideFor(ui.minus2, "DOWN") == ui.below, "new screen order")
  end)

  -- test_resizing_the_settings_pane_rechains
  page(function(env, ui)
    place(ui.dropdown, 368, 100, 298, 32)
    ui.optionsPanel._hookScripts.OnSizeChanged[1](ui.optionsPanel)
    env.flush()
    assert(env.overrideFor(ui.minus2, "DOWN") == ui.below, "new screen order")
  end)

  -- test_a_jump_out_of_view_scrolls_the_target_to_the_middle
  page(function(env, ui)
    env.left(ui.dropdown, "DOWN")
    -- View middle 400, target middle 178: 222 further down.
    assert(ui.scrollFrame:GetVerticalScroll() == 222, "got " .. ui.scrollFrame:GetVerticalScroll())
  end)

  -- test_a_jump_to_a_visible_control_does_not_scroll
  page(function(env, ui)
    env.left(ui.minus1, "DOWN")
    assert(ui.scrollFrame:GetVerticalScroll() == 0, "already in view")
  end)

  -- test_a_jump_up_to_a_control_cut_off_at_the_top_scrolls
  page(function(env, ui)
    ui.scrollFrame:SetVerticalScroll(300)
    place(ui.check, 640, 610, 24, 24)
    env.left(ui.minus1, "UP")
    -- Target middle 598 is 198 above the view middle.
    assert(ui.scrollFrame:GetVerticalScroll() == 102, "got " .. ui.scrollFrame:GetVerticalScroll())
  end)
end
