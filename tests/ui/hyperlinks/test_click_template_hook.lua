-- Frames built with InlineHyperlinkFrameTemplate keep the template's own click
-- script (Blizzard code, so the windows it opens stay untainted). BindClick
-- only post-hooks it for what Blizzard can't do: our encoded player links and
-- URL links. Frames without the template keep the addon click script, which
-- decodes an encoded player link before routing it.
local FakeUI = require("tests.helpers.fake_ui")
local LinkHooksEnv = require("tests.helpers.link_hooks_env")
local ManualCopyCapture = require("tests.helpers.manual_copy_capture")
local LinkClicks = require("WhisperMessenger.UI.Hyperlinks.LinkClicks")

local TEMPLATE = "InlineHyperlinkFrameTemplate"
local ITEM_LINK = "item:6948"
local URL_LINK = "addon:WhisperMessenger:url:https://example.com/help"
local ENCODED_LINK = "addon:WhisperMessenger:player:Name-Realm:12"
local ENCODED_TEXT = "|Haddon:WhisperMessenger:player:Name-Realm:12|h[Name]|h"
local DECODED_LINK = "player:Name-Realm:12"
local DECODED_TEXT = "|Hplayer:Name-Realm:12|h[Name]|h"
local STUBBED = { "SetItemRef", "ChatFrameMixin", "IsModifiedClick" }

-- Runs fn(calls) with a recording SetItemRef and ChatFrameMixin, and
-- IsModifiedClick answering chatLink. Puts every stubbed global back, also
-- when fn fails.
local function withStubs(chatLink, fn)
  local saved = {}
  for _, key in ipairs(STUBBED) do
    saved[key] = rawget(_G, key)
  end
  local calls = { setItemRef = {}, mixin = {} }
  rawset(_G, "SetItemRef", function(link)
    table.insert(calls.setItemRef, link)
  end)
  rawset(_G, "ChatFrameMixin", {
    OnHyperlinkClick = function(_self, link, text)
      table.insert(calls.mixin, { link = link, text = text })
    end,
  })
  rawset(_G, "IsModifiedClick", function(action)
    return action == "CHATLINK" and chatLink
  end)
  local ok, err = pcall(fn, calls)
  for _, key in ipairs(STUBBED) do
    rawset(_G, key, saved[key])
  end
  if not ok then
    error(err, 0)
  end
end

-- Runs fn(env, input, calls) with LinkHooks registered on a composer input.
-- SetItemRef is set before RegisterInput, so LinkHooks hooks the recorder.
local function withComposer(focused, fn)
  withStubs(true, function(calls)
    local env = LinkHooksEnv.New()
    local ok, err = pcall(function()
      env.globals.SetItemRef = function(link)
        table.insert(calls.setItemRef, link)
      end
      local input = env.NewInput()
      env.LinkHooks.RegisterInput(input)
      input.focused = focused
      fn(env, input, calls)
    end)
    env.Restore()
    if not ok then
      error(err, 0)
    end
  end)
end

local function newTemplatedFrame(factory)
  local frame = factory.CreateFrame("Button", nil, nil, TEMPLATE)
  frame._wmSecureLinks = true
  return frame
end

local function clickHooks(frame)
  return frame._hookScripts and frame._hookScripts.OnHyperlinkClick or {}
end

-- A click as the game runs it: the frame's click script, then each post-hook.
local function click(frame, link, text, button)
  frame:GetScript("OnHyperlinkClick")(frame, link, text, button)
  for _, hook in ipairs(clickHooks(frame)) do
    hook(frame, link, text, button)
  end
end

return function()
  local factory = FakeUI.NewFactory()

  -- test_templated_bind_leaves_template_click_script
  do
    local frame = newTemplatedFrame(factory)
    LinkClicks.BindClick(frame)
    assert(frame:GetScript("OnHyperlinkClick") == frame.templateHyperlinkClick, "BindClick must keep the template's click script")
  end

  -- test_item_click_reaches_set_item_ref_once_and_never_blizzard_mixin
  withStubs(false, function(calls)
    local frame = newTemplatedFrame(factory)
    LinkClicks.BindClick(frame)
    click(frame, ITEM_LINK, "|Hitem:6948|h[Hearthstone]|h", "LeftButton")
    assert(#calls.setItemRef == 1 and calls.setItemRef[1] == ITEM_LINK, "the template should call SetItemRef once, got " .. #calls.setItemRef)
    assert(#calls.mixin == 0, "Blizzard's chat handler must not run from addon code, ran " .. #calls.mixin)
  end)

  -- test_shift_click_encoded_player_link_inserts_name_without_who
  withComposer(true, function(env, _input, calls)
    local frame = newTemplatedFrame(factory)
    LinkClicks.BindClick(frame)
    click(frame, ENCODED_LINK, ENCODED_TEXT, "LeftButton")
    assert(#env.inserts == 1 and env.inserts[1] == "Name-Realm", "expected the plain name in the composer, got " .. table.concat(env.inserts, ", "))
    for _, link in ipairs(calls.setItemRef) do
      assert(string.sub(link, 1, 23) == "addon:WhisperMessenger:", "SetItemRef must only see the encoded link (no /who), got " .. link)
    end
    assert(#calls.mixin == 0, "Blizzard's chat handler must not run, ran " .. #calls.mixin)
  end)

  -- test_shift_click_encoded_player_link_unfocused_routes_as_today
  withComposer(false, function(env, _input, calls)
    local frame = newTemplatedFrame(factory)
    LinkClicks.BindClick(frame)
    click(frame, ENCODED_LINK, ENCODED_TEXT, "LeftButton")
    assert(#env.inserts == 0, "an unfocused composer must not receive the name")
    assert(#calls.mixin == 1 and calls.mixin[1].link == DECODED_LINK, "Blizzard's chat handler should get the decoded link")
  end)

  -- test_right_click_encoded_player_link_reaches_mixin_decoded
  withStubs(false, function(calls)
    local frame = newTemplatedFrame(factory)
    LinkClicks.BindClick(frame)
    click(frame, ENCODED_LINK, ENCODED_TEXT, "RightButton")
    assert(#calls.mixin == 1, "Blizzard's chat handler should run once, ran " .. #calls.mixin)
    assert(calls.mixin[1].link == DECODED_LINK, "expected the decoded link, got " .. tostring(calls.mixin[1].link))
    assert(calls.mixin[1].text == DECODED_TEXT, "expected the decoded text, got " .. tostring(calls.mixin[1].text))
  end)

  -- test_url_click_copies_url
  ManualCopyCapture.With(function(copied)
    withStubs(false, function(calls)
      local frame = newTemplatedFrame(factory)
      LinkClicks.BindClick(frame)
      click(frame, URL_LINK, "[https://example.com/help]", "LeftButton")
      assert(copied.count == 1 and copied.text == "https://example.com/help", "a URL click should copy the URL, got " .. tostring(copied.text))
      assert(#calls.mixin == 0, "Blizzard's chat handler must not run, ran " .. #calls.mixin)
    end)
  end)

  -- test_on_link_click_runs_once_when_routing_throws
  withStubs(false, function()
    rawset(_G, "ChatFrameMixin", {
      OnHyperlinkClick = function()
        error("mixin failed", 0)
      end,
    })
    local callbacks = 0
    local frame = newTemplatedFrame(factory)
    LinkClicks.BindClick(frame, function()
      callbacks = callbacks + 1
    end)
    local ok, err = pcall(clickHooks(frame)[1], frame, ENCODED_LINK, ENCODED_TEXT, "LeftButton")
    assert(callbacks == 1, "the callback should run once when routing throws, ran " .. callbacks)
    assert(not ok and err == "mixin failed", "the routing error should surface, got " .. tostring(err))
  end)

  -- test_rebind_replaces_callback_without_new_hook
  withStubs(false, function()
    local counts = { a = 0, b = 0 }
    local frame = newTemplatedFrame(factory)
    LinkClicks.BindClick(frame, function()
      counts.a = counts.a + 1
    end)
    LinkClicks.BindClick(frame, function()
      counts.b = counts.b + 1
    end)
    assert(#clickHooks(frame) == 1, "a rebind must not add a second hook, got " .. #clickHooks(frame))
    click(frame, ITEM_LINK, "[Hearthstone]", "LeftButton")
    assert(counts.a == 0 and counts.b == 1, "only the latest callback should run, got a=" .. counts.a .. " b=" .. counts.b)
  end)

  -- test_untemplated_frame_decodes_encoded_player_link
  withStubs(false, function(calls)
    local frame = factory.CreateFrame("Frame", nil, nil)
    LinkClicks.BindClick(frame)
    frame:GetScript("OnHyperlinkClick")(frame, ENCODED_LINK, ENCODED_TEXT, "LeftButton")
    assert(#calls.mixin == 1 and calls.mixin[1].link == DECODED_LINK, "Blizzard's chat handler should get the decoded link")
    assert(calls.mixin[1].text == DECODED_TEXT, "expected the decoded text, got " .. tostring(calls.mixin[1].text))
  end)
end
