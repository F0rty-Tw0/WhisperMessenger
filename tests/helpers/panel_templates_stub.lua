-- Records the PanelTemplates_* calls the native tabs make on the live client.

local PanelTemplatesStub = {}

function PanelTemplatesStub.stub()
  local calls = { selected = {}, deselected = {}, resized = {} }
  rawset(_G, "PanelTemplates_SelectTab", function(tab)
    calls.selected[#calls.selected + 1] = tab
  end)
  rawset(_G, "PanelTemplates_DeselectTab", function(tab)
    calls.deselected[#calls.deselected + 1] = tab
  end)
  rawset(_G, "PanelTemplates_TabResize", function(tab, padding, _absoluteSize, _minWidth, maxWidth)
    calls.resized[#calls.resized + 1] = { tab = tab, padding = padding, maxWidth = maxWidth }
  end)
  return calls
end

function PanelTemplatesStub.clear()
  rawset(_G, "PanelTemplates_SelectTab", nil)
  rawset(_G, "PanelTemplates_DeselectTab", nil)
  rawset(_G, "PanelTemplates_TabResize", nil)
end

return PanelTemplatesStub
