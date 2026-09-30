local DataBuilder = require("WhisperMessenger.UI.ContactsList.DataBuilder")
local RowElements = require("WhisperMessenger.UI.ContactsList.RowElements")
local FakeUI = require("tests.helpers.fake_ui")

local function bnFriend(battleTag, lastActivityAt)
  return { displayName = battleTag, channel = "BN", lastActivityAt = lastActivityAt, messages = {} }
end

local function rowTitle(factory, parent, item)
  local row = factory.CreateFrame("Frame", nil, parent)
  row.title = row:CreateFontString(nil, "OVERLAY")
  RowElements.updateNameLabel(row, item, 260)
  return row.title.text
end

return function()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", nil, nil)
  parent:SetSize(260, 400)

  -- test_bn_friends_sharing_a_name_show_distinct_names
  local items = DataBuilder.BuildItemsForProfile({
    conversations = {
      ["bnet::BN::mike#1234"] = bnFriend("Mike#1234", 30),
      ["bnet::BN::mike#5678"] = bnFriend("Mike#5678", 20),
      ["bnet::BN::arthas#1111"] = bnFriend("Arthas#1111", 10),
    },
  }, "me")

  assert(rowTitle(factory, parent, items[1]) == "Mike#1234", "first Mike keeps the number")
  assert(rowTitle(factory, parent, items[2]) == "Mike#5678", "second Mike keeps the number")
  assert(rowTitle(factory, parent, items[3]) == "Arthas", "a unique friend still hides the number")
end
