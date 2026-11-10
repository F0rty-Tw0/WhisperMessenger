local InstanceName = require("WhisperMessenger.Core.Ingest.GroupChatIngest.InstanceName")

return function()
  local savedIsInInstance = rawget(_G, "IsInInstance")
  local savedGetInstanceInfo = rawget(_G, "GetInstanceInfo")
  local savedIsSecret = rawget(_G, "issecretvalue")

  local function stubInstance(inInstance, name)
    rawset(_G, "IsInInstance", function()
      return inInstance, "party"
    end)
    rawset(_G, "GetInstanceInfo", function()
      return name, "party", 1
    end)
  end

  -- test_current_returns_name_inside_instance
  do
    stubInstance(true, "Halls of Atonement")
    local name = InstanceName.Current()
    assert(name == "Halls of Atonement", "inside an instance the name comes back, got: " .. tostring(name))
  end

  -- test_current_is_nil_outside_instance
  do
    stubInstance(false, "Stormwind City")
    local name = InstanceName.Current()
    assert(name == nil, "outside an instance there is no name, got: " .. tostring(name))
  end

  -- test_empty_name_is_ignored
  do
    stubInstance(true, "")
    assert(InstanceName.Current() == nil, "an empty instance name is no name")
  end

  -- test_secret_name_is_ignored
  do
    stubInstance(true, "Halls of Atonement")
    rawset(_G, "issecretvalue", function()
      return true
    end)
    local name = InstanceName.Current()
    rawset(_G, "issecretvalue", savedIsSecret)
    assert(name == nil, "a secret instance name is ignored, got: " .. tostring(name))
  end

  -- test_missing_instance_api_returns_nil
  do
    rawset(_G, "IsInInstance", nil)
    rawset(_G, "GetInstanceInfo", nil)
    assert(InstanceName.Current() == nil, "a client without the instance APIs has no name")
  end

  -- test_instance_api_error_returns_nil
  do
    stubInstance(true, "Halls of Atonement")
    rawset(_G, "IsInInstance", function()
      error("instance API raised")
    end)
    local ok, name = pcall(InstanceName.Current)
    assert(ok, "IsInInstance raising must not escape Current")
    assert(name == nil, "IsInInstance raising gives no name, got: " .. tostring(name))

    stubInstance(true, "Halls of Atonement")
    rawset(_G, "GetInstanceInfo", function()
      error("instance API raised")
    end)
    ok, name = pcall(InstanceName.Current)
    assert(ok, "GetInstanceInfo raising must not escape Current")
    assert(name == nil, "GetInstanceInfo raising gives no name, got: " .. tostring(name))
  end

  rawset(_G, "IsInInstance", savedIsInInstance)
  rawset(_G, "GetInstanceInfo", savedGetInstanceInfo)
  rawset(_G, "issecretvalue", savedIsSecret)
end
