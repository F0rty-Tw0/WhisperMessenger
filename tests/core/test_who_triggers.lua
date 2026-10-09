local WhoLookup = require("WhisperMessenger.Transport.WhoLookup")
local WhoTriggers = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.WhoTriggers")
local Env = require("tests.helpers.who_lookup_env")

local KEY = "wow::WOW::jaina"

-- Real WhoLookup: a click asks, the window closes, then a send to the same
-- contact must not ask again.
local function test_click_then_send_asks_once_per_contact()
  Env.Case("click then send", nil, function(env)
    Env.AddStranger(env, KEY, "Jaina")
    local triggers = WhoTriggers.Create(env.runtime)
    triggers.onContactClicked({ conversationKey = KEY })
    assert(#env.sent == 1, "click should send one who")
    WhoLookup.OnWhoListUpdate()
    Env.RunAfters(env)
    env.clock = env.clock + 60
    Env.FireDueTimers(env)
    assert(WhoLookup.IsWindowOpen() == false, "window should be closed")
    local wrapped = triggers.wrapSend(function()
      return true
    end)
    assert(wrapped({ channel = "WOW", conversationKey = KEY, text = "hi" }) == true, "send result")
    assert(#env.sent == 1, "send to an asked contact should not ask again, sent " .. #env.sent)
  end)
end

local function withSpy(fn, tryFor)
  local original = WhoLookup.TryFor
  local calls = {}
  WhoLookup.TryFor = tryFor or function(rt, key)
    calls[#calls + 1] = { runtime = rt, key = key }
    return true
  end
  local ok, err = pcall(fn, calls)
  WhoLookup.TryFor = original
  if not ok then
    error(err, 0)
  end
end

return function()
  local runtime = {}

  -- test_whisper_send_asks_who_then_sends_and_passes_result_through
  withSpy(function(calls)
    local order = {}
    local wrapped = WhoTriggers.Create(runtime).wrapSend(function(payload)
      order[#order + 1] = "send:" .. tostring(#calls)
      return payload.text == "hi" and "sent-result" or nil
    end)
    local result = wrapped({ channel = "WOW", conversationKey = KEY, text = "hi" })
    assert(#calls == 1 and calls[1].key == KEY and calls[1].runtime == runtime, "who asked for the whisper contact")
    assert(order[1] == "send:1", "who asked before the original send")
    assert(result == "sent-result", "original send result passed through")
  end)

  -- test_group_send_does_not_ask_who
  withSpy(function(calls)
    local wrapped = WhoTriggers.Create(runtime).wrapSend(function()
      return true
    end)
    assert(wrapped({ channel = "PARTY", conversationKey = "party::me", text = "x" }) == true, "group send result")
    assert(#calls == 0, "no who for a group send")
  end)

  -- test_whisper_send_without_key_does_not_ask_who
  withSpy(function(calls)
    local wrapped = WhoTriggers.Create(runtime).wrapSend(function()
      return false
    end)
    assert(wrapped({ channel = "WOW", text = "x" }) == false, "keyless send result")
    assert(#calls == 0, "no who without a conversation key")
  end)

  -- test_contact_click_asks_who_for_the_item
  withSpy(function(calls)
    local triggers = WhoTriggers.Create(runtime)
    triggers.onContactClicked({ conversationKey = KEY })
    triggers.onContactClicked(nil)
    triggers.onContactClicked({})
    assert(#calls == 1 and calls[1].key == KEY, "who asked once, only for the keyed item")
  end)

  -- test_throwing_who_never_breaks_click_or_send
  withSpy(function()
    local triggers = WhoTriggers.Create(runtime)
    triggers.onContactClicked({ conversationKey = KEY })
    local wrapped = triggers.wrapSend(function()
      return "still-sent"
    end)
    assert(wrapped({ channel = "WOW", conversationKey = KEY }) == "still-sent", "send survives a throwing who")
  end, function()
    error("boom")
  end)

  test_click_then_send_asks_once_per_contact()
end
