local FakeUI = require("tests.helpers.fake_ui")
local Hyperlinks = require("WhisperMessenger.UI.Hyperlinks")
local IncomingPreview = require("WhisperMessenger.UI.ToggleIcon.IncomingPreview")

local ITEM_LINK = "item:12345::"

local function build(onOpenPreview)
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  parent:SetSize(48, 48)
  parent:Show()
  local state = { opened = 0, dismissed = 0 }
  state.preview = IncomingPreview.Create(factory, parent, {
    onOpenPreview = onOpenPreview and function()
      state.opened = state.opened + 1
    end or nil,
    onDismissPreview = function()
      state.dismissed = state.dismissed + 1
    end,
  })
  return state
end

local function fire(frame, script, ...)
  local handler = frame:GetScript(script)
  assert(type(handler) == "function", "preview has a " .. script .. " handler")
  handler(frame, ...)
end

return function()
  local function test_left_click_on_a_whisper_preview_asks_to_open_it()
    local state = build(true)
    state.preview.setIncomingPreview("Jaina", "Need help?", "MAGE")
    fire(state.preview.frame, "OnMouseUp", "LeftButton")
    assert(state.opened == 1, "left-click opens the chat once, got " .. state.opened)
  end

  local function test_left_click_without_an_open_callback_does_nothing()
    local state = build(false)
    state.preview.setIncomingPreview("Jaina", "Need help?", "MAGE")
    fire(state.preview.frame, "OnMouseUp", "LeftButton")
    assert(state.preview.frame.shown == true, "preview stays when nothing handles the click")
  end

  local function test_right_click_still_dismisses_and_does_not_open()
    local state = build(true)
    state.preview.setIncomingPreview("Jaina", "Need help?", "MAGE")
    fire(state.preview.frame, "OnMouseUp", "RightButton")
    assert(state.dismissed == 1 and state.opened == 0, "right-click only dismisses")
    assert(state.preview.frame.shown ~= true, "right-click hides the preview")
  end

  local function test_item_link_click_does_not_open_the_chat()
    local saved = { enter = Hyperlinks.HandleEnter, click = Hyperlinks.HandleClick }
    rawset(Hyperlinks, "HandleClick", function() end)
    local state = build(true)
    state.preview.setIncomingPreview("Jaina", "Look |Hitem:12345::|h[Signet]|h", "MAGE")
    local ok, err = pcall(function()
      fire(state.preview.frame, "OnHyperlinkClick", ITEM_LINK, "[Signet]", "LeftButton")
      fire(state.preview.frame, "OnMouseUp", "LeftButton")
    end)
    rawset(Hyperlinks, "HandleEnter", saved.enter)
    rawset(Hyperlinks, "HandleClick", saved.click)
    assert(ok, err)
    assert(state.opened == 0, "a link click opens the item, not the chat")
  end

  local function test_addon_preview_left_click_runs_its_own_click_only()
    local state = build(true)
    local clicks = 0
    state.preview.setExternalPreview({
      sender = "Crafter",
      text = "Needs Plate Belt",
      classTag = "WARRIOR",
      onClick = function()
        clicks = clicks + 1
      end,
      onDismiss = function() end,
      onShown = function() end,
    })
    fire(state.preview.frame, "OnMouseUp", "LeftButton")
    assert(clicks == 1 and state.opened == 0, "an addon preview runs its onClick and never opens a whisper")
  end

  test_left_click_on_a_whisper_preview_asks_to_open_it()
  test_left_click_without_an_open_callback_does_nothing()
  test_right_click_still_dismisses_and_does_not_open()
  test_item_link_click_does_not_open_the_chat()
  test_addon_preview_left_click_runs_its_own_click_only()
end
