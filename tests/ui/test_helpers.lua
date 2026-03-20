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

  -- applyVertexColor applies vertex color to a texture
  local vtex = {
    SetVertexColor = function(self, ...)
      self.vertexColor = { ... }
    end,
  }
  UIHelpers.applyVertexColor(vtex, { 0.3, 0.4, 0.5, 0.9 })
  assert(vtex.vertexColor[1] == 0.3, "applyVertexColor should set r")
  assert(vtex.vertexColor[4] == 0.9, "applyVertexColor should set a")

  -- applyVertexColor with nil region (should not error)
  UIHelpers.applyVertexColor(nil, { 1, 1, 1, 1 })

  -- applyVertexColor with nil colorTable (should not error)
  UIHelpers.applyVertexColor(vtex, nil)

  -- applyVertexColor defaults alpha to 1
  local vtex2 = {
    SetVertexColor = function(self, ...)
      self.vertexColor = { ... }
    end,
  }
  UIHelpers.applyVertexColor(vtex2, { 0.1, 0.2, 0.3 })
  assert(vtex2.vertexColor[4] == 1, "applyVertexColor should default alpha to 1")

  -- applyClassColor with valid RAID_CLASS_COLORS entry (table with .r .g .b)
  local savedRCC = _G.RAID_CLASS_COLORS
  _G.RAID_CLASS_COLORS = {
    WARRIOR = { r = 0.78, g = 0.61, b = 0.43 },
  }
  local cfs = {
    SetTextColor = function(self, ...)
      self.color = { ... }
    end,
  }
  UIHelpers.applyClassColor(cfs, "warrior", { 1, 1, 1, 1 })
  assert(cfs.color[1] == 0.78, "applyClassColor should use class color r")
  assert(cfs.color[4] == 1, "applyClassColor should set alpha 1")

  -- applyClassColor with array-style class color
  _G.RAID_CLASS_COLORS = {
    MAGE = { 0.25, 0.78, 0.92 },
  }
  local cfs2 = {
    SetTextColor = function(self, ...)
      self.color = { ... }
    end,
  }
  UIHelpers.applyClassColor(cfs2, "MAGE", { 1, 1, 1, 1 })
  assert(cfs2.color[1] == 0.25, "applyClassColor array-style should use [1]")

  -- applyClassColor with unknown class falls back to fallbackColor
  _G.RAID_CLASS_COLORS = {}
  local cfs3 = {
    SetTextColor = function(self, ...)
      self.color = { ... }
    end,
  }
  UIHelpers.applyClassColor(cfs3, "UNKNOWN", { 0.9, 0.9, 0.9, 1 })
  assert(cfs3.color[1] == 0.9, "applyClassColor should fallback")

  -- applyClassColor with nil classTag falls back
  local cfs4 = {
    SetTextColor = function(self, ...)
      self.color = { ... }
    end,
  }
  UIHelpers.applyClassColor(cfs4, nil, { 0.8, 0.8, 0.8, 1 })
  assert(cfs4.color[1] == 0.8, "applyClassColor nil classTag should fallback")

  -- applyClassColor with nil RAID_CLASS_COLORS falls back
  _G.RAID_CLASS_COLORS = nil
  local cfs5 = {
    SetTextColor = function(self, ...)
      self.color = { ... }
    end,
  }
  UIHelpers.applyClassColor(cfs5, "WARRIOR", { 0.7, 0.7, 0.7, 1 })
  assert(cfs5.color[1] == 0.7, "applyClassColor nil RCC should fallback")
  _G.RAID_CLASS_COLORS = savedRCC

  -- captureFramePosition with GetPoint method
  local mockFrame = {
    GetPoint = function(self)
      return "TOPLEFT", nil, "TOPLEFT", 100, -50
    end,
  }
  local pos = UIHelpers.captureFramePosition(mockFrame)
  assert(pos.anchorPoint == "TOPLEFT", "captureFramePosition anchorPoint")
  assert(pos.relativePoint == "TOPLEFT", "captureFramePosition relativePoint")
  assert(pos.x == 100, "captureFramePosition x")
  assert(pos.y == -50, "captureFramePosition y")

  -- captureFramePosition without GetPoint (uses .point table)
  local mockFrame2 = {
    point = { "CENTER", nil, "CENTER", 10, 20 },
  }
  local pos2 = UIHelpers.captureFramePosition(mockFrame2)
  assert(pos2.anchorPoint == "CENTER", "captureFramePosition fallback anchorPoint")
  assert(pos2.x == 10, "captureFramePosition fallback x")

  -- captureFramePosition with nil GetPoint result defaults
  local mockFrame3 = {
    GetPoint = function(self)
      return nil, nil, nil, nil, nil
    end,
  }
  local pos3 = UIHelpers.captureFramePosition(mockFrame3)
  assert(pos3.anchorPoint == "CENTER", "captureFramePosition default anchorPoint")
  assert(pos3.x == 0, "captureFramePosition default x")
  assert(pos3.y == 0, "captureFramePosition default y")
end
