-- The fake frame factory wires Blizzard templates the way the live client
-- does, including comma-separated template lists.
local FakeUI = require("tests.helpers.fake_ui")

local function eq(actual, expected, label)
  assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

return function()
  local savedSetItemRef = _G.SetItemRef
  local calls = {}
  rawset(_G, "SetItemRef", function(link, text, button)
    calls[#calls + 1] = { link = link, text = text, button = button }
  end)

  local ok, err = pcall(function()
    -- test_inline_hyperlink_template_click_calls_set_item_ref
    local factory = FakeUI.NewFactory()
    local inline = factory.CreateFrame("Button", nil, nil, "InlineHyperlinkFrameTemplate")
    local handler = inline:GetScript("OnHyperlinkClick")
    assert(type(handler) == "function", "inline template sets OnHyperlinkClick")
    handler(inline, "item:1", "[x]", "LeftButton")
    eq(#calls, 1, "SetItemRef calls")
    eq(calls[1].link, "item:1", "link")
    eq(calls[1].text, "[x]", "text")
    eq(calls[1].button, "LeftButton", "button")

    -- test_combined_template_applies_each_name
    local combinedName = "TooltipBackdropTemplate, InlineHyperlinkFrameTemplate"
    local combined = factory.CreateFrame("Frame", nil, nil, combinedName)
    assert(combined.templateHyperlinkClick ~= nil, "combined template keeps the hyperlink handler")
    eq(combined.template, combinedName, "template string")

    -- test_single_template_unchanged
    local secure = factory.CreateFrame("Button", nil, nil, "SecureActionButtonTemplate")
    eq(secure.secureClicks, 0, "secureClicks")
  end)

  rawset(_G, "SetItemRef", savedSetItemRef)
  if not ok then
    error(err, 0)
  end
end
