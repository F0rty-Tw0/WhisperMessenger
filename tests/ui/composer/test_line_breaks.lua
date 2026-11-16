local LineBreaks = require("WhisperMessenger.UI.Composer.LineBreaks")

local CASES = {
  { name = "no break", text = "ab", cursor = 2, wantText = "ab", wantCursor = 2 },
  { name = "Enter at end", text = "ab\n", cursor = 3, wantText = "ab", wantCursor = 2 },
  { name = "break before more text is a paste", text = "a\nb", cursor = 2, wantText = "a b", wantCursor = 2 },
  { name = "paste with the cursor right after the break", text = "hello\nworld", cursor = 6, wantText = "hello world", wantCursor = 6 },
  { name = "Enter after the box was cleared", text = "\n", cursor = 1, wantText = "", wantCursor = 0 },
  { name = "typed CRLF", text = "ab\r\n", cursor = 4, wantText = "ab", wantCursor = 2 },
  { name = "paste", text = "x\ny\nz", cursor = 5, wantText = "x y z", wantCursor = 5 },
  { name = "paste with CRLF", text = "x\r\ny", cursor = 4, wantText = "x y", wantCursor = 3 },
  { name = "lone break not at the cursor", text = "a\nb", cursor = 1, wantText = "a b", wantCursor = 1 },
  { name = "paste ending in a break", text = "p\nq\n", cursor = 4, wantText = "p q ", wantCursor = 4 },
}

return function()
  for _, case in ipairs(CASES) do
    local text, cursor = LineBreaks.Flatten(case.text, case.cursor)
    assert(text == case.wantText, case.name .. ": text " .. string.format("%q", tostring(text)))
    assert(cursor == case.wantCursor, case.name .. ": cursor " .. tostring(cursor))
  end
end
