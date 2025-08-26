-- Example usage of the Ollama module in Love2D
local Ollama = require("ollama")

-- Example usage in your Love2D game
local function example_usage()
    -- Create Ollama client
    local ollama = Ollama.new({
        host = "localhost",
        port = 11434
    })

    -- Example 1: Generate a response
    ollama:generate("llama3.2", "Tell me a joke", function(success, response)
        if success then
            print("Generated response:", response.response)
        else
            print("Error:", response)
        end
    end)

    -- Example 2: Start a chat conversation
    ollama:respond("llama3.2", "Hello! What's your name?", function(success, response)
        if success then
            print("Chat response:", response.message.content)

            -- Continue the conversation
            ollama:respond("llama3.2", "Can you help me with Lua programming?", function(success2, response2)
                if success2 then
                    print("Follow-up response:", response2.message.content)
                end
            end)
        end
    end)

    -- Example 3: Add a tool for the model to use
    ollama:addTool("get_weather", "Get current weather for a location", {
        type = "object",
        properties = {
            location = {
                type = "string",
                description = "The city and state, e.g. San Francisco, CA"
            }
        },
        required = { "location" }
    }, function(args)
        -- This is your tool implementation
        return "The weather in " .. args.location .. " is sunny and 72°F"
    end)

    -- Example 4: Use the model with tools
    ollama:respond("llama3.2", "What's the weather like in New York?", function(success, response)
        if success and response.message.tool_calls then
            -- Handle tool calls
            for _, tool_call in ipairs(response.message.tool_calls) do
                local result = ollama:_handleToolCall(tool_call)
                print("Tool result:", result)
            end
        elseif success then
            print("Response:", response.message.content)
        end
    end)

    -- Example 5: List available models
    ollama:listModels(function(success, response)
        if success then
            print("Available models:")
            for _, model in ipairs(response.models or {}) do
                print("- " .. model.name)
            end
        end
    end)

    return ollama
end

-- Integration with Love2D
local ollama_client = nil

function love.load()
    ollama_client = example_usage()
end

function love.update(dt)
    -- Process pending HTTP responses
    if ollama_client then
        ollama_client:update()
    end
end

-- You can also use it in your game scenes
return {
    example_usage = example_usage
}
