-- Reads and clicks the rows of the open MenuPopup.
local MenuPopup = require("WhisperMessenger.UI.Shared.MenuPopup")

local MenuPopupProbe = {}

local function plain(text)
  local stripped = string.gsub(tostring(text or ""), "|c%x%x%x%x%x%x%x%x", "")
  stripped = string.gsub(stripped, "|r", "")
  return stripped
end

-- "title:<text>", "button:<text>", "checkbox:<text>" or "divider" per row.
function MenuPopupProbe.Labels()
  local labels = {}
  for _, row in ipairs(MenuPopup.Rows()) do
    if row.kind == "divider" then
      table.insert(labels, "divider")
    else
      table.insert(labels, row.kind .. ":" .. plain(row.text))
    end
  end
  return labels
end

function MenuPopupProbe.Find(text)
  for _, row in ipairs(MenuPopup.Rows()) do
    if row.kind ~= "divider" and plain(row.text) == text then
      return row
    end
  end
  return nil
end

-- Runs the row's OnClick script like a left click.
function MenuPopupProbe.Click(text)
  local row = assert(MenuPopupProbe.Find(text), "no row " .. tostring(text))
  local onClick = assert(row.region:GetScript("OnClick"), "row " .. tostring(text) .. " has no OnClick")
  onClick(row.region, "LeftButton")
end

return MenuPopupProbe
