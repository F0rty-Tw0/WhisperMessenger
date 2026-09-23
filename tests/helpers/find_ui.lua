-- Locates widgets inside a FakeUI frame tree (every frame, texture and
-- FontString is recorded in its parent's `children`), so tests reach
-- controls the way a player does -- by their visible label -- instead of
-- through handles production code would otherwise have to return.

local ToggleSwitch = require("WhisperMessenger.UI.Helpers.ToggleSwitch")

local FindUI = {}

-- Depth-first search below `root`; returns the first node matching `predicate`.
function FindUI.find(root, predicate)
  for _, child in ipairs(root.children or {}) do
    if predicate(child) then
      return child
    end
    local hit = FindUI.find(child, predicate)
    if hit then
      return hit
    end
  end
  return nil
end

-- FontString below `root` whose text equals `text`.
function FindUI.text(root, text)
  return FindUI.find(root, function(node)
    return node.frameType == "FontString" and node.text == text
  end)
end

-- Frame that owns the FontString labelled `labelText`: a toggle, slider or
-- selector row, or a button. Errors when no such label exists.
function FindUI.byLabel(root, labelText)
  local label = FindUI.text(root, labelText)
  assert(label, "no control labelled '" .. tostring(labelText) .. "'")
  return label.parent
end

-- Direct children of `frame` with the given frameType, in creation order.
function FindUI.ofType(frame, frameType)
  local out = {}
  for _, child in ipairs(frame.children or {}) do
    if child.frameType == frameType then
      out[#out + 1] = child
    end
  end
  return out
end

-- Slider inside the row labelled `labelText`.
function FindUI.slider(root, labelText)
  return FindUI.ofType(FindUI.byLabel(root, labelText), "Slider")[1]
end

-- Switch button of the toggle row labelled `labelText`.
function FindUI.toggle(root, labelText)
  return FindUI.ofType(FindUI.byLabel(root, labelText), "Button")[1]
end

-- A toggle is on when its knob sits on the right of the switch. The track's
-- rounded corners share the knob's circle texture, so match on size too.
function FindUI.isToggleOn(switchButton)
  local knob = FindUI.find(switchButton, function(node)
    return node.texturePath == ToggleSwitch.KNOB_TEXTURE and node.width == ToggleSwitch.KNOB_SIZE
  end)
  assert(knob and knob.point, "toggle switch has no positioned knob")
  return knob.point[1] == "RIGHT"
end

-- Option buttons of the ButtonSelector row labelled `labelText`.
function FindUI.selectorButtons(root, labelText)
  return FindUI.ofType(FindUI.byLabel(root, labelText), "Button")
end

-- Popup menu (ScrollFrame) of a DropdownSelector row.
function FindUI.dropdownMenu(row)
  return FindUI.ofType(row, "ScrollFrame")[1]
end

-- Listed (shown) option buttons of a DropdownSelector row, in order; pooled
-- buttons left over from a longer list stay hidden and are skipped.
function FindUI.dropdownOptions(row)
  local content = FindUI.ofType(FindUI.dropdownMenu(row), "Frame")[1]
  local listed = {}
  for _, button in ipairs(FindUI.ofType(content, "Button")) do
    if button:IsShown() then
      listed[#listed + 1] = button
    end
  end
  return listed
end

function FindUI.click(button)
  local onClick = button:GetScript("OnClick")
  assert(onClick, "button has no OnClick handler")
  onClick(button)
end

return FindUI
