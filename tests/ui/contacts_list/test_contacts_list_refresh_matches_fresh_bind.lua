-- Refreshes skip rows whose values did not change. Whatever the player changes
-- between two refreshes, a refreshed row must read the same as a row bound
-- from scratch.

_G.date = os.date

local ContactsList = require("WhisperMessenger.UI.ContactsList")
local DisplayName = require("WhisperMessenger.Util.DisplayName")
local TimeFormat = require("WhisperMessenger.Util.TimeFormat")
local FakeUI = require("tests.helpers.fake_ui")

local function items()
  return {
    {
      conversationKey = "me::BN::mike#1234",
      displayName = "Mike#1234",
      lastPreview = "hi",
      unreadCount = 0,
      lastActivityAt = 100,
      channel = "BN",
      pinned = false,
    },
    {
      conversationKey = "jaina::PARTY",
      displayName = "Party",
      lastPreview = "pull",
      unreadCount = 0,
      lastActivityAt = 1700000000,
      channel = "PARTY",
      ownerProfileId = "jaina-proudmoore",
      pinned = false,
    },
  }
end

local function newParent(factory)
  local parent = factory.CreateFrame("Frame", nil, nil)
  parent:SetSize(260, 400)
  return parent
end

local function assertSameText(refreshed, fresh, label)
  for index = 1, #fresh do
    for _, field in ipairs({ "title", "preview", "timeLabel" }) do
      local got, want = refreshed[index][field].text, fresh[index][field].text
      assert(got == want, label .. ": row " .. index .. " " .. field .. " reads " .. tostring(got) .. ", a fresh bind reads " .. tostring(want))
    end
  end
end

-- Binds rows, applies change, refreshes them and compares with a fresh bind.
local function check(label, change, undo)
  local factory = FakeUI.NewFactory()
  local parent = newParent(factory)
  local options = { visibleCount = 2 }
  local rows = ContactsList.Refresh(factory, parent, {}, items(), options)
  change()
  ContactsList.Refresh(factory, parent, rows, items(), options)
  local fresh = ContactsList.Refresh(factory, newParent(factory), {}, items(), options)
  undo()
  assertSameText(rows, fresh, label)
end

return function()
  DisplayName.SetBattleTags({})
  DisplayName.Configure({ hideBattleTagNumbers = true })

  -- test_refreshed_row_shows_battletag_numbers_after_the_option_turns_off
  check("hide BattleTag numbers off", function()
    DisplayName.Configure({ hideBattleTagNumbers = false })
  end, function()
    DisplayName.Configure({ hideBattleTagNumbers = true })
  end)

  -- test_refreshed_row_shows_battletag_numbers_when_a_friend_shares_the_name
  check("clashing friend", function()
    DisplayName.SetBattleTags({ "Mike#1234", "Mike#5678" })
  end, function()
    DisplayName.SetBattleTags({})
  end)

  -- test_refreshed_group_row_follows_the_time_format
  local timeFormat = TimeFormat.GetConfig()
  check("time format", function()
    TimeFormat.Configure({ timeFormat = timeFormat == "24h" and "12h" or "24h" })
  end, function()
    TimeFormat.Configure({ timeFormat = timeFormat })
  end)
end
