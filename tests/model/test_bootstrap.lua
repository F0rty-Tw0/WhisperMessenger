local Bootstrap = require("WhisperMessenger.Bootstrap")

return function()
  assert(type(Bootstrap.Initialize) == "function", "Bootstrap.Initialize should exist")
end
