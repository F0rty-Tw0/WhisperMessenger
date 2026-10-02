local FirstRunTip = require("WhisperMessenger.Core.Bootstrap.FirstRunTip")

local EXPECTED_MESSAGE = "|cffffd100WhisperMessenger:|r your whispers now open in the messenger window. Click the chat icon or type /wmsg."

local function makeFrame()
  local calls = {}
  local frame = {
    AddMessage = function(_self, text)
      table.insert(calls, text)
    end,
  }
  return frame, calls
end

local function test_fresh_state_prints_once_and_sets_flag()
  local accountState = { settings = {}, conversations = {} }
  local frame, calls = makeFrame()

  FirstRunTip.Announce(accountState, { frame = frame })

  assert(#calls == 1, "expected exactly one chat message")
  assert(calls[1] == EXPECTED_MESSAGE, "unexpected message text: " .. tostring(calls[1]))
  assert(accountState.settings.firstRunTipShown == true, "flag should be set after announcing")
end

local function test_flag_already_set_prints_nothing()
  local accountState = { settings = { firstRunTipShown = true }, conversations = {} }
  local frame, calls = makeFrame()

  FirstRunTip.Announce(accountState, { frame = frame })

  assert(#calls == 0, "expected no chat message when flag already set")
  assert(accountState.settings.firstRunTipShown == true, "flag should remain set")
end

local function test_existing_user_with_conversations_prints_nothing_but_sets_flag()
  local accountState = {
    settings = {},
    conversations = { ["wow::Someone"] = { messages = {} } },
  }
  local frame, calls = makeFrame()

  FirstRunTip.Announce(accountState, { frame = frame })

  assert(#calls == 0, "existing user with conversations must not see the tip")
  assert(accountState.settings.firstRunTipShown == true, "flag should still be set silently")
end

local function test_is_fresh_install_for_an_empty_account()
  assert(FirstRunTip.IsFreshInstall({ settings = {}, conversations = {} }) == true, "empty account is a fresh install")
end

local function test_is_not_fresh_install_after_first_boot()
  assert(FirstRunTip.IsFreshInstall({ settings = { firstRunTipShown = true }, conversations = {} }) == false, "a booted account is not fresh")
end

local function test_is_not_fresh_install_when_patch_notes_were_seen()
  local accountState = { settings = { patchNotesSeenVersion = "2.0.1" }, conversations = {} }
  assert(FirstRunTip.IsFreshInstall(accountState) == false, "an upgrader is not fresh")
end

local function test_is_not_fresh_install_with_any_saved_setting()
  -- Accounts from before the first-run flag existed still saved settings.
  local accountState = { settings = { nativeChrome = false }, conversations = {} }
  assert(FirstRunTip.IsFreshInstall(accountState) == false, "an old account with saved settings is not fresh")
end

local function test_is_not_fresh_install_with_saved_conversations()
  local accountState = { settings = {}, conversations = { ["wow::Someone"] = { messages = {} } } }
  assert(FirstRunTip.IsFreshInstall(accountState) == false, "an account with conversations is not fresh")
end

test_fresh_state_prints_once_and_sets_flag()
test_is_not_fresh_install_with_any_saved_setting()
test_is_not_fresh_install_with_saved_conversations()
test_is_fresh_install_for_an_empty_account()
test_is_not_fresh_install_after_first_boot()
test_is_not_fresh_install_when_patch_notes_were_seen()
test_flag_already_set_prints_nothing()
test_existing_user_with_conversations_prints_nothing_but_sets_flag()

print("test_first_run_tip.lua: all tests passed")
