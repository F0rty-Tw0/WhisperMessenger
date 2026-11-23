local ChatReplyState = require("WhisperMessenger.Util.ChatReplyState")

return function()
  local read = ChatReplyState.ReadEditBoxState
  assert(type(read) == "function", "ChatReplyState exports ReadEditBoxState")

  -- test_read_edit_box_state_reads_direct_field
  assert(read({ chatType = "WHISPER" }, "chatType") == "WHISPER", "a plain field is read")

  -- test_read_edit_box_state_prefers_attribute_over_field
  do
    local editBox = {
      chatType = "SAY",
      GetAttribute = function(_self, _key)
        return "BN_WHISPER"
      end,
    }
    assert(read(editBox, "chatType") == "BN_WHISPER", "the attribute wins over the field")
  end

  -- test_read_edit_box_state_skips_empty_attribute
  do
    local editBox = {
      chatType = "WHISPER",
      GetAttribute = function(_self, _key)
        return ""
      end,
    }
    assert(read(editBox, "chatType") == "WHISPER", "an empty attribute falls back to the field")
  end

  -- test_read_edit_box_state_treats_empty_field_as_missing
  assert(read({ tellTarget = "" }, "tellTarget") == nil, "an empty field reads as nil")

  -- test_read_edit_box_state_ignores_non_table
  assert(read(nil, "chatType") == nil, "a missing edit box reads as nil")
end
