-- A link click in our frames must start in Blizzard's own chat-frame click
-- handler, not in an addon function: another player's profession link opens
-- a window that casts a protected spell, which the game blocks ("Interface
-- action failed because of an AddOn") when addon code started the click.
-- Our extras (URL copy, the caller's callback) are hooked to run after it.
local FakeUI = require("tests.helpers.fake_ui")
local ManualCopyCapture = require("tests.helpers.manual_copy_capture")
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

-- Runs fn with a stand-in ChatFrameMixin (or none) and a recording SetItemRef.
local function withChatHandler(mixin, fn)
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
end

local function newChatMixin(calls)
  return {
    OnHyperlinkClick = function(_self, link)
      calls[#calls + 1] = "blizzard " .. link
    end,
  }
end

return function()
  local factory = FakeUI.NewFactory()

  -- test_enable_on_sets_blizzard_chat_click_handler_as_the_script
  do
    local mixin = newChatMixin({})
    withChatHandler(mixin, function()
      local frame = factory.CreateFrame("Frame", nil, nil)
      Hyperlinks.EnableOn(frame)
      assert(frame:GetScript("OnHyperlinkClick") == mixin.OnHyperlinkClick, "link clicks should start in Blizzard's own chat click handler")
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
end
