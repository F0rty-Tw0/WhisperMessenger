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
  local Theme = ns.Theme
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  local frame = factory.CreateFrame("Frame", "MainFrame", parent)
  frame:SetSize(920, 580)

  local layout = LayoutBuilder.Build(factory, frame, { width = 920, height = 580 }, {})

  -- All three option buttons should exist
  assert(layout.resetWindowButton, "resetWindowButton should exist")
  assert(layout.resetIconButton, "resetIconButton should exist")
  assert(layout.clearAllChatsButton, "clearAllChatsButton should exist")

  -- Buttons should NOT use UIPanelButtonTemplate (modern style)
  assert(
    layout.resetWindowButton.template == nil,
    "resetWindowButton should not use a template, got: " .. tostring(layout.resetWindowButton.template)
  )
  assert(layout.resetIconButton.template == nil, "resetIconButton should not use a template, got: " .. tostring(layout.resetIconButton.template))
  assert(
    layout.clearAllChatsButton.template == nil,
    "clearAllChatsButton should not use a template, got: " .. tostring(layout.clearAllChatsButton.template)
  )

  -- Each button should have a background texture child and a label
  local function assertModernButton(btn, expectedLabel)
    -- Button should have children (bg texture + label fontstring)
    assert(#btn.children >= 2, expectedLabel .. " should have at least 2 children (bg + label)")

    -- Find the label child with the expected text
    local foundLabel = false
    for _, child in ipairs(btn.children) do
      if child.text == expectedLabel then
        foundLabel = true
        break
      end
    end
    assert(foundLabel, expectedLabel .. " button should have a label with text '" .. expectedLabel .. "'")
  end

  assertModernButton(layout.resetWindowButton, "Reset Window Position")
  assertModernButton(layout.resetIconButton, "Reset Icon Position")
  assertModernButton(layout.clearAllChatsButton, "Clear All Chats")

  -- Buttons should have hover scripts (OnEnter / OnLeave)
  assert(layout.resetWindowButton.scripts and layout.resetWindowButton.scripts.OnEnter, "resetWindowButton should have OnEnter script")
  assert(layout.resetWindowButton.scripts and layout.resetWindowButton.scripts.OnLeave, "resetWindowButton should have OnLeave script")
  assert(layout.clearAllChatsButton.scripts and layout.clearAllChatsButton.scripts.OnEnter, "clearAllChatsButton should have OnEnter script")
  assert(layout.clearAllChatsButton.scripts and layout.clearAllChatsButton.scripts.OnLeave, "clearAllChatsButton should have OnLeave script")

  -- Hint text should mention all three actions
  assert(layout.optionsHint, "optionsHint should exist")
  assert(
    string.find(layout.optionsHint.text, "clear", 1, true) or string.find(layout.optionsHint.text, "Clear", 1, true),
    "optionsHint should mention clearing chats"
  )

  local expectedHintWidth = layout.contactsWidth - ((Theme.CONTENT_PADDING or 0) * 2)
  assert(layout.optionsHint.width == expectedHintWidth, "optionsHint should size to the current menu width")
  assert(layout.optionsHint.wordWrap == true, "optionsHint should enable word wrap")
  assert(layout.optionsHint.justifyH == "LEFT", "optionsHint should left-align wrapped text")
end
