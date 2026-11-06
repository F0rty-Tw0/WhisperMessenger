local GroupLabel = require("WhisperMessenger.UI.ContactsList.GroupLabel")
local GroupHeaderViewModel = require("WhisperMessenger.UI.ConversationPane.GroupHeaderViewModel")
local Textures = require("WhisperMessenger.UI.Theme.Textures")

return function()
  -- test_group_chat_row_shows_the_group_name
  do
    assert(GroupLabel.IsGroupItem({ channel = "WM_GROUP" }), "a group chat is a group row")
    assert(GroupLabel.ForItem({ channel = "WM_GROUP", title = "Crew", displayName = "Anna-Kazzak" }) == "Crew")
    assert(GroupLabel.ForItem({ channel = "WM_GROUP" }) == "Group chat", "untitled falls back to the kind")
  end

  -- test_group_chat_header_lists_the_members
  do
    local contact = { channel = "WM_GROUP", conversationKey = "wmgroup::abcd1234", displayName = "Anna-Kazzak" }
    local vm = GroupHeaderViewModel.Build(contact, { title = "Crew", memberSummary = "Anna, Bela-Ragnaros" })
    assert(vm.isGroup and vm.title == "Crew", "header titled after the group")
    assert(vm.channelChip == "Group chat", "chip names the kind")
    assert(vm.statusText == "Anna, Bela-Ragnaros", "members under the title")
    local bare = GroupHeaderViewModel.Build(contact, { title = "Crew" })
    assert(bare.statusText == nil, "no members, no line")
  end

  -- test_group_chat_has_its_own_icon
  do
    local channelIcon = Textures.ChannelIcon
    assert(channelIcon("WM_GROUP", "wmgroup::abcd1234") ~= nil)
  end
end
