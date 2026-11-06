-- Records the text Copy Text hands to the manual copy popup while fn(capture)
-- runs, then puts the real popup globals back.
local ManualCopyCapture = {}

local MANUAL_COPY_DIALOG_NAME = "WHISPER_MESSENGER_BUBBLE_COPY_TEXT"

function ManualCopyCapture.With(fn)
  local saved = {
    dialogs = rawget(_G, "StaticPopupDialogs"),
    show = rawget(_G, "StaticPopup_Show"),
  }
  local capture = { text = nil, count = 0 }
  rawset(_G, "StaticPopupDialogs", {})
  rawset(_G, "StaticPopup_Show", function(which, _text1, _text2, data)
    if which == MANUAL_COPY_DIALOG_NAME then
      capture.count = capture.count + 1
      capture.text = data
    end
    return { data = data }
  end)
  local ok, err = pcall(fn, capture)
  rawset(_G, "StaticPopupDialogs", saved.dialogs)
  rawset(_G, "StaticPopup_Show", saved.show)
  if not ok then
    error(err, 0)
  end
end

return ManualCopyCapture
