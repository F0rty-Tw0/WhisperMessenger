local FakeUI = require("tests.helpers.fake_ui")
local BubbleStructure = require("WhisperMessenger.UI.ChatBubble.BubbleStructure")

return function()
  local factory = FakeUI.NewFactory()

  -- test_create_structure_returns_bg_fills_corners_text
  do
    local frame = factory.CreateFrame("Frame", nil, nil)
    local bgFills, bgCorners, textFS = BubbleStructure.createStructure(frame)
    assert(type(bgFills) == "table", "expected bgFills table")
    assert(#bgFills == 5, "expected 5 bgFills, got " .. tostring(#bgFills))
    assert(type(bgCorners) == "table", "expected bgCorners table")
    assert(#bgCorners == 4, "expected 4 bgCorners, got " .. tostring(#bgCorners))
    assert(textFS ~= nil, "expected textFS")
  end

  -- test_create_structure_caches_on_frame
  do
    local frame = factory.CreateFrame("Frame", nil, nil)
    BubbleStructure.createStructure(frame)
    assert(frame._bgFills ~= nil, "expected frame._bgFills set")
    assert(frame._bgCorners ~= nil, "expected frame._bgCorners set")
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

  -- test_measure_text_height_returns_number
  do
    local frame = factory.CreateFrame("Frame", nil, nil)
    local fontString = frame:CreateFontString(nil, "OVERLAY")
    local result = BubbleStructure.measureTextHeight(fontString, "hello world", 200)
    assert(type(result) == "number", "expected number from measureTextHeight, got " .. type(result))
    assert(result > 0, "expected positive height")
  end

  -- test CORNER_R is exported
  do
    assert(type(BubbleStructure.CORNER_R) == "number", "expected CORNER_R to be a number")
    assert(BubbleStructure.CORNER_R == 8, "expected CORNER_R == 8")
  end
end
