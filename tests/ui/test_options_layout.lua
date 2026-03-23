local FakeUI = require("tests.helpers.fake_ui")

local function loadAddonFromToc(addonName, ns)
  for line in io.lines("WhisperMessenger.toc") do
    if line ~= "" and string.sub(line, 1, 2) ~= "##" then
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

  -- -----------------------------------------------------------------------
  -- test_options_menu_sidebar_exists
  -- -----------------------------------------------------------------------
  assert(layout.optionsMenu ~= nil, "optionsMenu sidebar should exist")

  -- -----------------------------------------------------------------------
  -- test_options_content_pane_exists
  -- -----------------------------------------------------------------------
  assert(layout.optionsContentPane ~= nil, "optionsContentPane should exist")

  -- -----------------------------------------------------------------------
  -- test_general_toggle_exists
  -- -----------------------------------------------------------------------
  assert(layout.generalToggle ~= nil, "generalToggle button should exist")

  -- -----------------------------------------------------------------------
  -- test_buttons_are_still_present
  -- -----------------------------------------------------------------------
  assert(layout.resetWindowButton ~= nil, "resetWindowButton should exist")
  assert(layout.resetIconButton ~= nil, "resetIconButton should exist")
  assert(layout.clearAllChatsButton ~= nil, "clearAllChatsButton should exist")

  -- -----------------------------------------------------------------------
  -- test_options_header_still_exists
  -- -----------------------------------------------------------------------
  assert(layout.optionsHeader ~= nil, "optionsHeader should exist")

  -- -----------------------------------------------------------------------
  -- test_general_toggle_has_label
  -- -----------------------------------------------------------------------
  do
    local foundLabel = false
    for _, child in ipairs(layout.generalToggle.children) do
      if child.text and (string.find(child.text, "General", 1, true)) then
        foundLabel = true
        break
      end
    end
    assert(foundLabel, "generalToggle should have a label containing 'General'")
  end

  -- -----------------------------------------------------------------------
  -- test_buttons_anchored_to_bottom_of_menu
  -- -----------------------------------------------------------------------
  do
    -- The clearAllChatsButton (bottommost) should anchor to BOTTOMLEFT of optionsMenu
    local btn = layout.clearAllChatsButton
    assert(btn.point ~= nil, "clearAllChatsButton should have a point set")
    local anchor = btn.point[1]
    assert(anchor == "BOTTOMLEFT", "clearAllChatsButton should anchor to BOTTOMLEFT, got: " .. tostring(anchor))
  end
end
