local FakeUI = require("tests.helpers.fake_ui")
local AppearanceSettings = require("WhisperMessenger.UI.MessengerWindow.AppearanceSettings")
local Localization = require("WhisperMessenger.Locale.Localization")
local FindUI = require("tests.helpers.find_ui")

local function themeButtons(result)
  return FindUI.selectorButtons(result.frame, "Theme Preset")
end

local function fontRow(result)
  return FindUI.byLabel(result.frame, "Font Family")
end

-- Closed dropdown button of the Font Family row.
local function fontButton(result)
  return FindUI.ofType(fontRow(result), "Button")[1]
end

local function resetButton(result)
  return FindUI.byLabel(result.frame, "Reset to Defaults")
end

local function withSharedMedia(fonts, fn)
  local savedLibStub = rawget(_G, "LibStub")
  local lsm = {
    List = function(_, mediaType)
      assert(mediaType == "font", "expected LibSharedMedia font list")
      local names = {}
      for name in pairs(fonts) do
        names[#names + 1] = name
      end
      return names
    end,
    Fetch = function(_, mediaType, name, noDefault)
      assert(mediaType == "font", "expected LibSharedMedia font fetch")
      assert(noDefault == true, "expected LibSharedMedia fetch without default")
      return fonts[name]
    end,
  }

  rawset(
    _G,
    "LibStub",
    setmetatable({}, {
      __call = function(_, name)
        if name == "LibSharedMedia-3.0" then
          return lsm
        end
      end,
    })
  )

  local ok, err = pcall(fn)
  rawset(_G, "LibStub", savedLibStub)
  if not ok then
    error(err, 0)
  end
end

return function()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)

  -- test_theme_preset_selector_exists

  do
    local config = { themePreset = "wow_default" }
    local result = AppearanceSettings.Create(factory, parent, config, { onChange = function() end })

    local buttons = themeButtons(result)
    assert(#buttons == 5, "test_theme_preset_selector_exists: should have 5 preset buttons, got: " .. tostring(#buttons))
  end

  -- test_theme_preset_selector_labels

  do
    local config = { themePreset = "wow_default" }
    local result = AppearanceSettings.Create(factory, parent, config, { onChange = function() end })

    local labels = {}
    for _, btn in ipairs(themeButtons(result)) do
      if btn.label and btn.label.text then
        table.insert(labels, btn.label.text)
      end
    end

    local expected = {
      ["Midnight"] = false,
      ["Shadowlands"] = false,
      ["Draenor"] = false,
      ["Pandaria"] = false,
      ["Azeroth"] = false,
    }
    for _, text in ipairs(labels) do
      if expected[text] ~= nil then
        expected[text] = true
      end
    end

    assert(expected["Midnight"], "test_theme_preset_selector_labels: should have a 'Midnight' button")
    assert(expected["Shadowlands"], "test_theme_preset_selector_labels: should have a 'Shadowlands' button")
    assert(expected["Draenor"], "test_theme_preset_selector_labels: should have a 'Draenor' button")
    assert(expected["Pandaria"], "test_theme_preset_selector_labels: should have a 'Pandaria' button")
    assert(expected["Azeroth"], "test_theme_preset_selector_labels: should have an 'Azeroth' button")
  end

  -- test_theme_preset_selector_fires_on_change

  do
    local changes = {}
    local config = { themePreset = "wow_default" }
    local result = AppearanceSettings.Create(factory, parent, config, {
      onChange = function(key, value)
        changes[key] = value
      end,
    })

    -- Click the "Draenor" button (third one)
    local warmBtn = themeButtons(result)[3]
    local onClick = warmBtn:GetScript("OnClick")
    assert(onClick ~= nil, "test_theme_preset_selector_fires_on_change: button should have OnClick")
    onClick(warmBtn)

    assert(
      changes.themePreset == "plumber_warm",
      "test_theme_preset_selector_fires_on_change: should fire onChange with themePreset=plumber_warm, got: " .. tostring(changes.themePreset)
    )
  end

  -- test_theme_preset_selector_highlights_initial

  do
    local config = { themePreset = "elvui_dark" }
    local result = AppearanceSettings.Create(factory, parent, config, { onChange = function() end })

    local darkBtn = themeButtons(result)[2]
    assert(
      darkBtn._selected == true,
      "test_theme_preset_selector_highlights_initial: Shadowlands button should be selected when themePreset=elvui_dark"
    )
    local defaultBtn = themeButtons(result)[1]
    assert(
      defaultBtn._selected ~= true,
      "test_theme_preset_selector_highlights_initial: Midnight button should NOT be selected when themePreset=elvui_dark"
    )
  end

  -- Window scale uses a localized percentage slider directly below theme.
  do
    Localization.Configure({ language = "enUS" })
    local changes = {}
    local result = AppearanceSettings.Create(factory, parent, { themePreset = "wow_default", windowScale = 1.25 }, {
      onChange = function(key, value)
        changes.key = key
        changes.value = value
      end,
    })
    local slider = FindUI.slider(result.frame, "Window Scale")

    assert(slider ~= nil, "window scale slider should be rendered")
    assert(slider.minValue == 0.75 and slider.maxValue == 1.50, "window scale range should be 0.75 through 1.50")
    assert(slider.valueStep == 0.05 and slider.value == 1.25, "window scale should use 0.05 steps and configured value")
    assert(slider.parent.children[1].text == "Window Scale", "window scale should use localized label")
    assert(slider.parent.children[2].text == "125%", "window scale value should use percent formatter")
    assert(slider.children[2].text == "75%" and slider.children[3].text == "150%", "window scale limits should use percent formatter")

    result.refreshLayout(360)
    assert(changes.key == nil, "layout slider resize must not commit a setting")
    local _, scaleAnchor = slider.parent:GetPoint()
    local _, fontAnchor = fontRow(result):GetPoint()
    assert(scaleAnchor == FindUI.byLabel(result.frame, "Theme Preset"), "window scale row should follow theme preset")
    assert(fontAnchor == slider.parent, "font family row should follow window scale")

    slider:SetValue(1.274)
    assert(changes.key == "windowScale" and changes.value == 1.25, "programmatic window scale should commit stepped value immediately")
  end

  -- Native left drags update display but commit only the final value on release.
  do
    local changes = {}
    local result = AppearanceSettings.Create(factory, parent, { windowScale = 1.00, fontSize = 12 }, {
      onChange = function(key, value)
        changes[#changes + 1] = { key = key, value = value }
      end,
    })
    local slider = FindUI.slider(result.frame, "Window Scale")
    local onMouseDown = slider:GetScript("OnMouseDown")
    local onMouseUp = slider:GetScript("OnMouseUp")
    assert(type(onMouseDown) == "function" and type(onMouseUp) == "function", "window scale slider must wire mouse handlers")

    onMouseDown(slider, "LeftButton")
    slider:SetValue(1.274, true)
    slider:SetValue(1.326, true)
    assert(slider.parent.children[2].text == "135%", "window scale drag must display latest stepped value")
    assert(#changes == 0, "window scale drag must defer onChange")
    onMouseUp(slider, "LeftButton")
    assert(
      #changes == 1 and changes[1].key == "windowScale" and changes[1].value == 1.35,
      "window scale release must commit final stepped value once"
    )

    FindUI.slider(result.frame, "Font Size"):SetValue(16)
    assert(#changes == 2 and changes[2].key == "fontSize", "ordinary sliders must remain immediate")
  end

  -- test_font_selector_uses_dropdown_for_registered_fonts

  do
    withSharedMedia({ ["Open Sans"] = "Interface\\AddOns\\SharedMedia\\OpenSans.ttf" }, function()
      local result = AppearanceSettings.Create(factory, parent, { fontFamily = "default" }, { onChange = function() end })

      assert(FindUI.text(result.frame, "Font Family") ~= nil, "test_font_dropdown_exists: should retain Font Family label")
      assert(fontButton(result) ~= nil, "test_font_dropdown_exists: dropdown should render a closed button")
      assert(FindUI.dropdownMenu(fontRow(result)) ~= nil, "test_font_dropdown_exists: dropdown should render a menu")
      assert(fontButton(result).label.text == "Default", "test_font_dropdown_exists: default should be shown while closed")
    end)
  end

  -- test_font_dropdown_selects_registered_font_and_closes

  do
    withSharedMedia({ ["Open Sans"] = "Interface\\AddOns\\SharedMedia\\OpenSans.ttf" }, function()
      local changes = {}
      local result = AppearanceSettings.Create(factory, parent, { fontFamily = "default" }, {
        onChange = function(key, value)
          changes[key] = value
        end,
      })

      local button = fontButton(result)
      local menu = FindUI.dropdownMenu(fontRow(result))
      local open = button:GetScript("OnClick")
      assert(type(open) == "function", "test_font_dropdown_select: closed button should open font menu")
      open(button)
      assert(menu:IsShown(), "test_font_dropdown_select: menu should open")
      local openSans = FindUI.dropdownOptions(fontRow(result))[2]
      assert(openSans.label.text == "Open Sans", "test_font_dropdown_select: registered font should be listed")

      FindUI.click(openSans)
      assert(changes.fontFamily == "Open Sans", "test_font_dropdown_select: selection should report registered name")
      assert(not menu:IsShown(), "test_font_dropdown_select: selection should close menu")
      assert(button.label.text == "Open Sans", "test_font_dropdown_select: closed button should update label")
    end)
  end

  -- test_font_dropdown_missing_saved_font_displays_default

  do
    withSharedMedia({ ["Open Sans"] = "Interface\\AddOns\\SharedMedia\\OpenSans.ttf" }, function()
      local result = AppearanceSettings.Create(factory, parent, { fontFamily = "Missing Font" }, { onChange = function() end })
      assert(fontButton(result).label.text == "Default", "test_font_dropdown_missing: missing saved font should display Default")
    end)
  end

  -- test_reset_resets_font_and_theme_to_defaults

  do
    withSharedMedia({ ["Open Sans"] = "Interface\\AddOns\\SharedMedia\\OpenSans.ttf" }, function()
      local changes = {}
      local config = {
        fontFamily = "Open Sans",
        themePreset = "elvui_dark",
        windowOpacityInactive = 0.90,
        windowOpacityActive = 0.60,
        windowScale = 1.35,
      }
      local result = AppearanceSettings.Create(factory, parent, config, {
        onChange = function(key, value)
          changes[key] = value
          if key == "windowScale" then
            changes.windowScaleCalls = (changes.windowScaleCalls or 0) + 1
          end
        end,
      })

      local reset = resetButton(result)
      local resetClick = reset:GetScript("OnClick")
      assert(resetClick ~= nil, "test_reset_resets_font_and_theme: resetButton should have OnClick")
      local windowScaleSlider = FindUI.slider(result.frame, "Window Scale")
      local onMouseDown = windowScaleSlider:GetScript("OnMouseDown")
      local onMouseUp = windowScaleSlider:GetScript("OnMouseUp")
      onMouseDown(windowScaleSlider, "LeftButton")
      windowScaleSlider:SetValue(1.274, true)
      assert(changes.windowScaleCalls == nil, "reset test user drag must defer windowScale")
      resetClick(reset)
      assert(changes.windowScaleCalls == 1 and changes.windowScale == 1.00, "reset must commit windowScale immediately")
      onMouseUp(windowScaleSlider, "LeftButton")
      assert(changes.windowScaleCalls == 1, "release after reset must not replay stale windowScale")

      assert(
        changes.themePreset == "wow_default",
        "test_reset_resets_font_and_theme: reset should fire onChange with themePreset=wow_default, got: " .. tostring(changes.themePreset)
      )
      assert(
        changes.fontFamily == "default",
        "test_reset_resets_font_and_theme: reset should fire onChange with fontFamily=default, got: " .. tostring(changes.fontFamily)
      )
      assert(
        math.abs((changes.windowOpacityInactive or 0) - 0.7) < 0.0001,
        "test_reset_resets_font_and_theme: reset should fire onChange with windowOpacityInactive=0.7, got: "
          .. tostring(changes.windowOpacityInactive)
      )
      assert(
        math.abs((changes.windowOpacityActive or 0) - 1.0) < 0.0001,
        "test_reset_resets_font_and_theme: reset should fire onChange with windowOpacityActive=1.0, got: " .. tostring(changes.windowOpacityActive)
      )
      assert(themeButtons(result)[1]._selected == true, "test_reset_resets_font_and_theme: Midnight theme should be selected after reset")
      assert(fontButton(result).label.text == "Default", "test_reset_resets_font_and_theme: reset should show Default font")
      assert(windowScaleSlider.value == 1.00, "reset should restore windowScale slider to 1.00")
      assert(windowScaleSlider.parent.children[2].text == "100%", "reset should display 100% window scale")
    end)
  end

  -- test_font_dropdown_refreshes_shared_media_options_when_opened

  do
    local fonts = {}
    withSharedMedia(fonts, function()
      local result = AppearanceSettings.Create(factory, parent, { fontFamily = "default" }, { onChange = function() end })
      fonts["Fira Sans"] = "Interface\\AddOns\\SharedMedia\\FiraSans.ttf"

      FindUI.click(fontButton(result))
      assert(FindUI.dropdownMenu(fontRow(result)):IsShown(), "test_font_dropdown_refresh: menu should open")
      local listed = FindUI.dropdownOptions(fontRow(result))
      assert(#listed == 2, "test_font_dropdown_refresh: open menu should include newly registered font")
      assert(listed[2].label.text == "Fira Sans", "test_font_dropdown_refresh: open menu should use refreshed font list")
    end)
  end

  -- test_font_size_slider_exists

  do
    local config = { fontSize = 12 }
    local result = AppearanceSettings.Create(factory, parent, config, { onChange = function() end })

    assert(FindUI.slider(result.frame, "Font Size") ~= nil, "test_font_size_slider_exists: should render a Font Size slider")
  end

  -- test_font_size_slider_fires_on_change

  do
    local changes = {}
    local config = { fontSize = 12 }
    local result = AppearanceSettings.Create(factory, parent, config, {
      onChange = function(key, value)
        changes[key] = value
      end,
    })

    local fontSizeSlider = FindUI.slider(result.frame, "Font Size")
    local onValueChanged = fontSizeSlider:GetScript("OnValueChanged")
    assert(onValueChanged ~= nil, "test_font_size_fires: slider should have OnValueChanged")
    onValueChanged(fontSizeSlider, 16)

    assert(changes.fontSize == 16, "test_font_size_fires: should fire onChange with fontSize=16, got: " .. tostring(changes.fontSize))
  end

  -- test_font_outline_selector_exists

  do
    local config = { fontOutline = "NONE" }
    local result = AppearanceSettings.Create(factory, parent, config, { onChange = function() end })

    local buttons = FindUI.selectorButtons(result.frame, "Font Outline")
    assert(#buttons == 3, "test_font_outline_selector_exists: should have 3 outline buttons, got: " .. tostring(#buttons))
  end

  -- test_font_outline_selector_fires_on_change

  do
    local changes = {}
    local config = { fontOutline = "NONE" }
    local result = AppearanceSettings.Create(factory, parent, config, {
      onChange = function(key, value)
        changes[key] = value
      end,
    })

    -- Click the "Outline" button (second one)
    local outlineBtn = FindUI.selectorButtons(result.frame, "Font Outline")[2]
    local onClick = outlineBtn:GetScript("OnClick")
    onClick(outlineBtn)

    assert(
      changes.fontOutline == "OUTLINE",
      "test_font_outline_fires: should fire onChange with fontOutline=OUTLINE, got: " .. tostring(changes.fontOutline)
    )
  end

  -- test_font_color_selector_exists

  do
    local config = { fontColor = "default" }
    local result = AppearanceSettings.Create(factory, parent, config, { onChange = function() end })

    local buttons = FindUI.selectorButtons(result.frame, "Chat Font Color")
    assert(#buttons >= 6, "test_font_color_selector_exists: should have at least 6 color buttons, got: " .. tostring(#buttons))
  end

  -- test_font_color_selector_fires_on_change

  do
    local changes = {}
    local config = { fontColor = "default" }
    local result = AppearanceSettings.Create(factory, parent, config, {
      onChange = function(key, value)
        changes[key] = value
      end,
    })

    -- Click the "Gold" button (second one: default, gold, ...)
    local goldBtn = FindUI.selectorButtons(result.frame, "Chat Font Color")[2]
    local onClick = goldBtn:GetScript("OnClick")
    onClick(goldBtn)

    assert(changes.fontColor == "gold", "test_font_color_fires: should fire onChange with fontColor=gold, got: " .. tostring(changes.fontColor))
  end

  -- test_reset_resets_new_font_settings

  do
    withSharedMedia({ ["Open Sans"] = "Interface\\AddOns\\SharedMedia\\OpenSans.ttf" }, function()
      local changes = {}
      local config = {
        fontFamily = "Open Sans",
        fontSize = 16,
        fontOutline = "OUTLINE",
        fontColor = "gold",
        themePreset = "elvui_dark",
        windowOpacityInactive = 0.90,
        windowOpacityActive = 0.60,
      }
      local result = AppearanceSettings.Create(factory, parent, config, {
        onChange = function(key, value)
          changes[key] = value
        end,
      })

      FindUI.click(resetButton(result))

      assert(changes.fontSize == 12, "test_reset_new_settings: reset should fire fontSize=12, got: " .. tostring(changes.fontSize))
      assert(changes.fontOutline == "NONE", "test_reset_new_settings: reset should fire fontOutline=NONE, got: " .. tostring(changes.fontOutline))
      assert(changes.fontColor == "default", "test_reset_new_settings: reset should fire fontColor=default, got: " .. tostring(changes.fontColor))
    end)
  end

  -- test_russian_localizes_appearance_panel

  do
    Localization.Configure({ language = "ruRU" })
    local result = AppearanceSettings.Create(factory, parent, { themePreset = "wow_default", fontFamily = "default" }, { onChange = function() end })

    local texts = {}
    for _, child in ipairs(result.frame.children) do
      if child.text then
        texts[child.text] = true
      end
    end

    assert(texts["Внешний вид"], "Russian appearance panel should translate title")
    assert(texts["Настройте темы, шрифты и прозрачность окна."], "Russian appearance panel should translate hint")
    assert(#FindUI.selectorButtons(result.frame, "Профиль темы") == 5, "Theme Preset label should be localized")
    assert(FindUI.slider(result.frame, "Масштаб окна") ~= nil, "Window Scale label should be localized")
    local ruFontButton = FindUI.ofType(FindUI.byLabel(result.frame, "Шрифт"), "Button")[1]
    assert(ruFontButton ~= nil, "Font Family label should be localized")
    assert(ruFontButton.label.text == "По умолчанию", "Default font should be localized in closed dropdown")
    assert(#FindUI.selectorButtons(result.frame, "Обводка шрифта") == 3, "Font Outline label should be localized")
    assert(#FindUI.selectorButtons(result.frame, "Цвета пузырей") > 0, "Bubble Colors label should be localized")
    assert(FindUI.byLabel(result.frame, "Сбросить настройки").frameType == "Button", "Reset button should be localized")
    Localization.Configure({ language = "enUS" })
  end
  print("  All appearance settings tests passed")
end
