local PhoneSlide = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.PhoneSlide")
local Theme = require("WhisperMessenger.UI.Theme")
local FakeUI = require("tests.helpers.fake_ui")

local WIDTH = 358
local DURATION = Theme.LAYOUT.PHONE_SLIDE_SECONDS

local function build(covered)
  local factory = FakeUI.NewFactory()
  local viewport = factory.CreateFrame("Frame", nil, nil)
  local contactsPane = factory.CreateFrame("Frame", nil, viewport)
  local contentPane = factory.CreateFrame("Frame", nil, viewport)
  contactsPane:SetSize(WIDTH, 600)
  contentPane:SetSize(WIDTH, 600)
  local layout = { phoneViewport = viewport, phoneProgress = 0, contactsPane = contactsPane, contentPane = contentPane }
  local slide = PhoneSlide.Create({
    layout = layout,
    theme = Theme,
    isCovered = function()
      return covered and covered.value == true
    end,
  })
  return slide, layout, viewport, contactsPane, contentPane
end

local function tick(viewport, seconds)
  viewport.scripts.OnUpdate(viewport, seconds)
end

return function()
  -- test_snap_to_chat_shows_only_the_chat_pane
  do
    local slide, _, viewport, contactsPane, contentPane = build()
    slide.snapTo(1)
    assert(contentPane:IsShown() and not contactsPane:IsShown(), "only the chat shows at rest")
    assert(viewport.scripts == nil or viewport.scripts.OnUpdate == nil, "a snap does not animate")
  end

  -- test_animation_shows_both_panes_and_clips_them
  do
    local slide, _, viewport, contactsPane, contentPane = build()
    slide.snapTo(0)
    slide.animateTo(1)
    assert(contactsPane:IsShown() and contentPane:IsShown(), "both panes show mid-slide")
    assert(viewport.clipsChildren == true, "the viewport clips while sliding")
  end

  -- test_animation_moves_the_list_off_to_the_left
  do
    local slide, layout, viewport = build()
    slide.snapTo(0)
    slide.animateTo(1)
    tick(viewport, DURATION / 2)
    assert(layout.phoneProgress > 0 and layout.phoneProgress < 1, "mid-slide progress, got " .. tostring(layout.phoneProgress))
    local _, _, _, x = layout.contactsPane:GetPoint()
    assert(x < 0 and x > -WIDTH, "list partly off the left edge, got " .. tostring(x))
  end

  -- test_finished_animation_rests_without_clipping
  do
    local slide, layout, viewport, contactsPane, contentPane = build()
    local finished = 0
    slide.snapTo(0)
    slide.animateTo(1, function()
      finished = finished + 1
    end)
    tick(viewport, DURATION + 0.01)
    assert(finished == 1, "done callback runs once")
    assert(layout.phoneProgress == 1, "ends on the chat")
    assert(viewport.clipsChildren == false, "clipping ends with the slide, so pop-ups are never cut off")
    assert(viewport.scripts.OnUpdate == nil, "the ticker stops")
    assert(contentPane:IsShown() and not contactsPane:IsShown(), "the off-screen pane hides")
  end

  -- test_reversing_mid_slide_drops_the_first_callback
  do
    local slide, _, viewport = build()
    local first, second = 0, 0
    slide.snapTo(0)
    slide.animateTo(1, function()
      first = first + 1
    end)
    tick(viewport, DURATION / 2)
    slide.animateTo(0, function()
      second = second + 1
    end)
    tick(viewport, DURATION + 0.01)
    assert(first == 0, "the abandoned slide never reports done")
    assert(second == 1, "the new slide reports done")
  end

  -- test_finish_now_completes_a_running_slide
  do
    local slide, layout = build()
    local finished = 0
    slide.snapTo(1)
    slide.animateTo(0, function()
      finished = finished + 1
    end)
    slide.finishNow()
    assert(finished == 1 and layout.phoneProgress == 0, "a hidden window cannot leave a slide hanging")
  end

  -- test_settle_leaves_panes_alone_while_covered
  do
    local covered = { value = false }
    local slide, _, _, contactsPane, contentPane = build(covered)
    slide.snapTo(0)
    contactsPane:Hide()
    contentPane:Hide()
    covered.value = true
    slide.settle()
    assert(not contactsPane:IsShown() and not contentPane:IsShown(), "settings keep the panes hidden")
    covered.value = false
    slide.settle()
    assert(contactsPane:IsShown() and not contentPane:IsShown(), "uncovered: the resting pane returns")
  end

  -- test_client_without_clipping_snaps_instead_of_sliding
  do
    local slide, layout, viewport = build()
    rawset(viewport, "SetClipsChildren", false)
    local finished = 0
    slide.snapTo(0)
    slide.animateTo(1, function()
      finished = finished + 1
    end)
    assert(layout.phoneProgress == 1 and finished == 1, "no clipping, no slide over the window edge")
  end
end
