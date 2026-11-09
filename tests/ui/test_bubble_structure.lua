local FakeUI = require("tests.helpers.fake_ui")
local ManualCopyCapture = require("tests.helpers.manual_copy_capture")
local BubbleStructure = require("WhisperMessenger.UI.ChatBubble.BubbleStructure")

return function()
  local factory = FakeUI.NewFactory()

  -- test_create_structure_returns_bg_fills_corners_text
  do
    local frame = factory.CreateFrame("Frame", nil, nil)
    local bgFills, bgCorners, textFS = BubbleStructure.createStructure(frame)
    assert(#bgFills == 5, "expected 5 bgFills, got " .. tostring(#bgFills))
    assert(#bgCorners == 4, "expected 4 bgCorners, got " .. tostring(#bgCorners))
    assert(textFS ~= nil, "expected textFS")
  end

  -- test_create_structure_caches_on_frame
  do
    local frame = factory.CreateFrame("Frame", nil, nil)
    BubbleStructure.createStructure(frame)
    assert(frame._textFS ~= nil, "expected frame._textFS set")
    assert(#frame._bgFills == 5, "expected 5 fills cached")
    assert(#frame._bgCorners == 4, "expected 4 corners cached")
  end

  -- test_create_structure_sets_hyperlink_scripts
  do
    local frame = factory.CreateFrame("Frame", nil, nil)
    BubbleStructure.createStructure(frame)
    assert(frame.scripts ~= nil, "expected scripts table")
    assert(type(frame.scripts.OnHyperlinkEnter) == "function", "expected OnHyperlinkEnter script")
    assert(type(frame.scripts.OnHyperlinkLeave) == "function", "expected OnHyperlinkLeave script")
    assert(type(frame.scripts.OnHyperlinkClick) == "function", "expected OnHyperlinkClick script")
  end

  -- test_create_structure_sends_link_clicks_to_blizzard_chat_handler
  do
    local savedMixin = rawget(_G, "ChatFrameMixin")
    local clicked = nil
    rawset(_G, "ChatFrameMixin", {
      OnHyperlinkClick = function(_self, link)
        clicked = link
      end,
    })
    local frame = factory.CreateFrame("Frame", nil, nil)
    BubbleStructure.createStructure(frame)
    frame.scripts.OnHyperlinkClick(frame, "trade:Player-1:2259:171", "[Tailoring]", "LeftButton")
    rawset(_G, "ChatFrameMixin", savedMixin)
    assert(clicked == "trade:Player-1:2259:171", "bubble link clicks should reach Blizzard's chat click handler")
  end

  -- test_measure_text_height_returns_number
  do
    local frame = factory.CreateFrame("Frame", nil, nil)
    local fontString = frame:CreateFontString(nil, "OVERLAY")
    local result = BubbleStructure.measureTextHeight(fontString, "hello world", 200)
    assert(type(result) == "number", "expected number from measureTextHeight, got " .. type(result))
    assert(result > 0, "expected positive height")
  end

  -- test_create_structure_avoids_protected_url_launch_and_copies_link
  ManualCopyCapture.With(function(copied)
    local savedExternalEventURL = _G.C_ExternalEventURL
    local savedLaunchURL = _G.LaunchURL

    local launchAttempted = false

    _G.C_ExternalEventURL = {
      LaunchURL = function()
        launchAttempted = true
      end,
    }
    _G.LaunchURL = function()
      launchAttempted = true
    end

    local frame = factory.CreateFrame("Frame", nil, nil)
    BubbleStructure.createStructure(frame)
    frame.scripts.OnHyperlinkClick(frame, "addon:WhisperMessenger:url:https://example.com/path?q=1", "https://example.com/path?q=1", "LeftButton")

    assert(launchAttempted == false, "expected URL click to avoid protected LaunchURL APIs")
    assert(copied.text == "https://example.com/path?q=1", "expected URL click to copy URL as safe fallback")

    _G.C_ExternalEventURL = savedExternalEventURL
    _G.LaunchURL = savedLaunchURL
  end)
end
