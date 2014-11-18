local uv = require('uv')
local stderr = require('utils').stderr

local add = require('zip').writer(function (chunk)
  p(chunk)
  uv.write(stderr, chunk)
end)

add("README.md", "# A Readme\n\nThis is neat?")
add("data.json", '{"name":"Tim","age":32}\n')
add("a/big/file.dat", string.rep("12345\n", 10000))
add("main.lua", 'print(require("luvi").version)')
add()
