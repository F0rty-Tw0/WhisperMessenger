local ConversationPane = require("WhisperMessenger.UI.ConversationPane")
local Theme = require("WhisperMessenger.UI.Theme")
local FakeUI = require("tests.helpers.fake_ui")

local contact = { displayName = "Jaina", conversationKey = "wow::WOW::jaina" }
local conv = { messages = {} }

local function newPane(factory, getter)
  local parent = factory.CreateFrame("Frame", "Parent", nil)
  parent:SetSize(600, 420)
  return ConversationPane.Create(factory, parent, contact, conv, { getContactInfoLines = getter })
end

local function assertAnchored(frame, point, relativeTo, relativePoint, label)
  for _, pt in ipairs(frame.points or {}) do
    if pt[1] == point and pt[2] == relativeTo and pt[3] == relativePoint then
      return
    end
  end
  error(label)
end

local function assertColorEquals(actual, expected, label)
  assert(type(actual) == "table", label .. ": missing color")
  for i = 1, 4 do
    assert(math.abs((actual[i] or 1) - (expected[i] or 1)) < 0.0001, label .. ": channel " .. i)
  end
end

return function()
  local factory = FakeUI.NewFactory()
  local lines = {}
  local calls = 0
  local function getter()
    calls = calls + 1
    return lines
  end

  -- test_strip_starts_hidden
  do
    lines = {}
    local pane = newPane(factory, getter)
    assert(pane.infoStrip.frame:IsShown() == false, "hidden without lines")
    assert(pane.infoStrip.height() == 0, "no height while hidden")
  end

  -- test_one_line_shows_a_22px_bar_under_the_header
  do
    lines = {}
    local pane = newPane(factory, getter)
    lines = { "Craft Alert: Belt" }
    ConversationPane.Refresh(pane, contact, conv)
    local strip = pane.infoStrip
    assert(strip.frame:IsShown() == true, "shown with a line")
    assert(strip.height() == 22, "one row is 22px, got " .. strip.height())
    assert(strip.rows[1].text == "Craft Alert: Belt", "row text")
    assertAnchored(strip.frame, "TOPLEFT", pane.headerFrame, "BOTTOMLEFT", "strip hangs from the header")
  end

  -- test_bar_uses_the_header_fill
  do
    local pane = newPane(factory, getter)
    assertColorEquals(pane.infoStrip.bg.color, Theme.COLORS.bg_header, "strip fill")
  end

  -- test_thread_top_follows_the_strip
  do
    lines = {}
    local pane = newPane(factory, getter)
    lines = { "Craft Alert: Belt" }
    ConversationPane.Refresh(pane, contact, conv)
    local _, rel, relPoint = pane.transcript.scrollFrame:GetPoint()
    assert(rel == pane.infoStrip.frame and relPoint == "BOTTOMLEFT", "thread starts under the strip")
    lines = {}
    ConversationPane.Refresh(pane, contact, conv)
    _, rel, relPoint = pane.transcript.scrollFrame:GetPoint()
    assert(rel == pane.headerFrame and relPoint == "BOTTOMLEFT", "thread goes back under the header")
  end

  -- test_two_sources_two_rows
  do
    lines = { "A", "B" }
    local pane = newPane(factory, getter)
    assert(pane.infoStrip.height() == 44, "two rows are 44px, got " .. pane.infoStrip.height())
    assert(pane.infoStrip.rows[1].text == "A" and pane.infoStrip.rows[2].text == "B", "both rows set")
  end

  -- test_rows_are_capped
  do
    lines = {}
    for index = 1, 60 do
      lines[index] = "Line " .. index
    end
    local pane = newPane(factory, getter)
    local strip = pane.infoStrip
    assert(strip.height() == 22 * 3, "three rows at most, got " .. strip.height())
    assert(#strip.rows == 3, "no rows built past the cap, got " .. #strip.rows)
    assert(strip.rows[3].text == "Line 3", "the first lines show")
  end

  -- test_viewport_shrinks_by_the_strip_height
  do
    lines = {}
    local pane = newPane(factory, getter)
    local before = pane.transcript.viewportHeight
    lines = { "Craft Alert: Belt" }
    ConversationPane.Refresh(pane, contact, conv)
    assert(pane.transcript.viewportHeight == before - 22, "viewport shrank by 22, got " .. pane.transcript.viewportHeight .. " from " .. before)
    lines = {}
    ConversationPane.Refresh(pane, contact, conv)
    assert(pane.transcript.viewportHeight == before, "viewport restored")
    lines = { "Craft Alert: Belt" }
    ConversationPane.Refresh(pane, contact, conv)
    ConversationPane.Relayout(pane, 600, 420)
    assert(pane.transcript.viewportHeight == before - 22, "a later relayout keeps the strip height")
  end

  -- test_fewer_lines_hide_the_spare_rows
  do
    lines = { "A", "B" }
    local pane = newPane(factory, getter)
    lines = { "A" }
    ConversationPane.Refresh(pane, contact, conv)
    local rowFrames = pane.infoStrip.rowFrames
    assert(rowFrames[1]:IsShown() == true and rowFrames[2]:IsShown() == false, "only the first row shows")
  end

  -- test_no_selected_contact_hides_the_strip
  do
    lines = { "Craft Alert: Belt" }
    local pane = newPane(factory, getter)
    assert(pane.infoStrip.frame:IsShown() == true)
    calls = 0
    ConversationPane.Refresh(pane, nil, nil)
    assert(pane.infoStrip.frame:IsShown() == false, "hidden without a contact")
    assert(calls == 0, "getter not called without a contact")
  end

  -- test_hovering_an_item_link_shows_its_tooltip
  do
    lines = { "Craft Alert: |cffa335ee|Hitem:12345::|h[Signet]|h|r" }
    local pane = newPane(factory, getter)
    local frame = pane.infoStrip.rowFrames[1]
    local savedTooltip = rawget(_G, "GameTooltip")
    local shown = {}
    _G.GameTooltip = {
      SetOwner = function(_self, owner)
        shown.owner = owner
      end,
      SetHyperlink = function(_self, link)
        shown.link = link
      end,
      Show = function()
        shown.visible = true
      end,
      Hide = function()
        shown.visible = false
      end,
    }
    assert(frame.mouseEnabled == true, "the row takes the mouse")
    assert(frame.hyperlinksEnabled == true, "the row enables hyperlinks")
    frame.scripts.OnHyperlinkEnter(frame, "item:12345::", "[Signet]")
    assert(shown.owner == frame and shown.link == "item:12345::" and shown.visible == true, "item tooltip shown")
    frame.scripts.OnHyperlinkLeave(frame)
    assert(shown.visible == false, "tooltip hidden on leave")
    _G.GameTooltip = savedTooltip
  end

  -- test_option_is_optional
  do
    local pane = newPane(factory, nil)
    ConversationPane.Refresh(pane, contact, conv)
    assert(pane.infoStrip.frame:IsShown() == false, "hidden without the option")
    assert(pane.infoStrip.height() == 0)
  end
end
