local FakeUI = require("tests.helpers.fake_ui")


local function colorsMatch(actual, expected)
  if type(actual) ~= "table" or type(expected) ~= "table" then
    return false
  end
  local epsilon = 0.0001
  for i = 1, 4 do
    local a = actual[i] or (i == 4 and 1 or nil)
    local b = expected[i] or (i == 4 and 1 or nil)
    if a == nil or b == nil or math.abs(a - b) > epsilon then
      return false
    end
  end
  return true
end
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

  local ChromeBuilder = ns.MessengerWindowChromeBuilder
  local Theme = ns.Theme
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)

  -- title defaults to Theme.TITLE when no title option is passed
  local chrome = ChromeBuilder.Build(factory, parent, { width = 920, height = 580 }, {})
  assert(
    chrome.title.text == Theme.TITLE,
    "expected title to be '" .. Theme.TITLE .. "' but got '" .. tostring(chrome.title.text) .. "'"
  )
  local expectedTitleColor = Theme.COLORS.text_title or Theme.COLORS.text_primary
  assert(
    colorsMatch(chrome.title.textColor, expectedTitleColor),
    "expected title text to use text_title or text_primary token"
  )

  -- explicit title option overrides Theme.TITLE
  local chrome2 = ChromeBuilder.Build(factory, parent, { width = 920, height = 580 }, { title = "Custom" })
  assert(chrome2.title.text == "Custom", "expected explicit title override to work")

  assert(chrome.titleBarTopBorder ~= nil, "expected title bar top border texture")
  assert(
    colorsMatch(chrome.titleBarTopBorder.color, Theme.COLORS.divider),
    "expected title bar top border to use divider color"
  )
  assert(chrome.titleBarBorder ~= nil, "expected titleBarBorder set")
  assert(chrome.titleBarBorder.top == chrome.titleBarTopBorder, "expected titleBarTopBorder alias to point at titleBarBorder.top")
  assert(chrome.titleBarBorder.left ~= nil, "expected title bar left border")
  assert(chrome.titleBarBorder.right ~= nil, "expected title bar right border")
  assert(chrome.titleBarBorder.bottom == nil, "expected title bar bottom border to be omitted to avoid overlap")

  local previousPreset = Theme.GetPreset and Theme.GetPreset() or nil
  if Theme.SetPreset then
    Theme.SetPreset("plumber_warm")
    chrome.applyTheme(Theme)
    assert(
      colorsMatch(chrome.titleBarTopBorder.color, Theme.COLORS.divider),
      "expected title bar top border to repaint with preset divider color"
    )
    local expectedPresetTitleColor = Theme.COLORS.text_title or Theme.COLORS.text_primary
    assert(
      colorsMatch(chrome.title.textColor, expectedPresetTitleColor),
      "expected title text to repaint with preset title color token"
    )
  end
  if Theme.SetPreset and previousPreset then
    Theme.SetPreset(previousPreset)
  end
end
