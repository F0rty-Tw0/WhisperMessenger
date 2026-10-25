local FakeUI = require("tests.helpers.fake_ui")
local Hyperlinks = require("WhisperMessenger.UI.Hyperlinks")
local IncomingPreview = require("WhisperMessenger.UI.ToggleIcon.IncomingPreview")

local ITEM_LINK = "item:12345::"
local ITEM_TEXT = "|cffa335ee|Hitem:12345::|h[Signet]|h|r"

local function build()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  parent:SetSize(48, 48)
  parent:Show()
  return IncomingPreview.Create(factory, parent, {})
end

local function showExternal(preview, log)
  preview.setExternalPreview({
    sender = "Crafter",
    text = "Needs " .. ITEM_TEXT,
    classTag = "WARRIOR",
    onClick = function()
      log[#log + 1] = "click"
    end,
    onDismiss = function() end,
    onShown = function() end,
  })
end

local function fire(frame, script, ...)
  local handler = frame:GetScript(script)
  assert(type(handler) == "function", "preview has a " .. script .. " handler")
  handler(frame, ...)
end

-- Swaps Hyperlinks' handlers and _G.GetTime for the test, restoring them after.
local function withSpies(clock, run)
  local saved = { enter = Hyperlinks.HandleEnter, click = Hyperlinks.HandleClick, getTime = rawget(_G, "GetTime") }
  local calls = {}
  rawset(Hyperlinks, "HandleEnter", function(owner, link)
    calls[#calls + 1] = { name = "enter", owner = owner, link = link }
  end)
  rawset(Hyperlinks, "HandleClick", function(link, _text, button)
    calls[#calls + 1] = { name = "click", link = link, button = button }
  end)
  rawset(_G, "GetTime", clock and function()
    return clock.now
  end or nil)
  local ok, err = pcall(run, calls)
  rawset(Hyperlinks, "HandleEnter", saved.enter)
  rawset(Hyperlinks, "HandleClick", saved.click)
  rawset(_G, "GetTime", saved.getTime)
  if not ok then
    error(err, 0)
  end
end

return function()
  local function test_preview_link_hover_shows_tooltip()
    withSpies(nil, function(calls)
      local preview = build()
      showExternal(preview, {})
      assert(preview.frame.hyperlinksEnabled == true, "preview enables hyperlinks")
      fire(preview.frame, "OnHyperlinkEnter", ITEM_LINK, "[Signet]")
      local call = calls[1]
      assert(call and call.name == "enter" and call.link == ITEM_LINK and call.owner == preview.frame, "hovering a link shows its tooltip")
    end)
  end

  local function test_preview_link_click_does_not_open_chat()
    withSpies({ now = 10 }, function(calls)
      local preview = build()
      local log = {}
      showExternal(preview, log)
      fire(preview.frame, "OnHyperlinkClick", ITEM_LINK, "[Signet]", "LeftButton")
      fire(preview.frame, "OnMouseUp", "LeftButton")
      assert(calls[1] and calls[1].name == "click" and calls[1].link == ITEM_LINK, "link click is handled as a link")
      assert(#log == 0, "link click does not run the preview's own click")
      assert(preview.frame.shown == true, "preview stays up after a link click")
    end)
  end

  local function test_preview_body_click_still_opens()
    withSpies({ now = 10 }, function()
      local preview = build()
      local log = {}
      showExternal(preview, log)
      fire(preview.frame, "OnMouseUp", "LeftButton")
      assert(table.concat(log, ",") == "click", "body click runs the preview's click")
    end)
  end

  local function test_body_click_long_after_unanswered_link_click_still_opens()
    local clock = { now = 10 }
    withSpies(clock, function()
      local preview = build()
      local log = {}
      showExternal(preview, log)
      fire(preview.frame, "OnHyperlinkClick", ITEM_LINK, "[Signet]", "LeftButton")
      clock.now = 15
      fire(preview.frame, "OnMouseUp", "LeftButton")
      assert(table.concat(log, ",") == "click", "a stale link click does not swallow a later body click")
    end)
  end

  test_preview_link_hover_shows_tooltip()
  test_preview_link_click_does_not_open_chat()
  test_preview_body_click_still_opens()
  test_body_click_long_after_unanswered_link_click_still_opens()
end
