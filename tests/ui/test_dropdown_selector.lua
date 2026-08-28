local FakeUI = require("tests.helpers.fake_ui")
local dropdownLoaded, DropdownSelector = pcall(require, "WhisperMessenger.UI.MessengerWindow.AppearanceSettings.DropdownSelector")
assert(dropdownLoaded, "test_dropdown_module: DropdownSelector module contract is required: " .. tostring(DropdownSelector))

return function()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)

  -- test_initial_and_fallback_labels

  do
    local options = {
      { key = "default", label = "Default" },
      { key = "open_sans", label = "Open Sans" },
    }
    local selected = DropdownSelector.Create(factory, parent, {
      labelText = "Font Family",
      optionsList = options,
      fallbackKey = "default",
      initial = "open_sans",
    })
    local fallback = DropdownSelector.Create(factory, parent, {
      labelText = "Font Family",
      optionsList = options,
      fallbackKey = "default",
      initial = "missing",
    })

    assert(selected.label.text == "Font Family", "test_dropdown_label: row label should be exposed")
    assert(selected.button.label.text == "Open Sans", "test_dropdown_initial: selected option label should be shown while closed")
    assert(fallback.button.label.text == "Default", "test_dropdown_fallback: missing initial value should show fallback label")
  end

  -- test_open_refreshes_options_and_clamps_mouse_wheel_scroll

  do
    local source = {
      { key = "default", label = "Default" },
      { key = "alpha", label = "Alpha" },
      { key = "bravo", label = "Bravo" },
      { key = "charlie", label = "Charlie" },
      { key = "delta", label = "Delta" },
    }
    local refreshes = 0
    local selector = DropdownSelector.Create(factory, parent, {
      labelText = "Font Family",
      getOptions = function()
        refreshes = refreshes + 1
        return source
      end,
      fallbackKey = "default",
      initial = "default",
      menuHeight = 52,
    })

    local open = selector.button:GetScript("OnClick")
    assert(type(open) == "function", "test_dropdown_open: closed button should open menu")
    open(selector.button)
    assert(selector.menu:IsShown(), "test_dropdown_open: menu should show after clicking closed button")
    assert(refreshes == 1, "test_dropdown_refresh: options should refresh on first open")
    assert(#selector.optionButtons == #source, "test_dropdown_refresh: refreshed options should create option buttons")

    source = {
      { key = "default", label = "Default" },
      { key = "fira", label = "Fira Sans" },
    }
    selector.menu:Hide()
    open(selector.button)
    assert(refreshes == 2, "test_dropdown_refresh: options should refresh on every open")
    assert(#selector.optionButtons == #source, "test_dropdown_refresh: second open should replace option buttons")

    source = {
      { key = "default", label = "Default" },
      { key = "alpha", label = "Alpha" },
      { key = "bravo", label = "Bravo" },
      { key = "charlie", label = "Charlie" },
      { key = "delta", label = "Delta" },
    }
    selector.menu:Hide()
    open(selector.button)
    assert(selector.menu.clipsChildren == true, "test_dropdown_scroll: menu should clip overflowing option buttons")
    assert(selector.menu:GetHeight() == 52, "test_dropdown_scroll: menu should retain configured viewport height")
    assert(selector.menu:GetVerticalScrollRange() > 0, "test_dropdown_scroll: overflowing options should create a scroll range")
    local wheel = selector.menu:GetScript("OnMouseWheel")
    assert(type(wheel) == "function", "test_dropdown_scroll: menu should handle mouse wheel")
    for _ = 1, 20 do
      wheel(selector.menu, -1)
    end
    assert(
      selector.menu:GetVerticalScroll() == selector.menu:GetVerticalScrollRange(),
      "test_dropdown_scroll: wheel down should clamp at menu bottom"
    )
    for _ = 1, 20 do
      wheel(selector.menu, 1)
    end
    assert(selector.menu:GetVerticalScroll() == 0, "test_dropdown_scroll: wheel up should clamp at menu top")
  end

  -- test_parent_hide_closes_open_menu

  do
    local lifecycleParent = factory.CreateFrame("Frame", "DropdownLifecycleParent", nil)
    local selector = DropdownSelector.Create(factory, lifecycleParent, {
      labelText = "Font Family",
      optionsList = {
        { key = "default", label = "Default" },
        { key = "open_sans", label = "Open Sans" },
      },
      fallbackKey = "default",
      initial = "default",
    })

    selector.button:GetScript("OnClick")(selector.button)
    assert(selector.menu:IsShown(), "test_dropdown_parent_hide: menu should open before parent hides")
    lifecycleParent:Hide()
    assert(not selector.menu:IsShown(), "test_dropdown_parent_hide: hiding parent should close open menu")
  end

  -- test_selection_closes_menu_and_reset_apis_update_control

  do
    local changed = nil
    local selector = DropdownSelector.Create(factory, parent, {
      labelText = "Font Family",
      optionsList = {
        { key = "default", label = "Default" },
        { key = "open_sans", label = "Open Sans" },
      },
      fallbackKey = "default",
      initial = "default",
      onChange = function(value)
        changed = value
      end,
    })

    selector.button:GetScript("OnClick")(selector.button)
    local selectOpenSans = selector.optionButtons[2]:GetScript("OnClick")
    assert(type(selectOpenSans) == "function", "test_dropdown_select: option button should be clickable")
    selectOpenSans(selector.optionButtons[2])
    assert(changed == "open_sans", "test_dropdown_select: selecting option should call onChange")
    assert(not selector.menu:IsShown(), "test_dropdown_select: selecting option should close menu")
    assert(selector.button.label.text == "Open Sans", "test_dropdown_select: closed button should show selected label")

    selector.setSelected("default")
    assert(selector.button.label.text == "Default", "test_dropdown_reset: setSelected should support reset to fallback option")

    selector.setWidth(318)
    assert(selector.row.width == 318, "test_dropdown_width: setWidth should resize row")
    assert(selector.button.width == 318, "test_dropdown_width: setWidth should resize closed button")

    local theme = {
      COLORS = {
        text_primary = { 0.2, 0.4, 0.6, 1 },
        option_button_bg = { 0.1, 0.1, 0.1, 1 },
        option_button_hover = { 0.2, 0.2, 0.2, 1 },
        option_button_active = { 0.3, 0.3, 0.3, 1 },
        option_button_text = { 0.7, 0.7, 0.7, 1 },
        option_button_text_hover = { 0.8, 0.8, 0.8, 1 },
        option_button_text_active = { 0.9, 0.9, 0.9, 1 },
      },
    }
    selector.applyTheme(theme)
    assert(selector.label.textColor[1] == 0.2, "test_dropdown_theme: applyTheme should recolor label")
  end

  print("  All dropdown selector tests passed")
end
