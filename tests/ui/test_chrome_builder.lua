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
    "expected title text to use text_title/text_primary for readability"
  )
  assert(chrome.newConversationButton ~= nil, "expected a New Conversation button")
  assert(chrome.newConversationButton.point ~= nil, "expected New Conversation button to be anchored")
  assert(
    chrome.newConversationButton.point[1] == "LEFT",
    "expected New Conversation button to anchor from its left edge"
  )
  assert(
    chrome.newConversationButton.point[2] == chrome.title,
    "expected New Conversation button to anchor relative to title"
  )
  assert(
    chrome.newConversationButton.point[3] == "RIGHT",
    "expected New Conversation button to sit to the right of title"
  )
  assert(
    chrome.newConversationButton.point[4] ~= nil
      and chrome.newConversationButton.point[4] >= 0
      and chrome.newConversationButton.point[4] <= 12,
    "expected New Conversation button horizontal offset to stay near title"
  )

  local newConversationIconTexture = nil
  for _, child in ipairs(chrome.newConversationButton.children or {}) do
    if child.frameType == "Texture" and type(child.texturePath) == "string" and child.texturePath ~= "" then
      newConversationIconTexture = child
      break
    end
  end
  assert(newConversationIconTexture ~= nil, "expected New Conversation button to include an icon texture")

  local onEnterScript = chrome.newConversationButton.GetScript and chrome.newConversationButton:GetScript("OnEnter")
    or nil
  local onLeaveScript = chrome.newConversationButton.GetScript and chrome.newConversationButton:GetScript("OnLeave")
    or nil
  assert(type(onEnterScript) == "function", "expected New Conversation button OnEnter script")
  assert(type(onLeaveScript) == "function", "expected New Conversation button OnLeave script")

  local originalGameTooltip = _G.GameTooltip
  local tooltipState = { shown = false, hidden = false }
  _G.GameTooltip = {
    SetOwner = function(_, owner, anchor)
      tooltipState.owner = owner
      tooltipState.anchor = anchor
    end,
    SetText = function(_, text)
      tooltipState.text = text
    end,
    AddLine = function(_, text)
      tooltipState.line = text
    end,
    Show = function()
      tooltipState.shown = true
    end,
    Hide = function()
      tooltipState.hidden = true
    end,
  }

  onEnterScript(chrome.newConversationButton)
  assert(tooltipState.owner == chrome.newConversationButton, "expected tooltip owner to be the New Conversation button")
  assert(tooltipState.anchor == "ANCHOR_TOP", "expected tooltip to anchor above the New Conversation button")
  assert(tooltipState.text == "Start New Whisper", "expected tooltip title text on hover")
  assert(tooltipState.line == "Open an empty conversation thread.", "expected tooltip description text on hover")
  assert(tooltipState.shown == true, "expected tooltip to be shown on hover")

  onLeaveScript(chrome.newConversationButton)
  assert(tooltipState.hidden == true, "expected tooltip to hide on leave")
  _G.GameTooltip = originalGameTooltip

  -- explicit title option overrides Theme.TITLE
  local chrome2 = ChromeBuilder.Build(factory, parent, { width = 920, height = 580 }, { title = "Custom" })
  assert(chrome2.title.text == "Custom", "expected explicit title override to work")

  assert(chrome.titleBarTopBorder ~= nil, "expected title bar top border texture")
  assert(
    colorsMatch(chrome.titleBarTopBorder.color, Theme.COLORS.divider),
    "expected title bar top border to use divider color"
  )
  assert(chrome.titleBarBorder ~= nil, "expected titleBarBorder set")
  assert(
    chrome.titleBarBorder.top == chrome.titleBarTopBorder,
    "expected titleBarTopBorder alias to point at titleBarBorder.top"
  )
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
      "expected title text to repaint with text_title/text_primary token"
    )
  end
  if Theme.SetPreset and previousPreset then
    Theme.SetPreset(previousPreset)
  end
end
