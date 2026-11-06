local SlashCommands = require("WhisperMessenger.Core.SlashCommands")

return function()
  local savedSlashCmdList = _G.SlashCmdList
  _G.SlashCmdList = {}

  local toggles = 0
  local groupArgs = {}
  SlashCommands.Register({
    toggle = function()
      toggles = toggles + 1
    end,
    groupChat = function(rest)
      groupArgs[#groupArgs + 1] = rest
    end,
  })
  local handler = _G.SlashCmdList["WHISPERMESSENGER"]

  -- test_group_command_passes_the_names_unchanged
  handler("  GROUP Anna, Bela-Argent Dawn  ")
  assert(groupArgs[1] == "Anna, Bela-Argent Dawn", "names keep their case and spaces, got " .. tostring(groupArgs[1]))
  assert(toggles == 0, "the group command does not toggle the window")

  -- test_bare_group_command_passes_empty_text
  handler("group")
  assert(groupArgs[2] == "", "no names gives empty text")

  -- test_without_a_group_handler_the_window_toggles
  SlashCommands.Register({
    toggle = function()
      toggles = toggles + 1
    end,
  })
  _G.SlashCmdList["WHISPERMESSENGER"]("group Anna")
  assert(toggles == 1)

  _G.SlashCmdList = savedSlashCmdList
end
