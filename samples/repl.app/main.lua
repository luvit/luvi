local uv = require('uv')
local bundle = require('luvi').bundle

-- Register two libraries as modules
bundle.register("utils", "utils.lua")
bundle.register("repl", "repl.lua")

local utils = require('utils')
local repl = require('repl')

local stdin = utils.stdin
local stdout = utils.stdout

local c = utils.color
local greeting = "Welcome to the " .. c("err") .. "L" .. c("quotes") .. "uv" .. c("table") .. "i" .. c() .. " repl!"
repl(stdin, stdout, uv, utils, greeting)

uv.run("default")
