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

  -- test_options_menu_scroll_view_exists

  do
    local optionsMenuScrollView = layout.optionsMenuScrollView
    assert(optionsMenuScrollView ~= nil, "optionsMenuScrollView should exist")
    assert(
      optionsMenuScrollView.scrollFrame.scrollChild == optionsMenuScrollView.content,
      "optionsMenuScrollView should wire its content as the scroll child"
    )
  end

  -- test_options_menu_controls_are_parented_to_scroll_content

  do
    local scrollContent = layout.optionsMenuScrollView.content
    local menuControls = {
      { name = "optionsHeader", control = layout.optionsHeader },
      { name = "generalTab", control = layout.generalTab },
      { name = "appearanceTab", control = layout.appearanceTab },
      { name = "behaviorTab", control = layout.behaviorTab },
      { name = "notificationsTab", control = layout.notificationsTab },
      { name = "iconsTab", control = layout.iconsTab },
      { name = "whatsNewTab", control = layout.whatsNewTab },
      { name = "resetWindowButton", control = layout.resetWindowButton },
      { name = "resetIconButton", control = layout.resetIconButton },
      { name = "clearAllChatsButton", control = layout.clearAllChatsButton },
      { name = "optionsHint", control = layout.optionsHint },
    }
    for _, menuControl in ipairs(menuControls) do
      assert(menuControl.control.parent == scrollContent, menuControl.name .. " should be parented to optionsMenuScrollView content")
    end
  end

  -- test_options_menu_uses_live_height_when_options_panel_shows

  do
    local optionsMenuScrollView = layout.optionsMenuScrollView
    layout.optionsMenu:SetHeight(473)
    layout.optionsPanel:Show()

    assert(optionsMenuScrollView.scrollFrame:GetHeight() == 473, "473px live options menu should set a 473px scroll viewport")
    assert(optionsMenuScrollView.content:GetHeight() == 473, "473px live options menu should set 473px scroll content despite a 580px outer window")
    assert(optionsMenuScrollView.hasOverflow == false, "473px live options menu should not overflow")
  end

  -- test_options_menu_overflows_below_live_content_minimum

  do
    local optionsMenuScrollView = layout.optionsMenuScrollView
    layout.optionsMenu:SetHeight(213)
    layout.optionsPanel:Show()

    assert(optionsMenuScrollView.scrollFrame:GetHeight() == 213, "213px live options menu should set a 213px scroll viewport")
    assert(optionsMenuScrollView.content:GetHeight() == 430, "213px live options menu should keep its 430px minimum content height")
    assert(optionsMenuScrollView.hasOverflow == true, "213px live options menu should overflow")

    optionsMenuScrollView.scrollFrame:SetVerticalScroll(100)
    assert(
      optionsMenuScrollView.scrollFrame:GetVerticalScroll() == 100,
      "overflowing live options menu should retain a nonzero scroll offset before growing"
    )
  end

  -- test_options_menu_clears_overflow_and_clamps_offset_after_growing

  do
    local optionsMenuScrollView = layout.optionsMenuScrollView
    layout.optionsMenu:SetHeight(473)
    layout.optionsPanel:Show()

    assert(optionsMenuScrollView.hasOverflow == false, "grown live options menu should clear overflow")
    assert(optionsMenuScrollView.scrollFrame:GetVerticalScroll() == 0, "grown live options menu should clamp its scroll offset to zero")
  end

  -- test_options_menu_does_not_overflow_at_normal_height

  do
    local optionsMenuScrollView = layout.optionsMenuScrollView
    assert(optionsMenuScrollView.hasOverflow == false, "580px-high options menu should not overflow")
    assert(optionsMenuScrollView.scrollBar.shown == false, "580px-high options menu scrollbar should be hidden")
  end

  -- test_options_menu_overflows_at_minimum_height_after_relayout

  do
    frame:SetSize(920, 320)
    LayoutBuilder.Relayout(layout, 920, 320)

    local optionsMenuScrollView = layout.optionsMenuScrollView
    assert(
      optionsMenuScrollView.scrollFrame:GetHeight() < optionsMenuScrollView.content:GetHeight(),
      "320px-high options menu viewport should be shorter than its content"
    )
    assert(optionsMenuScrollView.hasOverflow == true, "320px-high options menu should overflow")
    assert(optionsMenuScrollView.scrollFrame:GetVerticalScrollRange() > 0, "320px-high options menu should be scrollable")
    assert(optionsMenuScrollView.scrollBar.shown == true, "320px-high options menu scrollbar should be visible")
  end

  -- test_options_content_pane_exists

  assert(layout.optionsContentPane ~= nil, "optionsContentPane should exist")

  -- test_category_tabs_exist

  assert(layout.generalTab ~= nil, "generalTab should exist")
  assert(layout.appearanceTab ~= nil, "appearanceTab should exist")
  assert(layout.behaviorTab ~= nil, "behaviorTab should exist")
  assert(layout.notificationsTab ~= nil, "notificationsTab should exist")
  assert(layout.iconsTab ~= nil, "iconsTab should exist")
  assert(layout.whatsNewTab ~= nil, "whatsNewTab should exist")

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
    assert(hasLabel(layout.iconsTab, "Icons"), "iconsTab should have 'Icons' label")
    assert(hasLabel(layout.whatsNewTab, "What's New"), "whatsNewTab should have 'What's New' label")
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
    assert(hasLabel(localizedLayout.iconsTab, "Значки"), "icons tab should be localized")
    assert(hasLabel(localizedLayout.whatsNewTab, "Что нового"), "what's new tab should be localized")
    assert(hasLabel(localizedLayout.clearAllChatsButton, "Очистить все чаты"), "clear all chats button should be localized")
    assert(
      localizedLayout.optionsHint.text == "Сбросьте позиции или очистите всю историю переписок.",
      "options hint should be localized"
    )
    ns.Localization.Configure({ language = "enUS" })
  end

  -- test_buttons_anchored_to_bottom_of_menu

  do
    -- The clearAllChatsButton (bottommost) should anchor to the scroll content.
    local btn = layout.clearAllChatsButton
    assert(btn.point ~= nil, "clearAllChatsButton should have a point set")
    local anchor, relativeTo = btn.point[1], btn.point[2]
    assert(anchor == "BOTTOMLEFT", "clearAllChatsButton should anchor to BOTTOMLEFT, got: " .. tostring(anchor))
    assert(relativeTo == layout.optionsMenuScrollView.content, "clearAllChatsButton should anchor to menu scroll content")
  end
end
