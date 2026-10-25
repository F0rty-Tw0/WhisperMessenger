local ContactInfo = require("WhisperMessenger.Model.ContactInfo")
local PublicApi = require("WhisperMessenger.Core.PublicApi")

local JAINA = "wow::WOW::jaina-proudmoore"

local function makeRuntime(visible, selectedKey)
  local runtime = {
    contactInfo = ContactInfo.New(),
    refreshes = 0,
    activeConversationKey = selectedKey,
    store = {
      conversations = {
        [JAINA] = { channel = "WOW", displayName = "Jaina-Proudmoore" },
        ["wow::WOW::arthas"] = { channel = "WOW", displayName = "Arthas" },
      },
    },
  }
  runtime.isWindowVisible = function()
    return visible
  end
  runtime.refreshWindow = function()
    runtime.refreshes = runtime.refreshes + 1
  end
  return runtime
end

return function()
  -- test_set_stores_under_the_canonical_name_and_refreshes_a_shown_window
  do
    local runtime = makeRuntime(true, JAINA)
    local api = PublicApi.Build(runtime)
    assert(api.SetContactInfo("ca", "Jaina-Proudmoore", "x") == true)
    assert(runtime.contactInfo["jaina-proudmoore"] and runtime.contactInfo["jaina-proudmoore"].ca == "x", "stored under the canonical name")
    assert(runtime.refreshes == 1, "shown window refreshed once, got " .. runtime.refreshes)
  end

  -- test_a_note_for_another_player_does_not_refresh_the_window
  do
    local runtime = makeRuntime(true, "wow::WOW::arthas")
    local api = PublicApi.Build(runtime)
    assert(api.SetContactInfo("ca", "Jaina-Proudmoore", "x") == true)
    assert(api.SetContactInfo("ca", "Thrall", "x") == true)
    assert(runtime.refreshes == 0, "a note off the selected chat does not refresh, got " .. runtime.refreshes)
    assert(api.SetContactInfo("ca", "Arthas", "x") == true)
    assert(runtime.refreshes == 1, "a note for the selected chat refreshes, got " .. runtime.refreshes)
  end

  -- test_no_selected_chat_does_not_refresh
  do
    local runtime = makeRuntime(true, nil)
    local api = PublicApi.Build(runtime)
    assert(api.SetContactInfo("ca", "Jaina-Proudmoore", "x") == true)
    assert(runtime.refreshes == 0, "nothing selected, nothing to refresh")
  end

  -- test_hidden_window_is_not_refreshed
  do
    local runtime = makeRuntime(false, JAINA)
    local api = PublicApi.Build(runtime)
    assert(api.SetContactInfo("ca", "Jaina", "x") == true)
    assert(runtime.refreshes == 0, "hidden window not refreshed, got " .. runtime.refreshes)
  end

  -- test_nil_text_removes
  do
    local runtime = makeRuntime(true)
    local api = PublicApi.Build(runtime)
    assert(api.SetContactInfo("ca", "Jaina", "x") == true)
    assert(api.SetContactInfo("ca", "Jaina", nil) == true)
    assert(next(runtime.contactInfo) == nil, "the line is gone")
  end

  -- test_bad_arguments_return_false
  do
    local runtime = makeRuntime(true)
    local api = PublicApi.Build(runtime)
    local bad = { "", 5, {} }
    for _, value in ipairs(bad) do
      assert(api.SetContactInfo(value, "Jaina", "x") == false, "sourceKey " .. tostring(value))
      assert(api.SetContactInfo("ca", value, "x") == false, "playerName " .. tostring(value))
    end
    assert(api.SetContactInfo("ca", "Jaina", 5) == false, "numeric text")
    assert(runtime.refreshes == 0, "no refresh on bad input")
    assert(next(runtime.contactInfo) == nil, "nothing stored")
  end
end
