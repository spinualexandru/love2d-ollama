--[[
Ollama API Module for Love2D/LuaJIT
Compatible with Love2D without external dependencies
Uses love.thread for async HTTP requests
]]                          --

local json = require "json" -- You'll need a pure Lua JSON library

local Ollama = {}
Ollama.__index = Ollama

-- Default configuration
local DEFAULT_CONFIG = {
    host = "localhost",
    port = 11434,
    timeout = 30,
    stream = false
}

function Ollama.new(config)
    local self = setmetatable({}, Ollama)
    self.config = {}

    -- Merge default config with user config
    for k, v in pairs(DEFAULT_CONFIG) do
        self.config[k] = (config and config[k]) or v
    end

    self.base_url = string.format("http://%s:%d", self.config.host, self.config.port)
    self.chat_history = {}
    self.tools = {}
    self.active_requests = {}

    return self
end

-- Helper function to make HTTP requests
function Ollama:_makeRequest(endpoint, data, callback)
    local url = self.base_url .. endpoint
    local json_data = json.encode(data)

    print("Debug: Making Ollama request to:", url)
    print("Debug: Request data:", json_data:sub(1, 100) .. (json_data:len() > 100 and "..." or ""))

    -- Create a thread for the HTTP request
    local callback_id = tostring(os.time()) .. "_" .. math.random(1000, 9999)
    local thread_code = string.format([[
        local socket = require("socket")
        local http = require("socket.http")
        local ltn12 = require("ltn12")

        local url = "%s"
        local json_data = %q
        local response_body = {}

        print("Debug: Thread starting HTTP request to:", url)

        local result, status, headers = http.request{
            url = url,
            method = "POST",
            headers = {
                ["Content-Type"] = "application/json",
                ["Content-Length"] = tostring(#json_data)
            },
            source = ltn12.source.string(json_data),
            sink = ltn12.sink.table(response_body)
        }

        local response = table.concat(response_body)
        print("Debug: Thread HTTP response - Status:", status, "Length:", #response)

        love.thread.getChannel("ollama_response"):push({
            success = (status == 200),
            status = status,
            response = response,
            callback_id = "%s"
        })

        print("Debug: Thread finished, response sent to channel")
    ]], url, json_data, callback_id)

    -- If Love2D threading is available
    if love and love.thread then
        local thread = love.thread.newThread(thread_code)
        thread:start()

        -- Store callback for later execution
        if callback then
            self.active_requests[callback_id] = callback
            print("Debug: Stored callback with ID:", callback_id)
        end
    else
        -- Fallback for environments without Love2D threading
        print("Warning: Love2D threading not available. HTTP requests will be synchronous.")
        self:_makeRequestSync(url, json_data, callback)
    end
end -- Synchronous fallback (basic implementation)

function Ollama:_makeRequestSync(url, json_data, callback)
    -- This is a basic implementation - in a real scenario you'd need a proper HTTP client
    if callback then
        callback(false, "Threading not available")
    end
end

-- Process pending HTTP responses
function Ollama:update()
    if love and love.thread then
        local channel = love.thread.getChannel("ollama_response")
        local response = channel:pop()

        while response do
            print("Debug: Processing Ollama response:", response.success, response.callback_id)
            local callback = self.active_requests[response.callback_id]
            if callback then
                if response.success then
                    local success, parsed_response = pcall(json.decode, response.response)
                    if success then
                        callback(true, parsed_response)
                    else
                        print("Debug: JSON decode failed:", parsed_response)
                        callback(false, "JSON decode error: " .. tostring(parsed_response))
                    end
                else
                    print("Debug: HTTP request failed:", response.status)
                    callback(false, "HTTP Error: " .. (response.status or "unknown"))
                end
                self.active_requests[response.callback_id] = nil
            else
                print("Debug: No callback found for:", response.callback_id)
            end
            response = channel:pop()
        end
    end
end

-- Start or continue a chat session
function Ollama:chat(model, messages, callback, options)
    local data = {
        model = model,
        messages = messages or self.chat_history,
        stream = self.config.stream,
        tools = next(self.tools) and self.tools or nil
    }

    -- Add optional parameters
    if options then
        for k, v in pairs(options) do
            data[k] = v
        end
    end

    self:_makeRequest("/api/chat", data, function(success, response)
        if success and response.message then
            -- Add response to chat history
            table.insert(self.chat_history, response.message)
        end

        if callback then
            callback(success, response)
        end
    end)
end

-- Generate completion from a prompt
function Ollama:generate(model, prompt, callback, options)
    local data = {
        model = model,
        prompt = prompt,
        stream = self.config.stream
    }

    -- Add optional parameters
    if options then
        for k, v in pairs(options) do
            data[k] = v
        end
    end

    self:_makeRequest("/api/generate", data, callback)
end

-- Add a message to chat history and get response
function Ollama:respond(model, message, callback, options)
    -- Add user message to history
    table.insert(self.chat_history, {
        role = "user",
        content = message
    })

    -- Get response from model
    self:chat(model, nil, callback, options)
end

-- Add a tool/function for the model to use
function Ollama:addTool(name, description, parameters, handler)
    self.tools = self.tools or {}

    self.tools[name] = {
        type = "function",
        ["function"] = {
            name = name,
            description = description,
            parameters = parameters
        },
        handler = handler
    }
end

-- Remove a tool
function Ollama:removeTool(name)
    if self.tools then
        self.tools[name] = nil
    end
end

-- Clear chat history
function Ollama:clearHistory()
    self.chat_history = {}
end

-- Get current chat history
function Ollama:getHistory()
    return self.chat_history
end

-- List available models
function Ollama:listModels(callback)
    self:_makeRequest("/api/tags", {}, callback)
end

-- Pull/download a model
function Ollama:pullModel(model, callback)
    local data = {
        name = model
    }

    self:_makeRequest("/api/pull", data, callback)
end

-- Delete a model
function Ollama:deleteModel(model, callback)
    local data = {
        name = model
    }

    self:_makeRequest("/api/delete", data, callback)
end

-- Show model information
function Ollama:showModel(model, callback)
    local data = {
        name = model
    }

    self:_makeRequest("/api/show", data, callback)
end

-- Handle tool calls from the model
function Ollama:_handleToolCall(tool_call)
    local tool_name = tool_call["function"].name
    local tool = self.tools[tool_name]

    if tool and tool.handler then
        local args = json.decode(tool_call["function"].arguments or "{}")
        return tool.handler(args)
    else
        return "Tool not found: " .. tool_name
    end
end

-- Set streaming mode
function Ollama:setStreaming(enabled)
    self.config.stream = enabled
end

-- Get connection status
function Ollama:isConnected(callback)
    self:_makeRequest("/", {}, function(success, response)
        if callback then
            callback(success)
        end
    end)
end

return Ollama
