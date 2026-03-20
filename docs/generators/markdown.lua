local fmt = string.format
local insert, concat = table.insert, table.concat

---@class markdown.Context
---@field buffer string[]
---@field aliases_map alias_types
local Context = {}

---@return markdown.Context
function Context.initiate(docs_meta)
  -- the final output buffer
  local buffer = {}

  -- read all of the aliases and flatten them in a single lookup map
  ---@type table<string, alias>
  local aliases_map = {}
  for _, section in ipairs(docs_meta) do
    if section.aliases then
      for _, alias in ipairs(section.aliases) do
        assert(not aliases_map[alias.name], 'alias with the name @' .. alias.name .. ' is already defined')
        aliases_map[alias.name] = alias.types
      end
    end
  end

  return setmetatable({
    buffer = buffer,
    aliases_map = aliases_map,
  }, {
    __index = Context
  })
end

-- we generate the markdown on the go essentially
-- and any markdown output is written to the buffer through this
function Context:write(input, ...)
  if select('#', ...) > 0 then
    input = input:format(...)
  end
  self.buffer[#self.buffer+1] = input
end

-- concat the buffer into a single string and return it
function Context:finalize()
  return concat(self.buffer)
end

--- if value is truthy, format s and return it, otherwise return an empty string.
---@param value any
---@param s string
---@param ... any
---@return string
local function cond(value, s, ...)
  if select('#', ...) > 0 then
    s = s:format(...)
  end
  if value then
    return s
  else
    return ''
  end
end

-- Format insert. Format string s if varargs are supplied, then insert it into tbl.
---@param tbl table
---@param s string
---@param ... any
local function insertfmt(tbl, s, ...)
  if select('#', ...) > 0 then
    s = s:format(...)
  end
  return insert(tbl, s)
end

---given a value such as `{filename: string, index: integer}`, return it as a table.
---note it only accepts relevant values defined throughout the docs.
---@param str string
function Context:resolveTable(str, tbl)
  tbl = tbl or {}
  local body = str:match('{(.-)}')
  for key, value in body:gmatch('(%S+):%s*([^%s,]+)') do
    tbl[key] = value
  end
  return tbl
end

---given an array of options output a formatted string array.
---@generic T: string[]
---@param tbl T?
---@return T
function Context:resolveOptions(options, tbl)
  tbl = tbl or {}
  for _, option in ipairs(options) do
    insertfmt(tbl, '`%s`%s%s',
      option.value,
      cond(option.default, ' (default)'),
      cond(option.description, ' — %s', option.description)
    )
  end
  return tbl
end

---given a value such as `@name.of.alias`, return its value set in the aliases_map.
---@param type string
---@return string, table
function Context:resolveAlias(type, collected_fields)
  collected_fields = collected_fields or {}
  local name = type:match('^@(%S+)')
  if not name then
    return type, collected_fields
  end

  local value = self.aliases_map[name]
  assert(value, 'could not find alias @' .. name .. ', is it really defined?')

  -- Note: when the type is table, we only respect the first
  -- value because table aliases can't have more than one
  type = value[1].type
  if type == 'table' then
    -- TODO: handle when .value is not set
    self:resolveTable(value[1].value, collected_fields)
  else
    self:resolveOptions(value, collected_fields)
  end
  return type, collected_fields
end

---given an array of strings or a table of key/values format it into a bullet list and return it.
---@return string
local function formatBulletList(collected_tbl, prefix)
  prefix = prefix or ''
  local entries = {}
  -- is it a list?
  if collected_tbl[1] then
    for _, entry in ipairs(collected_tbl) do
      insertfmt(entries, '%s- %s', prefix, entry)
    end
  else
    for k, v in pairs(collected_tbl) do
      insertfmt(entries, '%s- `%s`: `%s`', prefix, k, v)
    end
  end
  return concat(entries, '\n')
end


---Given a function definition, write its signature into the buffer.
---Example output `foo.bar(a[, b], c)`.
---
---The parameters are analyzed for a more consistent and standard annotation.
---When the parameter has `omissible` set or it's an optional argument at the end
---of the parameters it will be wrapped in `[]` to indicate it can be completely left out.
---
---Multiple parameters may set omissible to the same value to combine into one group.
---That is, to group them under one shared `[]`, i.e. `a[, b, c, d]`.
---
---Internally this is done by parsing parameters into `collected_params`.
---For example, `a[, b], c, [, d, e]` will become `{a, {b}, c, {d, e}}`.
---Currently only one level down is supported (i.e. at most `a[, b]`, no `a[, b[, c]]`).
---@param interface string
---@param func method
---@param is_method boolean?
function Context:writeFuncSignature(interface, func, is_method)
  local sep = is_method and ':' or '.'
  local name = interface .. sep .. func.name
  local collected_params = {}

  local last_required_param = 0
  for index, param in ipairs(func.params) do
    if not param.optional then
      last_required_param = index
    end
  end

  -- TODO: run this resolution recursively?
  -- local last_required_group
  local last_omit_group
  for index, param in ipairs(func.params) do
    -- if the parameter is not optional, or isn't explicitly omissible
    -- and also isn't at the end of the parameters it cannot be omitted
    if not param.optional
    or not param.omissible and last_required_param > index then
      insert(collected_params, param)
      -- last_required_group = #collected_params
      last_omit_group = nil
      goto next
    end

    -- is this the first parameter to be grouped for omit?
    if not last_omit_group then
      last_omit_group = {group = true}
      insert(last_omit_group, param)
      insert(collected_params, last_omit_group)
      goto next
    end

    -- if a previous parameter has been grouped, check if this one should
    -- go with the old group or have its own group
    local pass = {
      ['nil'] = true,
      ['true'] = true,
    }
    if last_omit_group[1].omissible == param.omissible
    or (pass[tostring(last_omit_group[1].omissible)] and pass[tostring(param.omissible)]) then
      insert(last_omit_group, param)
    else
      last_omit_group = {group = true}
      insert(last_omit_group, param)
      insert(collected_params, last_omit_group)
    end

    ::next::
  end

  local param_buf = {}
  for index, grp in ipairs(collected_params) do
    if grp.group then
      insertfmt(param_buf, '[')
      for _, param in ipairs(grp) do
        insertfmt(param_buf, '%s%s', cond(index > 1, ', '), param.name)
      end
      insert(param_buf, ']')
    else
      insertfmt(param_buf, '%s%s', cond(index > 1, ', '), grp.name)
      -- insertfmt(param_buf, '%s%s', grp.name, cond(index < last_required_group, ', '))
    end
  end

  local params = concat(param_buf)
  local prefix = is_method and '> method form ' or '###'
  self:write('%s `%s(%s)`\n\n', prefix, name, params)
end
--[[
-- test usage
writeFuncSignature('', {
  name = '',
  params = {
    {
      name = 'foo',
      optional = false,
    },
    {
      name = 'start',
      optional = true,
      omissible = 1,
    },
    {
      name = 'stop',
      optional = true,
      omissible = 1,
    },
    {
      name = 'bar',
      optional = true,
      omissible = false,
    },
  },
})
os.exit()
]]

---@param params params
function Context:writeParameters(params)
  self:write('**Parameters:**\n')
  local collected_params = {}
  for _, param in pairs(params) do
    local res_type, collected_fields = self:resolveAlias(param.type)
    local fields = formatBulletList(collected_fields, '\t')

    local optional, default, description = '', '', ''
    if param.optional then
      optional = ' or `nil`'
    end
    if param.default then
      default = fmt('(default: `%s`)', param.default)
    end
    if param.description and #param.description > 0 then
      description = '— ' .. param.description
    end

    local type = fmt('`%s`%s',
      res_type,
      optional
    )

    insertfmt(collected_params, '- `%s`: %s %s%s%s',
      param.name,
      type,
      description,
      default,
      cond(#fields > 0, '\n' .. fields)
    )
  end
  self:write(concat(collected_params, '\n'))
  self:write('\n\n')
end

--- groups returns that are not in a group, and are not separated by a group, together.
local function groupReturnsLevel1(returns)
  local groups = {}
  local new_group = {}
  local function flush()
    if #new_group > 0 then
      insert(groups, new_group)
      new_group = {}
    end
  end
  for _, group in ipairs(returns) do
    if not group[1] then
      insert(new_group, group)
    else
      flush()
      insert(groups, group)
    end
  end
  flush()
  return groups
end

-- the luv-style small/simple returns.
---@param returns returns
function Context:writeReturns(returns)
  if #returns == 0 then
    return self:write('**Returns**: Nothing.\n')
  end
  local collected_groups = {} -- the returns such as `a or b or c`
  local collected_fields = {} -- the fields of any returned tables values

  local grouped_returns = groupReturnsLevel1(returns)
  for _, group in ipairs(grouped_returns) do
    local group_res = {}
    for _, rtn in ipairs(group) do
      local value, fields = self:resolveAlias(rtn.types)
      if next(fields) then
        insert(collected_fields, fields)
      end
      insertfmt(group_res, '%s%s', value, cond(rtn.nilable,'?'))
    end
    insertfmt(collected_groups, '`%s`', concat(group_res, ', '))
  end

  self:write('**Returns**: %s', concat(collected_groups, ' or '))

  if next(collected_fields) then
    for _, fields in ipairs(collected_fields) do
      self:write('\n')
      self:write(formatBulletList(fields))
    end
  end
  self:write('\n\n')
end

-- much more expanded and detailed returns.
---@param returns returns
function Context:writeReturns2(returns)
  if #returns == 0 then
    return self:write('**Returns**: Nothing.\n')
  end
  local collected_groups = {}
  local collected_fields = {}

  ---@type returns[]
  local grouped_returns = groupReturnsLevel1(returns)

  -- simple one-group returns
  if #grouped_returns == 1 then
    local res = {}
    local fields = {}
    for _, rtn in ipairs(grouped_returns[1]) do
      local value, field = self:resolveAlias(rtn.types)
      insertfmt(res, '%s%s',
        value,
        cond(rtn.nilable, '?')
      )
      if next(field) then
        fields[rtn.types] = field
      end
    end
    self:write('**Returns:** `%s`\n', concat(res, ', '))
    for name, field in pairs(fields) do
      self:write('\nFor the fields of `%s`:\n%s\n', name, formatBulletList(field))
    end
    return
  end

  -- grouped returns
  for _, group in ipairs(grouped_returns) do
    local group_res = {}
    local group_fields = {}
    for i, rtn in ipairs(group) do
      local value, fields = self:resolveAlias(rtn.types)
      if next(fields) then
        group_fields[rtn.types] = fields
      end
      insertfmt(group_res, '%d. %s%s',
        i,
        cond(rtn.name, '`%s`: `%s%s`%s',
          rtn.name,
          value,
          cond(rtn.nilable, '?'),
          cond(next(fields), '(`%s`)', rtn.types)
        ),
        rtn.description and (' — ' .. rtn.description) or '.'
      )
    end
    insert(collected_groups, '\n' .. concat(group_res, '\n'))
    insert(collected_fields, group_fields)
  end

  self:write('**Returns**:\n')

  for i, group in ipairs(collected_groups) do
    self:write(group .. '\n')
    if next(collected_fields[i]) then
      for name, fields in pairs(collected_fields[i]) do
        self:write('\n\tFor the fields of `%s`:\n%s\n', name, formatBulletList(fields, '\t'))
      end
    end
    if next(collected_groups, i) then
      self:write('\nOR\n')
    end
  end
  self:write('\n')
end
-- TODO: decide which return format to use.
Context.writeReturns = Context.writeReturns2

---@param interface string
---@param func method
function Context:writeFunction(interface, func)
  assert(func.name, 'a function must have name')
  assert(func.params, 'a function must define params')

  -- the function definition
  self:writeFuncSignature(interface, func)
  -- method form
  if func.method_form then
    local method_interface = type(func.method_form) == 'string' and func.method_form or interface
    self:writeFuncSignature(method_interface, func, true)
  end
  -- parameters
  if #func.params > 0 then
    self:writeParameters(func.params)
  end
  -- description
  if func.description and #func.description > 0 then
    self:write(func.description)
    self:write('\n\n')
  end
  -- returns
  self:writeReturns(func.returns)

  self:write('\n')
end

function Context:writeModule(module)
  self:write('# %s\n\n', module.title)
  self:write('%s\n\n', module.description)
end


---@param docs_meta meta
local function generate(docs_meta)
  local context = Context.initiate(docs_meta)

  context:writeModule(docs_meta)
  for _, section in ipairs(docs_meta) do
    context:write('## %s\n\n', section.title)
    context:write('%s\n\n', section.description)

    for _, func in pairs(section.methods) do
      context:writeFunction(section.name or docs_meta.name, func)
    end
  end
  return context:finalize()
end

return {
  generate = generate,
  extension = '.md'
}
