-- This runs `make regular` with all possible combinations of defines and checks if it succeeds
-- This is currently 2916 invocations
--
-- This script expects:
-- - an environment that can build luvi using the Makefile
-- - Lua and Luajit (and their libraries)
-- - Libluv (the library, not the module)
-- - Libuv
-- - openssl
-- - pcre
-- - zlib
local matrix = {""}

local function addDefineToMatrix(name, values, requires)
    local new_matrix = {}

    for _, old_value in ipairs(matrix) do
        if requires and string.find(old_value, requires, 1, true) or
            not requires then
            for _, value in ipairs(values) do
                table.insert(new_matrix,
                             old_value .. " " .. name .. "=" .. value)
            end
        else
            table.insert(new_matrix, old_value)
        end
    end

    matrix = new_matrix
end

addDefineToMatrix("CMAKE_BUILD_TYPE", {"Release", "RelWithDebInfo", "Debug"})
addDefineToMatrix("WITH_AMALG", {"ON", "OFF"})
addDefineToMatrix("WITH_SHARED_LIBLUV", {"ON", "OFF"})
addDefineToMatrix("WITH_SHARED_LIBUV", {"ON", "OFF"}, "WITH_SHARED_LIBLUV=OFF")
addDefineToMatrix("WITH_SHARED_LIBLUA", {"ON", "OFF"}, "WITH_SHARED_LIBLUV=OFF")
-- Shared libluv is usually only luajit, so we don't test it with lua
addDefineToMatrix("WITH_LUA_ENGINE", {"Lua", "LuaJIT"}, "WITH_SHARED_LIBLUV=OFF")

addDefineToMatrix("WITH_OPENSSL", {"ON", "OFF"})
addDefineToMatrix("WITH_PCRE", {"ON", "OFF"})
addDefineToMatrix("WITH_LPEG", {"ON", "OFF"})
addDefineToMatrix("WITH_ZLIB", {"ON", "OFF"})

addDefineToMatrix("WITH_SHARED_OPENSSL", {"ON", "OFF"}, "WITH_OPENSSL=ON")
addDefineToMatrix("WITH_SHARED_PCRE", {"ON", "OFF"}, "WITH_PCRE=ON")
addDefineToMatrix("WITH_SHARED_ZLIB", {"ON", "OFF"}, "WITH_ZLIB=ON")

local configure =
    'env make regular BUILD_PREFIX=build%d %s >logs/%d.configure.log 2>&1'
local info = "echo %q > build%d/matrix.txt"
local build = "make BUILD_PREFIX=build%d >logs/%d.build.log 2>&1"
local test = "make test BUILD_PREFIX=build%d >logs/%d.test.log 2>&1"
local clean = "(rm -rf logs/%d.*.log build%d &)"

os.execute("rm -rf logs build*")
os.execute("mkdir -p logs")
for i, value in ipairs(matrix) do
    io.write(i .. " / " .. #matrix .. "... ")
    io.flush()

    local configure_text = string.format(configure, i, value, i)
    local info_text = string.format(info, value, i)
    local build_text = string.format(build, i, i)
    local test_text = string.format(test, i, i)
    local clean_text = string.format(clean, i, i)

    local command = configure_text .. ' && ' .. info_text .. ' && ' ..
                        build_text .. ' && ' .. test_text .. ' && ' ..
                        clean_text

    local _, _, ret = os.execute(command)
    if ret == 0 then
        print("Success")
    else
        if ret == 2 then break end
        print("Failed")
    end
end
