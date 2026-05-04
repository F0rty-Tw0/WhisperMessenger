local FakeUI = require("tests.helpers.fake_ui")

local function loadAddonFromToc(addonName, ns)
  for line in io.lines("WhisperMessenger.toc") do
    if line ~= "" and string.sub(line, 1, 2) ~= "##" and not string.match(line, "%.xml$") then
      local chunk = assert(loadfile(line))
      chunk(addonName, ns)
    end
  end
end

return function()
  local ns = {}
  loadAddonFromToc("WhisperMessenger", ns)

  local LayoutBuilder = ns.MessengerWindowLayoutBuilder
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  local frame = factory.CreateFrame("Frame", "MainFrame", parent)
  frame:SetSize(920, 580)

  local layout = LayoutBuilder.Build(factory, frame, { width = 920, height = 580 }, {})

  -- test_options_menu_sidebar_exists

  assert(layout.optionsMenu ~= nil, "optionsMenu sidebar should exist")

  -- test_options_content_pane_exists

  assert(layout.optionsContentPane ~= nil, "optionsContentPane should exist")

  -- test_category_tabs_exist

  assert(layout.generalTab ~= nil, "generalTab should exist")
  assert(layout.appearanceTab ~= nil, "appearanceTab should exist")
  assert(layout.behaviorTab ~= nil, "behaviorTab should exist")
  assert(layout.notificationsTab ~= nil, "notificationsTab should exist")

  -- test_buttons_are_still_present

  assert(layout.resetWindowButton ~= nil, "resetWindowButton should exist")
  assert(layout.resetIconButton ~= nil, "resetIconButton should exist")
  assert(layout.clearAllChatsButton ~= nil, "clearAllChatsButton should exist")

  -- test_options_header_still_exists

  assert(layout.optionsHeader ~= nil, "optionsHeader should exist")

  -- test_tabs_have_labels

  do
    local function hasLabel(btn, expected)
      for _, child in ipairs(btn.children) do
        if child.text and string.find(child.text, expected, 1, true) then
          return true
        end
      end
      return false
    end
    assert(hasLabel(layout.generalTab, "General"), "generalTab should have 'General' label")
    assert(hasLabel(layout.appearanceTab, "Appearance"), "appearanceTab should have 'Appearance' label")
    assert(hasLabel(layout.behaviorTab, "Behavior"), "behaviorTab should have 'Behavior' label")
    assert(hasLabel(layout.notificationsTab, "Notifications"), "notificationsTab should have 'Notifications' label")
  end

  -- test_russian_options_menu_labels

  do
    ns.Localization.Configure({ language = "ruRU" })
    local localizedLayout = LayoutBuilder.Build(factory, frame, { width = 920, height = 580 }, {})

    local function hasLabel(btn, expected)
      for _, child in ipairs(btn.children) do
        if child.text and string.find(child.text, expected, 1, true) then
          return true
        end
      end
      return false
    end

    assert(localizedLayout.optionsHeader.text == "Параметры", "options header should be localized")
    assert(hasLabel(localizedLayout.generalTab, "Общие"), "general tab should be localized")
    assert(hasLabel(localizedLayout.appearanceTab, "Внешний вид"), "appearance tab should be localized")
    assert(hasLabel(localizedLayout.behaviorTab, "Поведение"), "behavior tab should be localized")
    assert(hasLabel(localizedLayout.notificationsTab, "Уведомления"), "notifications tab should be localized")
    assert(hasLabel(localizedLayout.clearAllChatsButton, "Очистить все чаты"), "clear all chats button should be localized")
    assert(localizedLayout.optionsHint.text == "Сбросьте позиции или очистите всю историю переписок.", "options hint should be localized")
    ns.Localization.Configure({ language = "enUS" })
  end

  -- test_buttons_anchored_to_bottom_of_menu

  do
    -- The clearAllChatsButton (bottommost) should anchor to BOTTOMLEFT of optionsMenu
    local btn = layout.clearAllChatsButton
    assert(btn.point ~= nil, "clearAllChatsButton should have a point set")
    local anchor = btn.point[1]
    assert(anchor == "BOTTOMLEFT", "clearAllChatsButton should anchor to BOTTOMLEFT, got: " .. tostring(anchor))
  end
end
