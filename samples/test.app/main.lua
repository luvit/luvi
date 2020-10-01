local env = require('env')
local uv = require('uv')
local bundle = require('luvi').bundle
-- Register the utils lib as a module
bundle.register("utils", "utils.lua")

local utils = require('utils')
local p = utils.prettyPrint
local stdout = utils.stdout


local function deepEqual(expected, actual, path)
  if expected == actual then
    return true
  end
  local prefix = path and (path .. ": ") or ""
  local expectedType = type(expected)
  local actualType = type(actual)
  if expectedType ~= actualType then
    return false, prefix .. "Expected type " .. expectedType .. " but found " .. actualType
  end
  if expectedType ~= "table" then
    return false, prefix .. "Expected " .. tostring(expected) .. " but found " .. tostring(actual)
  end
  local expectedLength = #expected
  local actualLength = #actual
  for key in pairs(expected) do
    if actual[key] == nil then
      return false, prefix .. "Missing table key " .. key
    end
    local newPath = path and (path .. '.' .. key) or key
    local same, message = deepEqual(expected[key], actual[key], newPath)
    if not same then
      return same, message
    end
  end
  if expectedLength ~= actualLength then
    return false, prefix .. "Expected table length " .. expectedLength .. " but found " .. actualLength
  end
  for key in pairs(actual) do
    if expected[key] == nil then
      return false, prefix .. "Unexpected table key " .. key
    end
  end
  return true
end

local env = setmetatable({}, {
  __pairs = function (table)
    local keys = env.keys(true)
    local index = 0
    return function ()
      index = index + 1
      local name = keys[index]
      if name then
        return name, table[name]
      end
    end
  end,
  __index = function (_, name)
    local value = env.get(name)
    return value
  end,
  __newindex = function (_, name, value)
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


print("Testing bundle.stat")
local rootStat = bundle.stat("")
assert(rootStat.type == "directory")
local addStat = bundle.stat("add")
assert(addStat.type == "directory")
local mainStat = bundle.stat("main.lua")
assert(mainStat.type == "file")
assert(mainStat.size > 3000)
local tests = {
  "", rootStat,
  "/", rootStat,
  "/a/../", rootStat,
  "add", addStat,
  "add/", addStat,
  "/add/", addStat,
  "foo/../add/", addStat,
  "main.lua", mainStat,
  "/main.lua", mainStat,
}
for i = 1, #tests, 2 do
  local path = tests[i]
  local expected = tests[i + 1]
  local actual = bundle.stat(path)
  p(path, actual)
  assert(deepEqual(expected, actual), "ERROR: stat(" .. path .. ")")
end

print("Testing bundle.readdir")
local rootTree = { "add", "greetings.txt", "main.lua", "sonnet-133.txt", "utils.lua" }
local addTree = { "a.lua", "b.lua", "init.lua" }
tests = {
  "", rootTree,
  "/", rootTree,
  "/a/../", rootTree,
  "add", addTree,
  "add/", addTree,
  "/add/", addTree,
  "foo/../add/", addTree,
}
table.sort(rootTree)
table.sort(addTree)
for i = 1, #tests, 2 do
  local path = tests[i]
  local expected = tests[i + 1]
  local actual = bundle.readdir(path)
  table.sort(actual)
  p(path, actual)
  assert(deepEqual(expected, actual), "ERROR: readdir(" .. path .. ")")
end

if _VERSION=="Lua 5.2" then
  print("Testing for lua 5.2 extensions")
  local thread, ismain = coroutine.running()
  p(thread, ismain)
  assert(thread)
  assert(ismain)
end

print("Testing miniz")
local miniz = require('miniz')
p(miniz)

local writer = miniz.new_writer()

local reader = miniz.new_reader(uv.exepath()) or miniz.new_reader("samples/test.zip")
if reader then
  p {
    reader=reader,
    offset=reader:get_offset(),
  }
  for i = 1, reader:get_num_files() do
    writer:add_from_zip(reader, i)
  end
end

writer:add("README.md", "# A Readme\n\nThis is neat?", 9)
writer:add("data.json", '{"name":"Tim","age":32}\n', 9)
writer:add("a/big/file.dat", string.rep("12345\n", 10000), 9)
writer:add("main.lua", 'print(require("luvi").version)', 9)

p("zip bytes", #writer:finalize())

do
  print("miniz zlib compression - full data")
  local original = string.rep(bundle.readfile("sonnet-133.txt"), 1000)
  local deflator = miniz.new_deflator(9)
  local deflated, err, part = deflator:deflate(original, "finish")
  p("Compressed", #(deflated or part or ""))
  deflated = assert(deflated, err)
  local inflator = miniz.new_inflator()
  local inflated, err, part = inflator:inflate(deflated)
  p("Decompressed", #(inflated or part or ""))
  inflated = assert(inflated, err)
  assert(inflated == original, "inflated data doesn't match original")
end

do
  print("miniz zlib compression - partial data stream")
  local original_full = bundle.readfile("sonnet-133.txt")
  local original_parts = { }
  for part in original_full:gmatch((".?"):rep(64)) do
    original_parts[#original_parts+1] = part
  end
  local deflator = miniz.new_deflator(9)
  local inflator = miniz.new_inflator()
  for i, part in ipairs(original_parts) do
    p("part", part)
    local deflated, err, partial = deflator:deflate(part,
      i == #original_parts and "finish" or "sync")
    p("compressed", deflated, partial)
    deflated = assert(not err, err) and (deflated or partial)
    local inflated, err, partial = inflator:inflate(deflated,
      i == #original_parts and "finish" or "sync")
    p("decompressed", inflated, partial)
    inflated = assert(not err, err) and (inflated or partial)

    assert(inflated == part, "inflated data doesn't match original")
  end
end

do
  print("miniz zlib compression - no stream")
  local original = string.rep(bundle.readfile("sonnet-133.txt"), 1000)
  local compressed = assert(miniz.compress(original))
  local uncompressed = assert(miniz.uncompress(compressed, #original))
  assert(uncompressed == original, "inflated data doesn't match original")
end

local options = require('luvi').options

if options.zlib then
  local zlib = require("zlib")
  print("Testing zlib")
  p("zlib version", zlib.version())
  local tozblob = bundle.readfile("sonnet-133.txt")
  local defstreamf = zlib.deflate()
  local infstreamf = zlib.inflate()
  local deflated, def_eof, def_bytes_in, def_bytes_out = defstreamf(tozblob, 'finish')
  assert(def_eof, "deflate not finished?")
  assert(def_bytes_in > def_bytes_out, "deflate failed")
  local inflated, inf_eof, inf_bytes_in, inf_bytes_out = infstreamf(deflated)
  assert(inf_eof, "inflate not finished?")
  assert(inf_bytes_in < inf_bytes_out, "inflate failed")
  assert(inf_bytes_in == def_bytes_out, "inflate byte in count != deflate byte out count")
  assert(def_bytes_in == inf_bytes_out, "inflate byte out count != deflate byte in count")
  assert(inflated == tozblob, "inflated data doesn't match original")
end

if options.rex then
  local rex = require('rex')
  local string = "The red frog sits on the blue box in the green well."
  local colors = {}
  for color in rex.gmatch(string, "(red|blue|green)") do
    colors[#colors + 1] = color
  end
  p(colors)
  assert(#colors == 3)
end

print("Testing utf8")

local emoji = "🎃"
assert(utf8.len(emoji) == 1)
assert(utf8.char(0x1F383) == emoji)
assert(emoji:match(utf8.charpattern) == emoji)
assert(utf8.offset(emoji, 1) == 1)

print("All tests pass!\n")

require('uv').run()
