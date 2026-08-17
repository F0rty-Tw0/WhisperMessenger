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

local function test_back_button_renders_themed_visuals()
  forEachChrome(function(chrome, chromeType)
    local background, icon = findButtonVisuals(chrome.backButton)
    assert(background ~= nil, chromeType .. " Back button should render a themed background")
    assert(icon ~= nil, chromeType .. " Back button should render an icon")
    assert(icon.texturePath == "Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up", chromeType .. " Back button should render the previous-page icon")
    assert(colorsMatch(background.color, Theme.COLORS.option_button_bg), chromeType .. " Back button should use the themed resting background")
    assert(colorsMatch(icon.vertexColor, Theme.COLORS.option_button_text), chromeType .. " Back button should use the themed resting icon color")
  end)
end

local function test_back_button_hover_uses_theme_colors()
  forEachChrome(function(chrome, chromeType)
    local background, icon = findButtonVisuals(chrome.backButton)
    assert(background ~= nil and icon ~= nil, chromeType .. " Back button should expose rendered visuals")

    local onEnter = chrome.backButton:GetScript("OnEnter")
    assert(type(onEnter) == "function", chromeType .. " Back button should repaint on hover")

    onEnter(chrome.backButton)
    assert(colorsMatch(background.color, Theme.COLORS.option_button_hover), chromeType .. " Back hover should use the themed hover background")
    assert(colorsMatch(icon.vertexColor, Theme.COLORS.option_button_text_hover), chromeType .. " Back hover should use the themed hover icon color")
  end)
end

local function test_back_button_leave_restores_theme_colors()
  forEachChrome(function(chrome, chromeType)
    local background, icon = findButtonVisuals(chrome.backButton)
    assert(background ~= nil and icon ~= nil, chromeType .. " Back button should expose rendered visuals")

    local onEnter = chrome.backButton:GetScript("OnEnter")
    local onLeave = chrome.backButton:GetScript("OnLeave")
    assert(type(onEnter) == "function", chromeType .. " Back button should repaint on hover")
    assert(type(onLeave) == "function", chromeType .. " Back button should restore paint after hover")

    onEnter(chrome.backButton)
    onLeave(chrome.backButton)
    assert(colorsMatch(background.color, Theme.COLORS.option_button_bg), chromeType .. " Back leave should restore the themed resting background")
    assert(colorsMatch(icon.vertexColor, Theme.COLORS.option_button_text), chromeType .. " Back leave should restore the themed resting icon color")
  end)
end

local function test_back_button_apply_theme_repaints_visuals()
  local repaintTheme = setmetatable({
    COLORS = setmetatable({
      option_button_bg = { 0.11, 0.22, 0.33, 0.44 },
      option_button_text = { 0.55, 0.66, 0.77, 0.88 },
    }, { __index = Theme.COLORS }),
  }, { __index = Theme })

  forEachChrome(function(chrome, chromeType)
    local background, icon = findButtonVisuals(chrome.backButton)
    assert(background ~= nil and icon ~= nil, chromeType .. " Back button should expose rendered visuals")

    chrome.applyTheme(repaintTheme)

    assert(colorsMatch(background.color, repaintTheme.COLORS.option_button_bg), chromeType .. " Back background should repaint when theme changes")
    assert(colorsMatch(icon.vertexColor, repaintTheme.COLORS.option_button_text), chromeType .. " Back icon should repaint when theme changes")
  end)
end

local function test_hovered_chrome_controls_keep_hover_paint_when_theme_changes()
  local repaintTheme = setmetatable({
    COLORS = setmetatable({
      option_button_bg = { 0.01, 0.02, 0.03, 0.04 },
      option_button_hover = { 0.11, 0.12, 0.13, 0.14 },
      option_button_text = { 0.21, 0.22, 0.23, 0.24 },
      option_button_text_hover = { 0.31, 0.32, 0.33, 0.34 },
      bg_contact_hover = { 0.41, 0.42, 0.43, 0.44 },
      text_primary = { 0.51, 0.52, 0.53, 0.54 },
      text_title = { 0.61, 0.62, 0.63, 0.64 },
      text_secondary = { 0.71, 0.72, 0.73, 0.74 },
    }, { __index = Theme.COLORS }),
  }, { __index = Theme })

  forEachChrome(function(chrome, chromeType)
    local backBackground, backIcon = findButtonVisuals(chrome.backButton)
    local newConversationBackground, newConversationIcon = findButtonVisuals(chrome.newConversationButton)
    local resizeLines = chrome.resizeGrip.children or {}
    assert(backBackground ~= nil and backIcon ~= nil, chromeType .. " Back button should expose rendered visuals")
    assert(newConversationBackground ~= nil and newConversationIcon ~= nil, chromeType .. " New Conversation button should expose rendered visuals")
    assert(#resizeLines > 0, chromeType .. " resize grip should expose rendered lines")

    for _, control in ipairs({
      { name = "Back", frame = chrome.backButton },
      { name = "New Conversation", frame = chrome.newConversationButton },
      { name = "resize grip", frame = chrome.resizeGrip },
    }) do
      control.frame.mouseOver = true
      local onEnter = control.frame:GetScript("OnEnter")
      assert(type(onEnter) == "function", chromeType .. " " .. control.name .. " should repaint on hover")
      onEnter(control.frame)
    end

    chrome.applyTheme(repaintTheme)

    assert(
      colorsMatch(backBackground.color, repaintTheme.COLORS.option_button_hover),
      chromeType .. " hovered Back background should keep hover paint when theme changes"
    )
    assert(
      colorsMatch(backIcon.vertexColor, repaintTheme.COLORS.option_button_text_hover),
      chromeType .. " hovered Back icon should keep hover paint when theme changes"
    )
    assert(
      colorsMatch(newConversationBackground.color, { 0.41, 0.42, 0.43, 0.75 }),
      chromeType .. " hovered New Conversation background should keep hover paint when theme changes"
    )
    assert(
      colorsMatch(newConversationIcon.vertexColor, repaintTheme.COLORS.text_title),
      chromeType .. " hovered New Conversation icon should keep hover paint when theme changes"
    )

    for _, line in ipairs(resizeLines) do
      assert(colorsMatch(line.color, { 0.51, 0.52, 0.53, 1 }), chromeType .. " hovered resize grip should keep hover paint when theme changes")
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

  local onEnter = chrome.closeButton:GetScript("OnEnter")
  local onLeave = chrome.closeButton:GetScript("OnLeave")
  assert(type(onEnter) == "function" and type(onLeave) == "function", "modern close button should expose hover scripts")

  chrome.closeButton.mouseOver = true
  onEnter(chrome.closeButton)
  chrome.applyTheme(repaintTheme)

  assert(colorsMatch(icon.vertexColor, { 0.9, 0.3, 0.3, 1 }), "modern hovered close icon should keep hover color when theme changes")
  assert(colorsMatch(background.color, { 0.9, 0.3, 0.3, 0.15 }), "modern hovered close background should keep hover color when theme changes")

  chrome.closeButton.mouseOver = false
  onLeave(chrome.closeButton)
  assert(colorsMatch(icon.vertexColor, repaintTheme.COLORS.text_secondary), "modern close leave should restore the latest themed icon color")
  assert(colorsMatch(background.color, { 0, 0, 0, 0 }), "modern close leave should restore the resting background")
end

local function test_chrome_controls_use_branch_specific_anchor_tuples()
  forEachChrome(function(chrome, chromeType)
    local newPoint, newRelativeTo, newRelativePoint, newX, newY = chrome.newConversationButton:GetPoint()
    if chromeType == "native" then
      assert(
        newPoint == "TOPLEFT" and newRelativeTo == chrome.frame and newRelativePoint == "TOPLEFT" and newX == 6 and newY == -3,
        "native New Conversation button should use its complete frame-relative anchor"
      )
    else
      assert(
        newPoint == "LEFT" and newRelativeTo == chrome.title and newRelativePoint == "RIGHT" and newX == 2 and newY == 0,
        "modern New Conversation button should use its complete title-relative anchor"
      )
    end

    local optionsPoint, optionsRelativeTo, optionsRelativePoint, optionsX, optionsY = chrome.optionsButton:GetPoint()
    assert(
      optionsPoint == "RIGHT" and optionsRelativeTo == chrome.closeButton and optionsRelativePoint == "LEFT" and optionsX == -2 and optionsY == 0,
      chromeType .. " options button should use its complete close-relative anchor"
    )

    local backPoint, backRelativeTo, backRelativePoint, backX, backY = chrome.backButton:GetPoint()
    assert(
      backPoint == "RIGHT" and backRelativeTo == chrome.optionsButton and backRelativePoint == "LEFT" and backX == -2 and backY == 0,
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

  local activeBackground = Theme.COLORS.option_button_active or Theme.COLORS.bg_contact_selected
  local activeIcon = Theme.COLORS.option_button_text_active or Theme.COLORS.text_primary
  assert(colorsMatch(background.color, activeBackground), "visible options should render the cogwheel active background")
  assert(colorsMatch(icon.vertexColor, activeIcon), "visible options should render the cogwheel active icon")
  assert(chrome.backButton:IsShown(), "Back button should be visible while options are active")

  chrome.optionsButton.mouseOver = true
  chrome.optionsButton:GetScript("OnEnter")(chrome.optionsButton)
  local activeHover = Theme.COLORS.option_button_active_hover or activeBackground
  assert(colorsMatch(background.color, activeHover), "hover should remain visible while the cogwheel is active")

  chrome.optionsButton.mouseOver = false
  chrome.optionsButton:GetScript("OnLeave")(chrome.optionsButton)
  assert(colorsMatch(background.color, activeBackground), "leaving hover should restore the cogwheel active background")

  chrome.setOptionsActive(false)
  assert(not colorsMatch(background.color, activeBackground), "hidden options should clear the cogwheel active background")
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

  local optionsBackground, optionsIcon = findButtonVisuals(chrome.optionsButton)
  assert(optionsBackground ~= nil and optionsIcon ~= nil, "built options button should expose rendered visuals")
  local activeBackground = Theme.COLORS.option_button_active or Theme.COLORS.bg_contact_selected
  local activeIcon = Theme.COLORS.option_button_text_active or Theme.COLORS.text_primary

  chrome.optionsButton:GetScript("OnClick")(chrome.optionsButton)
  assert(observedTransitions[1] == true, "show callback should observe already-transitioned panes")
  assert(colorsMatch(optionsBackground.color, activeBackground), "cogwheel show should activate built options paint")
  assert(colorsMatch(optionsIcon.vertexColor, activeIcon), "cogwheel show should activate built options icon")
  assert(chrome.backButton:IsShown(), "cogwheel show should reveal the built Back button")

  local onBack = chrome.backButton:GetScript("OnClick")
  assert(type(onBack) == "function", "built Back button should be wired for navigation")
  onBack(chrome.backButton)

  assert(observedTransitions[2] == true, "Back callback should observe already-restored panes")
  assert(colorsMatch(optionsBackground.color, Theme.COLORS.option_button_bg), "Back should restore the built options resting background")
  assert(colorsMatch(optionsIcon.vertexColor, Theme.COLORS.option_button_text), "Back should restore the built options resting icon")
  assert(not chrome.backButton:IsShown(), "Back should hide after restoring conversation panes")
end

return function()
  test_back_button_renders_themed_visuals()
  test_back_button_hover_uses_theme_colors()
  test_back_button_leave_restores_theme_colors()
  test_back_button_apply_theme_repaints_visuals()
  test_hovered_chrome_controls_keep_hover_paint_when_theme_changes()
  test_chrome_controls_use_branch_specific_anchor_tuples()
  test_cogwheel_active_visual_survives_hover()
  test_navigation_updates_built_chrome_after_panes_transition()
  test_modern_close_button_preserves_hover_and_latest_theme()
end
