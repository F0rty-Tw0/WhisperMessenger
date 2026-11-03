local AddonGreetings = require("WhisperMessenger.Model.AddonGreetings")
local Identity = require("WhisperMessenger.Model.Identity")

-- Crafting addons announce an automated greeting with "Q:<AddonName>" right
-- before the whisper. The announcement marks the sender for a short window;
-- the next whisper from them claims the mark.

local function keyFor(name)
  return Identity.FromWhisper(name).contactKey
end

local function test_decode_reads_addon_name()
  assert(AddonGreetings.Decode("Q:CraftScan") == "CraftScan", "Q:<name> decodes to the addon name")
  assert(AddonGreetings.Decode("Q:  Craft Alert  ") == "Craft Alert", "surrounding spaces are trimmed")
end

local function test_decode_rejects_other_payloads()
  assert(AddonGreetings.Decode("D:2") == nil, "a humanize reply is not an announcement")
  assert(AddonGreetings.Decode("Q:") == nil, "empty name rejected")
  assert(AddonGreetings.Decode("Q:   ") == nil, "blank name rejected")
  assert(AddonGreetings.Decode(nil) == nil, "nil rejected")
  assert(AddonGreetings.Decode(42) == nil, "non-string rejected")
end

local function test_decode_rejects_untrusted_names()
  assert(AddonGreetings.Decode("Q:" .. string.rep("a", 33)) == nil, "names over 32 bytes rejected")
  assert(AddonGreetings.Decode("Q:" .. string.rep("a", 32)) == string.rep("a", 32), "32 bytes is fine")
  assert(AddonGreetings.Decode("Q:|cffff0000Red|r") == nil, "escape sequences rejected")
  assert(AddonGreetings.Decode("Q:Bad\nName") == nil, "control characters rejected")
  assert(AddonGreetings.Decode("Q:Caf\195\169") == nil, "non-ASCII rejected")
end

local function test_claim_returns_name_within_window()
  local state = {}
  assert(AddonGreetings.Record(state, "Crafter-Realm", "Q:CraftScan", 100) == true, "announcement recorded")
  assert(AddonGreetings.Claim(state, keyFor("Crafter-Realm"), 105) == "CraftScan", "whisper within the window claims the tag")
end

local function test_claim_after_the_burst_is_untagged()
  local state = {}
  AddonGreetings.Record(state, "Crafter-Realm", "Q:CraftScan", 100)
  AddonGreetings.Claim(state, keyFor("Crafter-Realm"), 101)
  local later = 101 + AddonGreetings.BURST_SECONDS + 1
  assert(AddonGreetings.Claim(state, keyFor("Crafter-Realm"), later) == nil, "a whisper after the burst is not tagged")
end

-- CraftScan sends several lines in a loop after one announcement.
local function test_burst_lines_share_the_tag()
  local state = {}
  local key = keyFor("Crafter-Realm")
  AddonGreetings.Record(state, "Crafter-Realm", "Q:CraftScan", 100)
  assert(AddonGreetings.Claim(state, key, 100) == "CraftScan", "first line tagged")
  assert(AddonGreetings.Claim(state, key, 101) == "CraftScan", "second line tagged")
  assert(AddonGreetings.Claim(state, key, 103) == "CraftScan", "the window slides from the previous line")
  assert(AddonGreetings.Claim(state, key, 106) == nil, "a reply after the burst is not tagged")
end

local function test_burst_needs_a_tagged_line()
  local state = {}
  local key = keyFor("Crafter-Realm")
  AddonGreetings.Claim(state, key, 100)
  assert(AddonGreetings.Claim(state, key, 101) == nil, "untagged whispers start no burst")
end

local function test_stored_whisper_claimed_within_window()
  local state = {}
  local stored = { conversationKey = "c" }
  AddonGreetings.NoteWhisper(state, keyFor("Crafter-Realm"), 100, stored)
  assert(AddonGreetings.ClaimStored(state, "Crafter-Realm", 100 + AddonGreetings.LATE_TAG_SECONDS) == stored, "the stored whisper is returned")
  assert(AddonGreetings.ClaimStored(state, "Crafter-Realm", 103) == nil, "only one claim per whisper")
end

local function test_stored_whisper_expires()
  local state = {}
  AddonGreetings.NoteWhisper(state, keyFor("Crafter-Realm"), 100, {})
  assert(AddonGreetings.ClaimStored(state, "Crafter-Realm", 100 + AddonGreetings.LATE_TAG_SECONDS + 1) == nil, "an older whisper is not claimed")
end

local function test_newer_whisper_replaces_the_stored_one()
  local state = {}
  local key = keyFor("Crafter-Realm")
  AddonGreetings.NoteWhisper(state, key, 100, { conversationKey = "old" })
  AddonGreetings.NoteWhisper(state, key, 101, nil)
  assert(AddonGreetings.ClaimStored(state, "Crafter-Realm", 101) == nil, "a tagged newer whisper leaves nothing to claim")
end

local function test_claim_expires_after_window()
  local state = {}
  AddonGreetings.Record(state, "Crafter-Realm", "Q:CraftScan", 100)
  assert(AddonGreetings.Claim(state, keyFor("Crafter-Realm"), 100 + AddonGreetings.WINDOW_SECONDS + 1) == nil, "stale mark ignored")
end

local function test_claim_matches_only_the_announcing_sender()
  local state = {}
  AddonGreetings.Record(state, "Crafter-Realm", "Q:CraftScan", 100)
  assert(AddonGreetings.Claim(state, keyFor("Someone-Realm"), 101) == nil, "other sender untagged")
end

local function test_sender_names_normalise_like_whisper_ingest()
  rawset(_G, "Ambiguate", function(name)
    return (string.gsub(name, "%-HomeRealm$", ""))
  end)
  local state = {}
  AddonGreetings.Record(state, "crafter-HomeRealm", "Q:CraftScan", 100)
  local tag = AddonGreetings.Claim(state, keyFor("Crafter"), 101)
  rawset(_G, "Ambiguate", nil)
  assert(tag == "CraftScan", "realm-suffixed addon sender matches the short whisper name")
end

local function test_record_ignores_invalid_payload()
  local state = {}
  assert(AddonGreetings.Record(state, "Crafter-Realm", "D:2", 100) == false, "non-announcement not recorded")
  assert(AddonGreetings.Record(state, nil, "Q:CraftScan", 100) == false, "missing sender not recorded")
  assert(AddonGreetings.Claim(state, keyFor("Crafter-Realm"), 101) == nil, "nothing to claim")
end

local function test_record_drops_stale_marks()
  local state = {}
  AddonGreetings.Record(state, "Old-Realm", "Q:CraftScan", 100)
  AddonGreetings.Record(state, "New-Realm", "Q:CraftScan", 200)
  assert(state.addonGreetingInbox[keyFor("Old-Realm")] == nil, "expired mark purged on the next record")
end

local function test_announcement_right_after_its_whisper_ignored()
  local state = {}
  AddonGreetings.Claim(state, keyFor("Crafter-Realm"), 100)
  assert(AddonGreetings.Record(state, "Crafter-Realm", "Q:CraftScan", 101) == false, "late announcement for an arrived whisper ignored")
  assert(AddonGreetings.Claim(state, keyFor("Crafter-Realm"), 103) == nil, "the human follow-up is not tagged")
end

local function test_announcement_after_an_older_whisper_counts()
  local state = {}
  AddonGreetings.Claim(state, keyFor("Crafter-Realm"), 100)
  assert(AddonGreetings.Record(state, "Crafter-Realm", "Q:CraftScan", 102) == true, "announcement recorded")
  assert(AddonGreetings.Claim(state, keyFor("Crafter-Realm"), 103) == "CraftScan", "next whisper tagged")
end

local function test_whisper_marks_are_pruned()
  local state = {}
  AddonGreetings.Claim(state, keyFor("Old-Realm"), 100)
  AddonGreetings.Claim(state, keyFor("New-Realm"), 200)
  assert(state.addonGreetingInbox[keyFor("Old-Realm")] == nil, "old whisper mark purged on the next whisper")
end

local function test_mode_defaults_to_show()
  assert(AddonGreetings.Mode(nil) == "show", "no settings shows")
  assert(AddonGreetings.Mode({}) == "show", "unset shows")
  assert(AddonGreetings.Mode({ addonGreetings = "bogus" }) == "show", "unknown value shows")
  assert(AddonGreetings.Mode({ addonGreetings = "hide" }) == "hide", "hide kept")
end

local function test_requests_mode_needs_requests_inbox()
  assert(AddonGreetings.Mode({ addonGreetings = "requests", requestsInbox = true }) == "requests", "requests with inbox on")
  assert(AddonGreetings.Mode({ addonGreetings = "requests" }) == "show", "requests with inbox off falls back to show")
end

return function()
  test_decode_reads_addon_name()
  test_decode_rejects_other_payloads()
  test_decode_rejects_untrusted_names()
  test_claim_returns_name_within_window()
  test_claim_after_the_burst_is_untagged()
  test_burst_lines_share_the_tag()
  test_burst_needs_a_tagged_line()
  test_stored_whisper_claimed_within_window()
  test_stored_whisper_expires()
  test_newer_whisper_replaces_the_stored_one()
  test_claim_expires_after_window()
  test_claim_matches_only_the_announcing_sender()
  test_sender_names_normalise_like_whisper_ingest()
  test_record_ignores_invalid_payload()
  test_record_drops_stale_marks()
  test_announcement_right_after_its_whisper_ignored()
  test_announcement_after_an_older_whisper_counts()
  test_whisper_marks_are_pruned()
  test_mode_defaults_to_show()
  test_requests_mode_needs_requests_inbox()
end
