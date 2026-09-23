local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local ChromeBuilder = require("WhisperMessenger.UI.MessengerWindow.ChromeBuilder")
local WindowVisibility = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.WindowVisibility")
local WindowScripts = require("WhisperMessenger.UI.MessengerWindow.WindowScripts")

local function colorsMatch(actual, expected)
  if not actual or not expected then
    return false
  end

  return actual[1] == expected[1] and actual[2] == expected[2] and actual[3] == expected[3] and (actual[4] or 1) == (expected[4] or 1)
end

local function buildChrome(useNativeChrome)
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  local chrome = ChromeBuilder.Build(factory, parent, { width = 920, height = 580 }, {
    useNativeChrome = useNativeChrome == true,
  })

  return factory, parent, chrome
end

local function findButtonVisuals(button)
  local background
  local icon
  for _, child in ipairs(button.children or {}) do
    if child.texturePath then
      icon = child
    elseif child.color then
      background = child
    end
  end

  return background, icon
end

local function forEachChrome(assertions)
  for _, chromeType in ipairs({
    { name = "modern", useNativeChrome = false },
    { name = "native", useNativeChrome = true },
  }) do
    local _, _, chrome = buildChrome(chromeType.useNativeChrome)
    assertions(chrome, chromeType.name)
  end
end

local TRANSPARENT = { 0, 0, 0, 0 }
local DANGER_GLYPH = { 0.95, 0.36, 0.36, 1 }
local GRIP_HOVER = { 1, 1, 1, 0.55 }

local function test_back_button_renders_icon_visuals()
  forEachChrome(function(chrome, chromeType)
    local background, icon = findButtonVisuals(chrome.backButton)
    assert(background ~= nil, chromeType .. " Back button should render a background")
    assert(icon ~= nil, chromeType .. " Back button should render an icon")
    assert(icon.texturePath == Theme.TEXTURES.title_back_icon, chromeType .. " Back button should render the bundled back icon")
    assert(colorsMatch(background.color, TRANSPARENT), chromeType .. " Back button has no fill at rest")
    assert(colorsMatch(icon.vertexColor, Theme.COLORS.text_secondary), chromeType .. " Back icon is text_secondary at rest")
  end)
end

local function test_back_button_hover_and_leave()
  forEachChrome(function(chrome, chromeType)
    local background, icon = findButtonVisuals(chrome.backButton)
    chrome.backButton:GetScript("OnEnter")(chrome.backButton)
    assert(colorsMatch(background.color, TRANSPARENT), chromeType .. " Back hover keeps no fill")
    assert(colorsMatch(icon.vertexColor, Theme.COLORS.text_primary), chromeType .. " Back hover brightens the icon")
    chrome.backButton:GetScript("OnLeave")(chrome.backButton)
    assert(colorsMatch(icon.vertexColor, Theme.COLORS.text_secondary), chromeType .. " Back leave restores the resting icon")
  end)
end

local function test_back_button_apply_theme_repaints_visuals()
  local repaintTheme = setmetatable({
    COLORS = setmetatable({
      text_secondary = { 0.55, 0.66, 0.77, 0.88 },
    }, { __index = Theme.COLORS }),
  }, { __index = Theme })

  forEachChrome(function(chrome, chromeType)
    local _, icon = findButtonVisuals(chrome.backButton)
    chrome.applyTheme(repaintTheme)
    assert(colorsMatch(icon.vertexColor, repaintTheme.COLORS.text_secondary), chromeType .. " Back icon should repaint when theme changes")
  end)
end

local function test_hovered_chrome_controls_keep_hover_paint_when_theme_changes()
  local repaintTheme = setmetatable({
    COLORS = setmetatable({
      text_primary = { 0.51, 0.52, 0.53, 0.54 },
      text_secondary = { 0.71, 0.72, 0.73, 0.74 },
    }, { __index = Theme.COLORS }),
  }, { __index = Theme })

  forEachChrome(function(chrome, chromeType)
    local _, backIcon = findButtonVisuals(chrome.backButton)
    local _, newConversationIcon = findButtonVisuals(chrome.newConversationButton)
    local resizeLines = chrome.resizeGrip.children or {}
    assert(#resizeLines > 0, chromeType .. " resize grip should expose rendered lines")

    for _, control in ipairs({ chrome.backButton, chrome.newConversationButton, chrome.resizeGrip }) do
      control.mouseOver = true
      control:GetScript("OnEnter")(control)
    end

    chrome.applyTheme(repaintTheme)

    assert(colorsMatch(backIcon.vertexColor, repaintTheme.COLORS.text_primary), chromeType .. " hovered Back icon keeps hover paint")
    assert(
      colorsMatch(newConversationIcon.vertexColor, repaintTheme.COLORS.text_primary),
      chromeType .. " hovered New Conversation icon keeps hover paint"
    )
    for _, line in ipairs(resizeLines) do
      assert(colorsMatch(line.color, GRIP_HOVER), chromeType .. " hovered resize grip keeps hover paint")
    end
  end)
end

local function test_modern_close_button_preserves_hover_and_latest_theme()
  local repaintTheme = setmetatable({
    COLORS = setmetatable({
      text_secondary = { 0.12, 0.23, 0.34, 0.45 },
    }, { __index = Theme.COLORS }),
  }, { __index = Theme })
  local _, _, chrome = buildChrome(false)
  local background, icon = findButtonVisuals(chrome.closeButton)
  assert(background ~= nil and icon ~= nil, "modern close button should expose rendered visuals")

  chrome.closeButton.mouseOver = true
  chrome.closeButton:GetScript("OnEnter")(chrome.closeButton)
  chrome.applyTheme(repaintTheme)
  assert(colorsMatch(icon.vertexColor, DANGER_GLYPH), "hovered close icon keeps its red hover glyph when theme changes")
  assert(colorsMatch(background.color, TRANSPARENT), "hovered close button keeps no fill")

  chrome.closeButton.mouseOver = false
  chrome.closeButton:GetScript("OnLeave")(chrome.closeButton)
  assert(colorsMatch(icon.vertexColor, repaintTheme.COLORS.text_secondary), "close leave restores the latest themed icon color")
end

local function test_chrome_controls_use_branch_specific_anchor_tuples()
  forEachChrome(function(chrome, chromeType)
    -- Native WoW HUD keeps its compact 2px chain; custom chrome uses the
    -- shared title-bar gap.
    local gap = chromeType == "native" and 2 or Theme.LAYOUT.TITLE_BUTTON_GAP
    local newPoint, newRelativeTo, newRelativePoint, newX, newY = chrome.newConversationButton:GetPoint()
    if chromeType == "native" then
      assert(
        newPoint == "TOPLEFT" and newRelativeTo == chrome.frame and newRelativePoint == "TOPLEFT" and newX == 6 and newY == -3,
        "native New Conversation button should use its complete frame-relative anchor"
      )
    else
      assert(
        newPoint == "LEFT" and newRelativeTo == chrome.title and newRelativePoint == "RIGHT" and newX == gap and newY == 0,
        "modern New Conversation button should use its complete title-relative anchor"
      )
    end

    local optionsPoint, optionsRelativeTo, optionsRelativePoint, optionsX, optionsY = chrome.optionsButton:GetPoint()
    assert(
      optionsPoint == "RIGHT" and optionsRelativeTo == chrome.closeButton and optionsRelativePoint == "LEFT" and optionsX == -gap and optionsY == 0,
      chromeType .. " options button should use its complete close-relative anchor"
    )

    local backPoint, backRelativeTo, backRelativePoint, backX, backY = chrome.backButton:GetPoint()
    assert(
      backPoint == "RIGHT" and backRelativeTo == chrome.optionsButton and backRelativePoint == "LEFT" and backX == -gap and backY == 0,
      chromeType .. " Back button should use its complete options-relative anchor"
    )
  end)
end

local function test_cogwheel_active_visual_survives_hover()
  local _, _, chrome = buildChrome()

  assert(type(chrome.setOptionsActive) == "function", "chrome should expose options active-state updates")
  local background, icon = findButtonVisuals(chrome.optionsButton)
  assert(background ~= nil and icon ~= nil, "options cogwheel should expose rendered background and icon visuals")

  chrome.setOptionsActive(true)

  assert(colorsMatch(background.color, TRANSPARENT), "active cogwheel has no fill")
  assert(colorsMatch(icon.vertexColor, Theme.COLORS.text_primary), "visible options should render the cogwheel emphasized")
  assert(chrome.backButton:IsShown(), "Back button should be visible while options are active")

  chrome.optionsButton.mouseOver = true
  chrome.optionsButton:GetScript("OnEnter")(chrome.optionsButton)
  chrome.optionsButton.mouseOver = false
  chrome.optionsButton:GetScript("OnLeave")(chrome.optionsButton)
  assert(colorsMatch(icon.vertexColor, Theme.COLORS.text_primary), "leaving hover keeps the active cogwheel emphasized")

  chrome.setOptionsActive(false)
  assert(colorsMatch(icon.vertexColor, Theme.COLORS.text_secondary), "hidden options should restore the resting cogwheel")
  assert(not chrome.backButton:IsShown(), "Back button should hide with options")
end

local function test_navigation_updates_built_chrome_after_panes_transition()
  local factory, _, chrome = buildChrome()
  local optionsPanel = factory.CreateFrame("Frame", nil, chrome.frame)
  local contactsPane = factory.CreateFrame("Frame", nil, chrome.frame)
  local contentPane = factory.CreateFrame("Frame", nil, chrome.frame)
  local observedTransitions = {}

  optionsPanel:Hide()
  contactsPane:Show()
  contentPane:Show()

  local visibility = WindowVisibility.Create({
    optionsPanel = optionsPanel,
    contactsPane = contactsPane,
    contentPane = contentPane,
    onOptionsVisibilityChanged = function(visible)
      observedTransitions[#observedTransitions + 1] = optionsPanel:IsShown() == visible
        and contactsPane:IsShown() == not visible
        and contentPane:IsShown() == not visible
      chrome.setOptionsActive(visible)
    end,
  })

  WindowScripts.WireButtons({
    optionsButton = chrome.optionsButton,
    backButton = chrome.backButton,
    optionsPanel = optionsPanel,
  }, {
    setOptionsVisible = visibility.setOptionsVisible,
    isShown = function(frame)
      return frame:IsShown()
    end,
  })

  local _, optionsIcon = findButtonVisuals(chrome.optionsButton)
  assert(optionsIcon ~= nil, "built options button should expose rendered visuals")

  chrome.optionsButton:GetScript("OnClick")(chrome.optionsButton)
  assert(observedTransitions[1] == true, "show callback should observe already-transitioned panes")
  assert(colorsMatch(optionsIcon.vertexColor, Theme.COLORS.text_primary), "cogwheel show should activate built options icon")
  assert(chrome.backButton:IsShown(), "cogwheel show should reveal the built Back button")

  local onBack = chrome.backButton:GetScript("OnClick")
  assert(type(onBack) == "function", "built Back button should be wired for navigation")
  onBack(chrome.backButton)

  assert(observedTransitions[2] == true, "Back callback should observe already-restored panes")
  assert(colorsMatch(optionsIcon.vertexColor, Theme.COLORS.text_secondary), "Back should restore the built options resting icon")
  assert(not chrome.backButton:IsShown(), "Back should hide after restoring conversation panes")
end

return function()
  -- Every preset shares the icon-button chrome; run against Azeroth to prove
  -- it no longer takes a separate paint path.
  local previousPreset = Theme.GetPreset()
  Theme.SetPreset("wow_native")
  test_back_button_renders_icon_visuals()
  test_back_button_hover_and_leave()
  test_back_button_apply_theme_repaints_visuals()
  test_hovered_chrome_controls_keep_hover_paint_when_theme_changes()
  test_chrome_controls_use_branch_specific_anchor_tuples()
  test_cogwheel_active_visual_survives_hover()
  test_navigation_updates_built_chrome_after_panes_transition()
  test_modern_close_button_preserves_hover_and_latest_theme()
  Theme.SetPreset(previousPreset)
end
