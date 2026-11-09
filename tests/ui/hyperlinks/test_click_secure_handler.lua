-- A link click in our frames goes to Blizzard's own chat-frame click handler,
-- so links open the way they do in Blizzard chat. Our extras (URL copy, the
-- caller's callback) run after it. The click script itself is addon code; see
-- test_click_combat_item_ref for the combat click that skips the handler.
local FakeUI = require("tests.helpers.fake_ui")
local ManualCopyCapture = require("tests.helpers.manual_copy_capture")
local WriteWatch = require("tests.helpers.write_watch")
local Hyperlinks = require("WhisperMessenger.UI.Hyperlinks")

local URL_LINK = "addon:WhisperMessenger:url:https://example.com/help"
local TRADE_LINK = "trade:Player-1234-ABCDEF:2259:171"

local function fireClick(frame, link)
  local script = frame:GetScript("OnHyperlinkClick")
  script(frame, link, "[" .. link .. "]", "LeftButton")
  for _, hook in ipairs(frame._hookScripts and frame._hookScripts.OnHyperlinkClick or {}) do
    hook(frame, link, "[" .. link .. "]", "LeftButton")
  end
end

-- Field writes into the stand-in ChatFrameMixin. A click may call Blizzard's
-- handler but never assign into the mixin: the write taints that slot, even
-- with Blizzard's own function written back.
local mixinWrites = {}

local function watched(mixin)
  return WriteWatch.Wrap("ChatFrameMixin", mixin, mixinWrites)
end

-- Runs fn with a stand-in ChatFrameMixin (or none) and a recording SetItemRef.
local function withChatHandler(mixin, fn)
  mixinWrites = {}
  local saved = { mixin = rawget(_G, "ChatFrameMixin"), setItemRef = rawget(_G, "SetItemRef") }
  local calls = {}
  rawset(_G, "ChatFrameMixin", mixin)
  rawset(_G, "SetItemRef", function(link)
    calls[#calls + 1] = "SetItemRef " .. link
  end)
  local ok, err = pcall(fn, calls)
  rawset(_G, "ChatFrameMixin", saved.mixin)
  rawset(_G, "SetItemRef", saved.setItemRef)
  if not ok then
    error(err, 0)
  end
  assert(#mixinWrites == 0, "a click assigned " .. table.concat(mixinWrites, ", "))
end

local function newChatMixin(calls)
  return watched({
    OnHyperlinkClick = function(_self, link)
      calls[#calls + 1] = "blizzard " .. link
    end,
  })
end

return function()
  local factory = FakeUI.NewFactory()

  -- test_link_click_forwards_frame_and_arguments_to_blizzard_handler
  do
    local received = {}
    local mixin = watched({
      OnHyperlinkClick = function(self, link, text, button)
        received = { self = self, link = link, text = text, button = button }
      end,
    })
    withChatHandler(mixin, function()
      local frame = factory.CreateFrame("Frame", nil, nil)
      Hyperlinks.EnableOn(frame)
      frame:GetScript("OnHyperlinkClick")(frame, TRADE_LINK, "[Tailoring]", "RightButton")
      assert(received.self == frame and received.link == TRADE_LINK, "Blizzard's handler should get the frame and the link")
      assert(received.text == "[Tailoring]" and received.button == "RightButton", "Blizzard's handler should get the text and the button")
    end)
  end

  -- test_url_click_copies_after_blizzard_handler
  ManualCopyCapture.With(function(copied)
    withChatHandler(nil, function(calls)
      rawset(_G, "ChatFrameMixin", newChatMixin(calls))
      local frame = factory.CreateFrame("Frame", nil, nil)
      Hyperlinks.EnableOn(frame)
      fireClick(frame, URL_LINK)
      assert(calls[1] == "blizzard " .. URL_LINK, "Blizzard's handler should get the click first, got " .. tostring(calls[1]))
      assert(copied.count == 1 and copied.text == "https://example.com/help", "a URL click should still copy the URL, got " .. tostring(copied.text))
    end)
  end)

  -- test_link_click_runs_callback_after_blizzard_handler
  do
    withChatHandler(nil, function(calls)
      rawset(_G, "ChatFrameMixin", newChatMixin(calls))
      local frame = factory.CreateFrame("Frame", nil, nil)
      Hyperlinks.EnableOn(frame, function()
        calls[#calls + 1] = "callback"
      end)
      fireClick(frame, TRADE_LINK)
      assert(#calls == 2, "expected the handler and the callback once each, got " .. #calls)
      assert(calls[1] == "blizzard " .. TRADE_LINK and calls[2] == "callback", "the callback should run after Blizzard's handler")
    end)
  end

  -- test_hook_does_not_route_the_link_a_second_time
  do
    withChatHandler(nil, function(calls)
      rawset(_G, "ChatFrameMixin", newChatMixin(calls))
      local frame = factory.CreateFrame("Frame", nil, nil)
      Hyperlinks.EnableOn(frame)
      fireClick(frame, TRADE_LINK)
      assert(#calls == 1, "only Blizzard's handler should route the link, got " .. table.concat(calls, ", "))
    end)
  end

  -- test_without_blizzard_handler_click_routes_through_set_item_ref
  do
    withChatHandler(nil, function(calls)
      local frame = factory.CreateFrame("Frame", nil, nil)
      Hyperlinks.EnableOn(frame, function()
        calls[#calls + 1] = "callback"
      end)
      fireClick(frame, TRADE_LINK)
      assert(calls[1] == "SetItemRef " .. TRADE_LINK, "without Blizzard's handler the click should reach SetItemRef, got " .. tostring(calls[1]))
      assert(calls[2] == "callback" and #calls == 2, "the callback should still run once, got " .. table.concat(calls, ", "))
    end)
  end

  -- test_callback_runs_once_and_error_surfaces_when_blizzard_handler_throws
  do
    local callbacks = 0
    local mixin = watched({
      OnHyperlinkClick = function()
        error("blizzard handler failed", 0)
      end,
    })
    withChatHandler(mixin, function()
      local frame = factory.CreateFrame("Frame", nil, nil)
      Hyperlinks.EnableOn(frame, function()
        callbacks = callbacks + 1
      end)
      local clickScript = assert(frame:GetScript("OnHyperlinkClick"))
      local ok, err = pcall(clickScript, frame, TRADE_LINK, "[Tailoring]", "LeftButton")
      assert(callbacks == 1, "the callback should still run once when Blizzard's handler throws, ran " .. callbacks)
      assert(not ok and err == "blizzard handler failed", "the handler's error should still surface, got " .. tostring(err))
    end)
  end
end
