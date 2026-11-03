local AddonComm = require("WhisperMessenger.Transport.AddonComm")

-- The "robots.txt" prefix is listen-only: a "D:<delay>" reply on it tells a
-- crafting addon to fake a human answer, so nothing may ever go out on it.
return function()
  assert(AddonComm.PREFIX_ADDON_GREETING == "robots.txt", "addon greeting prefix must stay robots.txt")

  local calls = 0
  local api = {
    SendAddonMessage = function()
      calls = calls + 1
      return true
    end,
    SendGameData = function()
      calls = calls + 1
      return true
    end,
  }

  assert(AddonComm.Send(api, "robots.txt", "D:2", "Crafter-Realm") == false, "whisper send on robots.txt must be refused")
  assert(AddonComm.SendGroup(api, "robots.txt", "D:2", "PARTY") == false, "group send on robots.txt must be refused")
  assert(AddonComm.SendBNet(api, "robots.txt", "D:2", 42) == false, "BNet send on robots.txt must be refused")
  assert(calls == 0, "no addon message may leave on robots.txt, got " .. calls)

  -- CraftScan's own prefix: WM only listens for it.
  assert(AddonComm.PREFIX_CRAFT_SCAN == "CRAFT_SCAN", "CraftScan prefix must stay CRAFT_SCAN")
  assert(AddonComm.Send(api, "CRAFT_SCAN", "x", "Crafter-Realm") == false, "whisper send on CRAFT_SCAN must be refused")
  assert(AddonComm.SendGroup(api, "CRAFT_SCAN", "x", "PARTY") == false, "group send on CRAFT_SCAN must be refused")
  assert(AddonComm.SendBNet(api, "CRAFT_SCAN", "x", 42) == false, "BNet send on CRAFT_SCAN must be refused")
  assert(calls == 0, "no addon message may leave on CRAFT_SCAN, got " .. calls)

  -- Other prefixes still go out.
  assert(AddonComm.Send(api, "WMQL", "1:x", "Crafter-Realm") == true, "WMQL send still works")
end
