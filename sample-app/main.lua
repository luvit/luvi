local env = require('luvi').env
local uv = require('uv')
local dump = require('utils').dump

local stdout
if uv.guess_handle(1) == "TTY" then
  stdout = uv.new_tty(1)
  print("STDOUT is TTY")
else
  stdout = uv.new_pipe()
  uv.pipe_open(stdout, 1)
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

p("uv", uv)
p("env", setmetatable({}, {
  __pairs = function (table)
    local keys = env.keys()
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
    return env.get(name)
  end,
  __newindex = function (table, name, value)
    if value then
      env.set(name, value, 1)
    else
      env.unset(name)
    end
  end
}))
p{
  keys=env.keys(),
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
