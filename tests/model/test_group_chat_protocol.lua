local Protocol = require("WhisperMessenger.Model.GroupChatProtocol")

return function()
  -- test_message_body_round_trips
  do
    local body = Protocol.EncodeMessage("abcd1234", "hello ~ world")
    local decoded = Protocol.Decode(body)
    assert(decoded.kind == "message" and decoded.groupId == "abcd1234", "message decoded")
    assert(decoded.text == "hello ~ world", "text is the last field and may hold the separator")
    assert(Protocol.EncodeMessage("abcd1234", "") == nil, "empty messages are not sent")
    assert(Protocol.EncodeMessage("BAD", "x") == nil, "invalid ids are refused")
  end

  -- test_roster_body_round_trips
  do
    local body = Protocol.EncodeRoster("abcd1234", "Raid|night", { "Anna-Kazzak", "Me-Kazzak" })
    local decoded = Protocol.Decode(body)
    assert(decoded.kind == "roster" and decoded.name == "Raidnight", "roster name is cleaned")
    assert(#decoded.members == 2 and decoded.members[1] == "Anna-Kazzak" and decoded.members[2] == "Me-Kazzak", "members decoded")
  end

  -- test_roster_drops_malformed_member_names
  do
    local decoded = Protocol.Decode("R~abcd1234~G~Anna-Kazzak,bad|name,x y")
    assert(#decoded.members == 1 and decoded.members[1] == "Anna-Kazzak", "only clean names survive")
  end

  -- test_leave_and_query_bodies
  do
    assert(Protocol.Decode(Protocol.EncodeLeave("abcd1234")).kind == "leave")
    assert(Protocol.Decode(Protocol.EncodeQuery("abcd1234")).kind == "query")
    assert(Protocol.Decode("L~abcd1234~extra") == nil, "leave carries nothing else")
  end

  -- test_decode_rejects_garbage
  do
    assert(Protocol.Decode(nil) == nil)
    assert(Protocol.Decode("hello") == nil)
    assert(Protocol.Decode("X~abcd1234") == nil, "unknown kinds are ignored")
    assert(Protocol.Decode("M~abcd1234") == nil, "a message needs text")
    assert(Protocol.Decode("M~short~hi") == nil, "ids must be valid")
  end

  -- test_next_message_id_is_four_chars_and_advances
  do
    local counter = {}
    local first = Protocol.NextMessageId(counter, function()
      return 1
    end)
    local second = Protocol.NextMessageId(counter)
    assert(first == "0001" and second == "0002", first .. " " .. second)
    counter.value = 1679615
    assert(Protocol.NextMessageId(counter) == "0000", "ids wrap around")
  end

  -- test_short_body_is_one_frame
  do
    local frames = Protocol.Split("M~abcd1234~hi", "00a1")
    assert(#frames == 1 and frames[1] == "100a111M~abcd1234~hi", tostring(frames[1]))
    assert(Protocol.Receive({}, "Anna-Kazzak", frames[1], 0) == "M~abcd1234~hi", "one frame is the whole body")
  end

  -- test_long_body_splits_and_reassembles_in_any_order
  do
    local body = "M~abcd1234~" .. string.rep("x", 300)
    local frames = Protocol.Split(body, "zz01")
    assert(#frames == 2, "expected two frames")
    for _, frame in ipairs(frames) do
      assert(#frame <= 255, "every frame fits one addon message")
    end
    local buffer = {}
    assert(Protocol.Receive(buffer, "Anna-Kazzak", frames[2], 1) == nil, "waits for the rest")
    assert(Protocol.Receive(buffer, "Bela-Kazzak", frames[1], 1) == nil, "frames from another sender never mix in")
    assert(Protocol.Receive(buffer, "Anna-Kazzak", frames[1], 2) == body, "body reassembled")
    assert(next(buffer) ~= nil, "the other sender's half is still pending")
  end

  -- test_stale_partial_bodies_expire
  do
    local frames = Protocol.Split(string.rep("y", 300), "aaaa")
    local buffer = {}
    Protocol.Receive(buffer, "Anna-Kazzak", frames[1], 0)
    Protocol.Receive(buffer, "Anna-Kazzak", "1bbbb12z", 100)
    assert(buffer["anna-kazzak:aaaa"] == nil, "a half body older than the window is dropped")
    assert(Protocol.Receive(buffer, "Anna-Kazzak", frames[2], 101) == nil, "its late half alone is not a body")
  end

  -- test_bodies_over_nine_frames_are_refused
  do
    assert(Protocol.Split(string.rep("z", Protocol.MAX_BODY_BYTES + 1), "aaaa") == nil)
    assert(#Protocol.Split(string.rep("z", Protocol.MAX_BODY_BYTES), "aaaa") == 9)
  end

  -- test_receive_rejects_bad_frames
  do
    assert(Protocol.Receive({}, "A", "2aaaa11x", 0) == nil, "unknown versions are ignored")
    assert(Protocol.Receive({}, "A", "1aaaa21x", 0) == nil, "index past count is ignored")
    assert(Protocol.Receive({}, "A", "1aaaa11", 0) == nil, "a frame needs a chunk")
  end
end
