local env = require('luvi').env
local uv = require('uv')
local bundle = require('luvi').bundle
-- Register the utils lib as a module
bundle.register("utils", "utils.lua")

local utils = require('utils')
local dump = require('utils').dump

local stdout
if uv.guess_handle(1) == "TTY" then
  stdout = uv.new_tty(1, false)
  utils.init(true)
  print("STDOUT is TTY")
else
  stdout = uv.new_pipe(false)
  uv.pipe_open(stdout, 1)
  utils.init(false)
  print("STDOUT is PIPE")
end

_G.p = function (...)
  local n = select('#', ...)
  local arguments = { ... }

  for i = 1, n do
    arguments[i] = dump(arguments[i])
  end

  local toWrite = table.concat(arguments, "\t") .. "\n"
  uv.write(stdout, toWrite);
end

local env = setmetatable({}, {
  __pairs = function (table)
    local keys = env.keys(true)
    local index = 0
    return function (...)
      index = index + 1
      local name = keys[index]
      if name then
        return name, table[name]
      end
    end
  end,
  __index = function (table, name)
    local value = env.get(name)
    return value
  end,
  __newindex = function (table, name, value)
    if value then
      env.set(name, value)
    else
      env.unset(name)
    end
  end
})

-- Make sure unicode can round-trip in unicode environment variable names and values.
local r1 = "На берегу пустынных волн"
local r2 = "Стоял он, дум великих полн"
env[r1] = r2
assert(env[r1] == r2)
p(env)
p{
  args=args,
  bundle=bundle
}
p{
  [""] = bundle.stat(""),
  ["add"] = bundle.stat("add"),
  ["main.lua"] = bundle.stat("main.lua"),
  ["fake"] = bundle.stat("fake"),
}
p(bundle.readfile("greetings.txt"))
p("readdir", bundle.readdir(""))
p{
  ["1"] = bundle.stat("1"),
  ["2"] = bundle.stat("2"),
}

p(coroutine.running())
