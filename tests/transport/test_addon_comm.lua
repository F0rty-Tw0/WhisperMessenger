local AddonComm = require("WhisperMessenger.Transport.AddonComm")

return function()
  -- 1. RegisterPrefix calls C_ChatInfo.RegisterAddonMessagePrefix once per prefix.
  do
    local registered = {}
    local api = {
      RegisterAddonMessagePrefix = function(prefix)
        table.insert(registered, prefix)
        return true
      end,
    }

    local ok = AddonComm.RegisterPrefix(api, "WMQL")
    assert(ok == true, "expected RegisterPrefix to return true on success")
    assert(#registered == 1 and registered[1] == "WMQL", "expected prefix registered once")

    -- Registering again is idempotent: no second call.
    AddonComm.RegisterPrefix(api, "WMQL")
    assert(#registered == 1, "expected idempotent registration, got: " .. tostring(#registered))

    -- Different prefix registers separately.
    AddonComm.RegisterPrefix(api, "OTHER")
    assert(#registered == 2 and registered[2] == "OTHER", "expected second prefix registered")
  end

  -- 2. Send forwards prefix/payload/channel/target to C_ChatInfo.SendAddonMessage.
  do
    local calls = {}
    local api = {
      SendAddonMessage = function(prefix, payload, channel, target)
        table.insert(calls, { prefix = prefix, payload = payload, channel = channel, target = target })
        return true
      end,
    }

    local sent = AddonComm.Send(api, "WMQL", "4641:Your Place In The World", "Thrall-Nagrand")
    assert(sent == true, "expected Send to return true on success")
    assert(#calls == 1, "expected one SendAddonMessage call")
    assert(calls[1].prefix == "WMQL", "prefix forwarded")
    assert(calls[1].payload == "4641:Your Place In The World", "payload forwarded")
    assert(calls[1].channel == "WHISPER", "WHISPER channel used")
    assert(calls[1].target == "Thrall-Nagrand", "target forwarded")
  end

  -- 3. RegisterPrefix returns false when the API isn't available (no crash).
  do
    local ok1 = AddonComm.RegisterPrefix(nil, "WMQL")
    assert(ok1 == false, "expected false when api is nil")

    local ok2 = AddonComm.RegisterPrefix({}, "WMQL")
    assert(ok2 == false, "expected false when api lacks RegisterAddonMessagePrefix")
  end

  -- 4. Send returns false when the API isn't available (no crash).
  do
    local ok1 = AddonComm.Send(nil, "WMQL", "payload", "target")
    assert(ok1 == false, "expected false when api is nil")

    local ok2 = AddonComm.Send({}, "WMQL", "payload", "target")
    assert(ok2 == false, "expected false when api lacks SendAddonMessage")
  end

  -- 5. Send swallows API errors so a misbehaving server doesn't tear down the
  -- whisper path that already succeeded.
  do
    local api = {
      SendAddonMessage = function()
        error("C_ChatInfo exploded")
      end,
    }
    local ok = AddonComm.Send(api, "WMQL", "payload", "target")
    assert(ok == false, "expected false when the API throws")
  end

  -- 6. Send accepts successful enum/legacy results and rejects explicit failures.
  do
    local cases = {
      { result = 0, sent = true, name = "enum zero" },
      { prefix = true, result = 0, sent = true, name = "wrapped enum zero" },
      { prefix = true, result = 1, sent = false, name = "wrapped nonzero enum" },
      { result = true, sent = true, name = "legacy true" },
      { result = false, sent = false, name = "legacy false" },
      { result = nil, sent = true, name = "legacy nil" },
      { result = "unexpected", sent = false, name = "unexpected result" },
    }
    for _, case in ipairs(cases) do
      local api = {
        SendAddonMessage = function()
          if case.prefix ~= nil then
            return case.prefix, case.result
          end
          return case.result
        end,
      }
      assert(AddonComm.Send(api, "WMQL", "payload", "target") == case.sent, "Send should handle " .. case.name)
    end
  end

  -- 6. Send refuses oversized payloads (Blizzard caps addon messages at 255
  -- bytes). The caller should batch or skip rather than throw at the API.
  do
    local calls = {}
    local api = {
      SendAddonMessage = function(prefix, payload, channel, target)
        table.insert(calls, payload)
        return true
      end,
    }
    local oversized = string.rep("x", 256)
    local ok = AddonComm.Send(api, "WMQL", oversized, "target")
    assert(ok == false, "expected false on oversized payload")
    assert(#calls == 0, "expected oversized payload not to reach the API")
  end

  -- 7. SendBNet dispatches SendGameData with gameAccountID + prefix + payload.
  do
    local calls = {}
    local api = {
      SendGameData = function(gameAccountID, prefix, payload)
        table.insert(calls, { gameAccountID = gameAccountID, prefix = prefix, payload = payload })
        return true
      end,
    }

    local ok = AddonComm.SendBNet(api, "WMQL", "4641:Your Place In The World", 77)
    assert(ok == true, "expected SendBNet to return true on success")
    assert(#calls == 1, "expected one BNSendGameData call")
    assert(calls[1].gameAccountID == 77, "gameAccountID forwarded")
    assert(calls[1].prefix == "WMQL", "prefix forwarded")
    assert(calls[1].payload == "4641:Your Place In The World", "payload forwarded")
  end

  -- 8. SendBNet falls back to _G.BNSendGameData when the api table lacks it.
  do
    local savedBNSendGameData = _G.BNSendGameData
    local legacyCalls = {}
    rawset(_G, "BNSendGameData", function(gameAccountID, prefix, payload)
      table.insert(legacyCalls, { gameAccountID = gameAccountID, prefix = prefix, payload = payload })
      return true
    end)
    local ok = AddonComm.SendBNet({}, "WMQL", "1:Foo", 88)
    assert(ok == true, "legacy BNSendGameData fallback used")
    assert(legacyCalls[1].gameAccountID == 88, "legacy gameAccountID forwarded")
    assert(legacyCalls[1].payload == "1:Foo", "legacy payload forwarded")
    rawset(_G, "BNSendGameData", savedBNSendGameData)
  end

  -- 9. SendBNet returns false on nil api/missing function/bad inputs.
  do
    local savedBNSendGameData = _G.BNSendGameData
    rawset(_G, "BNSendGameData", nil)
    assert(AddonComm.SendBNet(nil, "WMQL", "p", 1) == false, "nil api -> false")
    assert(AddonComm.SendBNet({}, "WMQL", "p", 1) == false, "missing fn -> false")

    local api = { SendGameData = function() end }
    assert(AddonComm.SendBNet(api, "", "p", 1) == false, "empty prefix -> false")
    assert(AddonComm.SendBNet(api, "WMQL", "", 1) == false, "empty payload -> false")
    assert(AddonComm.SendBNet(api, "WMQL", "p", nil) == false, "missing gameAccountID -> false")
    assert(AddonComm.SendBNet(api, "WMQL", string.rep("x", 256), 1) == false, "oversized -> false")
    rawset(_G, "BNSendGameData", savedBNSendGameData)
  end
  -- 10. SendGroup forwards only approved channels without a target argument.
  do
    local calls = {}
    local api = {
      SendAddonMessage = function(...)
        local prefix, payload, channel = ...
        table.insert(calls, {
          prefix = prefix,
          payload = payload,
          channel = channel,
          argumentCount = select("#", ...),
        })
        return true
      end,
    }
    local channels = { "PARTY", "RAID", "INSTANCE_CHAT", "GUILD", "OFFICER" }
    for _, channel in ipairs(channels) do
      assert(AddonComm.SendGroup(api, "WMQL", "payload", channel) == true, "group channel should send: " .. channel)
    end
    assert(#calls == #channels, "each approved group channel should dispatch")
    for index, channel in ipairs(channels) do
      assert(calls[index].prefix == "WMQL" and calls[index].payload == "payload", "group prefix and payload forwarded")
      assert(calls[index].channel == channel, "group channel forwarded")
      assert(calls[index].argumentCount == 3, "group send should omit target argument")
    end
  end

  -- 11. SendGroup rejects invalid inputs without calling the API.
  do
    local calls = {}
    local api = {
      SendAddonMessage = function()
        table.insert(calls, true)
      end,
    }
    assert(AddonComm.SendGroup(api, "", "payload", "PARTY") == false, "empty prefix -> false")
    assert(AddonComm.SendGroup(api, "WMQL", "", "PARTY") == false, "empty payload -> false")
    assert(AddonComm.SendGroup(api, "WMQL", string.rep("x", 256), "PARTY") == false, "oversized payload -> false")
    assert(AddonComm.SendGroup(api, "WMQL", "payload", "WHISPER") == false, "WHISPER is not a group channel")
    assert(AddonComm.SendGroup(api, "WMQL", "payload", "SAY") == false, "SAY is not a group channel")
    assert(AddonComm.SendGroup(api, "WMQL", "payload", nil) == false, "missing channel -> false")
    assert(#calls == 0, "invalid group input should not reach API")
  end

  -- 12. SendGroup returns false when the addon API is unavailable.
  do
    assert(AddonComm.SendGroup(nil, "WMQL", "payload", "PARTY") == false, "nil group API -> false")
    assert(AddonComm.SendGroup({}, "WMQL", "payload", "PARTY") == false, "missing group API -> false")
  end

  -- 12. SendGroup returns false when the addon API throws.
  do
    local api = {
      SendAddonMessage = function()
        error("C_ChatInfo exploded")
      end,
    }
    assert(AddonComm.SendGroup(api, "WMQL", "payload", "PARTY") == false, "group API error -> false")
  end

  -- 14. SendGroup accepts successful enum/legacy results and rejects explicit failures.
  do
    local cases = {
      { result = 0, sent = true, name = "enum zero" },
      { prefix = true, result = 0, sent = true, name = "wrapped enum zero" },
      { prefix = true, result = 1, sent = false, name = "wrapped nonzero enum" },
      { result = true, sent = true, name = "legacy true" },
      { result = false, sent = false, name = "legacy false" },
      { result = nil, sent = true, name = "legacy nil" },
      { result = "unexpected", sent = false, name = "unexpected result" },
    }
    for _, case in ipairs(cases) do
      local api = {
        SendAddonMessage = function()
          if case.prefix ~= nil then
            return case.prefix, case.result
          end
          return case.result
        end,
      }
      assert(AddonComm.SendGroup(api, "WMQL", "payload", "PARTY") == case.sent, "SendGroup should handle " .. case.name)
    end
  end
  -- RegisterPrefix accepts only successful/duplicate registration results and
  -- caches only accepted prefixes.
  do
    local cases = {
      { label = "nil", result = nil, accepted = true },
      { label = "true", result = true, accepted = true },
      { label = "registered", result = 0, accepted = true },
      { label = "duplicate", result = 1, accepted = true },
      { label = "false", result = false, accepted = false },
      { label = "invalid", result = 2, accepted = false },
      { label = "too-long", result = 3, accepted = false },
      { label = "other", result = 99, accepted = false },
    }

    for _, case in ipairs(cases) do
      local calls = 0
      local api = {
        RegisterAddonMessagePrefix = function()
          calls = calls + 1
          return "ignored", case.result
        end,
      }
      local prefix = "WMR" .. case.label

      assert(AddonComm.RegisterPrefix(api, prefix) == case.accepted, case.label .. " result classification mismatch")
      assert(calls == 1, case.label .. " should invoke registration once")

      assert(AddonComm.RegisterPrefix(api, prefix) == case.accepted, case.label .. " retry classification mismatch")
      assert(calls == (case.accepted and 1 or 2), case.label .. " cache behavior mismatch")
    end
  end
end
