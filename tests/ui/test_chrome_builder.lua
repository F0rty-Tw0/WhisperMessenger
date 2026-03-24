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

  -- explicit title option overrides Theme.TITLE
  local chrome2 = ChromeBuilder.Build(factory, parent, { width = 920, height = 580 }, { title = "Custom" })
  assert(chrome2.title.text == "Custom", "expected explicit title override to work")
end
