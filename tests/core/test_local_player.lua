local LocalPlayer = require("WhisperMessenger.Core.LocalPlayer")

return function()
  local savedName, savedClass = _G.UnitName, _G.UnitClass

  -- test_reads_name_and_class_tag
  rawset(_G, "UnitName", function()
    return "Arthas"
  end)
  rawset(_G, "UnitClass", function()
    return "Paladin", "PALADIN"
  end)
  assert(LocalPlayer.Name() == "Arthas", "name")
  assert(LocalPlayer.ClassTag() == "PALADIN", "class tag")

  -- test_blank_values_read_as_nil
  rawset(_G, "UnitName", function()
    return ""
  end)
  rawset(_G, "UnitClass", function()
    return "Paladin", ""
  end)
  assert(LocalPlayer.Name() == nil and LocalPlayer.ClassTag() == nil, "blank values are nil")

  -- test_throwing_api_reads_as_nil
  rawset(_G, "UnitName", function()
    error("secret")
  end)
  assert(LocalPlayer.Name() == nil, "throwing API is nil")

  -- test_missing_api_reads_as_nil
  rawset(_G, "UnitName", nil)
  rawset(_G, "UnitClass", nil)
  assert(LocalPlayer.Name() == nil and LocalPlayer.ClassTag() == nil, "missing API is nil")

  rawset(_G, "UnitName", savedName)
  rawset(_G, "UnitClass", savedClass)
end
