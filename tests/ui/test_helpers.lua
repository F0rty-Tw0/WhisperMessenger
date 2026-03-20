local UIHelpers = require("WhisperMessenger.UI.Helpers")

return function()
  -- sizeValue with getter function
  local target = {
    GetWidth = function(self)
      return 200
    end,
    width = 100,
  }
  assert(UIHelpers.sizeValue(target, "GetWidth", "width", 0) == 200, "sizeValue should use getter")

  -- sizeValue with field fallback
  local target2 = { width = 150 }
  assert(UIHelpers.sizeValue(target2, "GetWidth", "width", 0) == 150, "sizeValue should use field")

  -- sizeValue with fallback
  assert(UIHelpers.sizeValue({}, "GetWidth", "width", 42) == 42, "sizeValue should use fallback")

  -- sizeValue with nil target
  assert(UIHelpers.sizeValue(nil, "GetWidth", "width", 99) == 99, "sizeValue(nil) should use fallback")

  -- sizeValue with zero getter (should fall through)
  local target3 = {
    GetWidth = function(self)
      return 0
    end,
    width = 50,
  }
  assert(UIHelpers.sizeValue(target3, "GetWidth", "width", 0) == 50, "sizeValue should skip zero getter")

  -- applyColor
  local fs = {
    SetTextColor = function(self, ...)
      self.color = { ... }
    end,
  }
  UIHelpers.applyColor(fs, { 0.5, 0.6, 0.7, 1.0 })
  assert(fs.color[1] == 0.5, "applyColor should set r")
  assert(fs.color[4] == 1.0, "applyColor should set a")

  -- applyColor with nil
  UIHelpers.applyColor(nil, { 1, 1, 1, 1 }) -- should not error

  -- applyColorTexture
  local tex = {
    SetColorTexture = function(self, ...)
      self.color = { ... }
    end,
  }
  UIHelpers.applyColorTexture(tex, { 0.1, 0.2, 0.3, 0.8 })
  assert(tex.color[1] == 0.1, "applyColorTexture should set r")
end
