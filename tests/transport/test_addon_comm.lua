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

  -- 7. SendBNet dispatches BNSendGameData with prefix + payload + bnetAccountID.
  do
    local calls = {}
    local api = {
      SendGameData = function(bnetAccountID, prefix, payload)
        table.insert(calls, { bnetAccountID = bnetAccountID, prefix = prefix, payload = payload })
        return true
      end,
    }

    local ok = AddonComm.SendBNet(api, "WMQL", "4641:Your Place In The World", 77)
    assert(ok == true, "expected SendBNet to return true on success")
    assert(#calls == 1, "expected one BNSendGameData call")
    assert(calls[1].bnetAccountID == 77, "bnetAccountID forwarded")
    assert(calls[1].prefix == "WMQL", "prefix forwarded")
    assert(calls[1].payload == "4641:Your Place In The World", "payload forwarded")
  end

  -- 8. SendBNet falls back to _G.BNSendGameData when the api table lacks it.
  do
    local savedBNSendGameData = _G.BNSendGameData
    local legacyCalls = {}
    rawset(_G, "BNSendGameData", function(bnetAccountID, prefix, payload)
      table.insert(legacyCalls, { bnetAccountID = bnetAccountID, prefix = prefix, payload = payload })
      return true
    end)
    local ok = AddonComm.SendBNet({}, "WMQL", "1:Foo", 88)
    assert(ok == true, "legacy BNSendGameData fallback used")
    assert(legacyCalls[1].bnetAccountID == 88, "legacy bnetAccountID forwarded")
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
    assert(AddonComm.SendBNet(api, "WMQL", "p", nil) == false, "missing bnetAccountID -> false")
    assert(AddonComm.SendBNet(api, "WMQL", string.rep("x", 256), 1) == false, "oversized -> false")
    rawset(_G, "BNSendGameData", savedBNSendGameData)
  end
end
