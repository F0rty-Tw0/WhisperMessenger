local PublicApiEnv = require("tests.helpers.public_api_env")

local itemLink = "|Hitem:1|h[Item]|h"

local function each(settings, fn)
  local runtime, api = PublicApiEnv.Initialize(settings)
  local ok, err = pcall(fn, runtime, api)
  PublicApiEnv.Reset()
  if not ok then
    error(err, 0)
  end
end

local function focusedComposer(runtime)
  runtime.ensureWindow()
  runtime.setWindowVisible(true)
  local input = runtime.window.composer.input
  local frame = input
  while frame and frame ~= runtime.window.frame do
    frame:Show()
    frame = frame:GetParent()
  end
  input:SetFocus()
  return input
end

return function()
  -- test_rejects_a_non_string_or_blank_text
  each({}, function(runtime, api)
    local input = focusedComposer(runtime)
    assert(api.InsertLink(nil) == false, "nil is not a link")
    assert(api.InsertLink(42) == false, "a number is not a link")
    assert(api.InsertLink("   ") == false, "blank text is not a link")
    assert(input:GetText() == "", "a rejected call must not touch the composer")
  end)

  -- test_rejects_text_longer_than_one_message
  each({}, function(runtime, api)
    local input = focusedComposer(runtime)
    input:SetMaxBytes(0)
    assert(api.InsertLink(string.rep("a", 256)) == false, "more than one message must be refused")
    assert(input:GetText() == "", "a rejected call must not touch the composer")
  end)

  -- test_refused_when_the_composer_byte_cap_has_no_room
  each({}, function(runtime, api)
    local input = focusedComposer(runtime)
    input:SetText("aaaaaaaaaa")
    input:SetMaxBytes(20)
    assert(api.InsertLink(itemLink) == false, "a link past the composer's byte cap must be refused")
    assert(input:GetText() == "aaaaaaaaaa", "a refused call must not touch the composer")
  end)

  -- test_refused_in_competitive_content
  each({}, function(runtime, api)
    local input = focusedComposer(runtime)
    runtime.isCompetitiveContent = function()
      return true
    end
    assert(api.InsertLink(itemLink) == false, "competitive content must refuse")
    assert(input:GetText() == "", "a refused call must not touch the composer")
  end)

  -- test_refused_when_integration_is_off_and_nothing_is_inserted
  each({ allowAddonIntegration = false }, function(runtime, api)
    local input = focusedComposer(runtime)
    assert(api.InsertLink(itemLink) == false, "integration off must refuse")
    assert(input:GetText() == "", "a refused call must not touch the composer")
  end)

  -- test_connect_handle_has_insert_link
  each({}, function(_, api)
    assert(type(api.Connect("totalRP3").InsertLink) == "function", "the handle must carry InsertLink")
  end)

  -- test_inserts_into_the_focused_composer
  each({}, function(runtime, api)
    local input = focusedComposer(runtime)
    assert(api.InsertLink(itemLink) == true, "a focused composer should take the link")
    assert(string.find(input:GetText(), itemLink, 1, true), "expected the link in the composer, got: " .. tostring(input:GetText()))
  end)
end
