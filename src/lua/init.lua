--[[

Copyright 2014 The Luvit Authors. All Rights Reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS-IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

--]]

local uv = require('uv')
local luvi = require('luvi')
local miniz = require('miniz')

local luviBundle = require('luvibundle')
local commonBundle = luviBundle.commonBundle
local makeBundle = luviBundle.makeBundle
local buildBundle = luviBundle.buildBundle

local function generateOptionsString()
  local s = {}
  for k, v in pairs(luvi.options) do
    if type(v) == 'boolean' then
      table.insert(s, k)
    else
      table.insert(s, string.format("%s: %s", k, v))
    end
  end
  return table.concat(s, "\n")
end

local commands = {
  ["-o"] = "output",
  ["--output"] = "output",
  ["-m"] = "main",
  ["--main"] = "main",
  ["-v"] = "version",
  ["--version"] = "version",
  ["-h"] = "help",
  ["--help"] = "help",
}

local function version(args)
  print(string.format("%s %s", args[0], luvi.version))
  print(generateOptionsString())
end

local function help(args)

  local usage = [[
Usage: $(LUVI) bundle+ [options] [-- extra args]

  bundle            Path to directory or zip file containing bundle source.
                    `bundle` can be specified multiple times to layer bundles
                    on top of each other.
  --version         Show luvi version and compiled in options.
  --output target   Build a luvi app by zipping the bundle and inserting luvi.
  --main path       Specify a custom main bundle path (normally main.lua)
  --help            Show this help file.
  --                All args after this go to the luvi app itself.

Examples:

  # Run an app from disk, but pass in arguments
  $(LUVI) path/to/app -- app args

  # Run from a app zip
  $(LUVI) path/to/app.zip

  # Run an app that layers on top of luvit
  $(LUVI) path/to/app path/to/luvit

  # Bundle an app with luvi to create standalone
  $(LUVI) path/to/app -o target
  ./target some args

  # Run unit tests for a luvi app using custom main
  $(LUVI) path/to/app -m tests/run.lua
]]
  print((string.gsub(usage, "%$%(LUVI%)", args[0])))
end

return function(args)

  -- First check for a bundled zip file appended to the executable
  local path = uv.exepath()
  local zip = miniz.new_reader(path)
  if zip then
    return commonBundle({path}, nil, args)
  end

  -- Parse the arguments
  local bundles = { }
  local options = {}
  local appArgs = { [0] = args[0] }

  local key
  for i = 1, #args do
    local arg = args[i]
    if arg == "--" then
      if #bundles == 0 then
        i = i + 1
        bundles[1] = args[i]
      end
      for j = i + 1, #args do
        appArgs[#appArgs + 1] = args[j]
      end
      break
    elseif key then
      options[key] = arg
      key = nil
    else
      local command = commands[arg]
      if options[command] then
        error("Duplicate flags: " .. command)
      end
      if command == "output" or command == "main" then
        key = command
      elseif command then
        options[command] = true
      else
        if arg:sub(1, 1) == "-" then
          error("Unknown flag: " .. arg)
        end
        bundles[#bundles + 1] = arg
      end
    end
  end

  if key then
    error("Missing value for option: " .. key)
  end

  -- Show help and version by default
  if #bundles == 0 and not options.version and not options.help then
    options.version = true
    options.help = true
  end

  if options.version then
    version(args)
  end
  if options.help then
    help(args)
  end

  -- Don't run app when printing version or help
  if options.version or options.help then return -1 end

  -- Build the app if output is given
  if options.output then
    return buildBundle(options.output, makeBundle(bundles))
  end

  -- Run the luvi app with the extra args
  return commonBundle(bundles, options.main, appArgs)

end
