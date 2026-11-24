local fs = require 'fs'
local join = require 'pathjoin'.pathJoin
local generators = require './generators'

local function dir(path)
  if not fs.existsSync(path) then
    assert(fs.mkdirpSync(path))
  end
  return path
end

-- TODO: a full CLI tool?

local output_dir = dir('./output')
local input_dir = dir('./modules')

local modules_docs = {}
for entry, entry_type in fs.scandirSync(input_dir) do
  if entry_type == 'file' then
    table.insert(modules_docs, dofile(join(input_dir, entry)))
  end
end

for _, docs in ipairs(modules_docs) do
  for gen_name, generator in pairs(generators) do
    local content = generator.generate(docs)
    local dir_path = dir(join(output_dir, gen_name))
    local file_name = docs.name .. generator.extension
    assert(fs.writeFileSync(join(dir_path, file_name), content))
  end
end
