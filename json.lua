--[[
Simple JSON encoder/decoder for Love2D/LuaJIT
Pure Lua implementation, no external dependencies
]] --

local json = {}

-- Helper function to escape strings
local function escape_str(s)
    s = string.gsub(s, "\\", "\\\\")
    s = string.gsub(s, '"', '\\"')
    s = string.gsub(s, "\n", "\\n")
    s = string.gsub(s, "\r", "\\r")
    s = string.gsub(s, "\t", "\\t")
    s = string.gsub(s, "\b", "\\b")
    s = string.gsub(s, "\f", "\\f")
    return s
end

-- Helper function to check if table is array
local function is_array(t)
    local i = 0
    for _ in pairs(t) do
        i = i + 1
        if t[i] == nil then
            return false
        end
    end
    return true
end

-- Encode Lua value to JSON string
function json.encode(val, indent)
    indent = indent or 0
    local indent_str = string.rep("  ", indent)
    local next_indent_str = string.rep("  ", indent + 1)

    if type(val) == "nil" then
        return "null"
    elseif type(val) == "boolean" then
        return val and "true" or "false"
    elseif type(val) == "number" then
        return tostring(val)
    elseif type(val) == "string" then
        return '"' .. escape_str(val) .. '"'
    elseif type(val) == "table" then
        if is_array(val) then
            if #val == 0 then
                return "[]"
            end
            local result = "[\n"
            for i = 1, #val do
                result = result .. next_indent_str .. json.encode(val[i], indent + 1)
                if i < #val then
                    result = result .. ","
                end
                result = result .. "\n"
            end
            result = result .. indent_str .. "]"
            return result
        else
            local pairs_count = 0
            for _ in pairs(val) do
                pairs_count = pairs_count + 1
            end

            if pairs_count == 0 then
                return "{}"
            end

            local result = "{\n"
            local count = 0
            for k, v in pairs(val) do
                count = count + 1
                result = result ..
                    next_indent_str .. '"' .. escape_str(tostring(k)) .. '": ' .. json.encode(v, indent + 1)
                if count < pairs_count then
                    result = result .. ","
                end
                result = result .. "\n"
            end
            result = result .. indent_str .. "}"
            return result
        end
    else
        error("Cannot encode value of type " .. type(val))
    end
end

-- Simple JSON decoder
function json.decode(str)
    str = string.gsub(str, "%s+", " ") -- Normalize whitespace

    local pos = 1

    local function skip_whitespace()
        while pos <= #str and string.match(string.sub(str, pos, pos), "%s") do
            pos = pos + 1
        end
    end

    local function parse_value()
        skip_whitespace()

        if pos > #str then
            error("Unexpected end of JSON")
        end

        local char = string.sub(str, pos, pos)

        if char == '"' then
            -- String
            pos = pos + 1
            local start = pos
            while pos <= #str do
                if string.sub(str, pos, pos) == '"' and string.sub(str, pos - 1, pos - 1) ~= "\\" then
                    local result = string.sub(str, start, pos - 1)
                    pos = pos + 1
                    -- Unescape
                    result = string.gsub(result, '\\"', '"')
                    result = string.gsub(result, '\\\\', '\\')
                    result = string.gsub(result, '\\n', '\n')
                    result = string.gsub(result, '\\r', '\r')
                    result = string.gsub(result, '\\t', '\t')
                    return result
                end
                pos = pos + 1
            end
            error("Unterminated string")
        elseif char == '{' then
            -- Object
            pos = pos + 1
            local result = {}
            skip_whitespace()

            if pos <= #str and string.sub(str, pos, pos) == '}' then
                pos = pos + 1
                return result
            end

            while true do
                -- Parse key
                local key = parse_value()
                skip_whitespace()

                if pos > #str or string.sub(str, pos, pos) ~= ':' then
                    error("Expected ':' after key")
                end
                pos = pos + 1

                -- Parse value
                local value = parse_value()
                result[key] = value

                skip_whitespace()
                if pos > #str then
                    error("Expected '}' or ','")
                end

                local next_char = string.sub(str, pos, pos)
                if next_char == '}' then
                    pos = pos + 1
                    break
                elseif next_char == ',' then
                    pos = pos + 1
                else
                    error("Expected '}' or ','")
                end
            end

            return result
        elseif char == '[' then
            -- Array
            pos = pos + 1
            local result = {}
            skip_whitespace()

            if pos <= #str and string.sub(str, pos, pos) == ']' then
                pos = pos + 1
                return result
            end

            while true do
                local value = parse_value()
                table.insert(result, value)

                skip_whitespace()
                if pos > #str then
                    error("Expected ']' or ','")
                end

                local next_char = string.sub(str, pos, pos)
                if next_char == ']' then
                    pos = pos + 1
                    break
                elseif next_char == ',' then
                    pos = pos + 1
                else
                    error("Expected ']' or ','")
                end
            end

            return result
        elseif char == 't' then
            -- true
            if string.sub(str, pos, pos + 3) == "true" then
                pos = pos + 4
                return true
            else
                error("Invalid token")
            end
        elseif char == 'f' then
            -- false
            if string.sub(str, pos, pos + 4) == "false" then
                pos = pos + 5
                return false
            else
                error("Invalid token")
            end
        elseif char == 'n' then
            -- null
            if string.sub(str, pos, pos + 3) == "null" then
                pos = pos + 4
                return nil
            else
                error("Invalid token")
            end
        elseif char == '-' or (char >= '0' and char <= '9') then
            -- Number
            local start = pos
            if char == '-' then
                pos = pos + 1
            end

            while pos <= #str and string.sub(str, pos, pos) >= '0' and string.sub(str, pos, pos) <= '9' do
                pos = pos + 1
            end

            if pos <= #str and string.sub(str, pos, pos) == '.' then
                pos = pos + 1
                while pos <= #str and string.sub(str, pos, pos) >= '0' and string.sub(str, pos, pos) <= '9' do
                    pos = pos + 1
                end
            end

            local num_str = string.sub(str, start, pos - 1)
            return tonumber(num_str)
        else
            error("Unexpected character: " .. char)
        end
    end

    return parse_value()
end

return json
