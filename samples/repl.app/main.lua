local uv = require('uv')
local bundle = require('luvi').bundle

-- Register two libraries as modules
bundle.register("utils", "utils.lua")
bundle.register("repl", "repl.lua")

local utils = require('utils')
local repl = require('repl')

local stdin
if uv.guess_handle(0) == "TTY" then
  stdin = uv.new_tty(0, true)
else
  stdin = uv.new_pipe(false)
  uv.pipe_open(0)
end

local stdout
if uv.guess_handle(1) == "TTY" then
  stdout = uv.new_tty(1, false)
  utils.init(true)
else
  stdout = uv.new_pipe(false)
  uv.pipe_open(1)
  utils.init(false)
end

repl(stdin, stdout, uv, utils)

uv.run("default")
