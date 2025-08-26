# love2d-ollama

A pure Lua Ollama client for Love2D with asynchronous HTTP support and no external dependencies.

## Features

- **Asynchronous HTTP requests** using Love2D threading
- **Chat conversations** with persistent history
- **Function calling/tools** support
- **Streaming responses** (configurable)
- **Love2D integration** with update loop
- **No external dependencies** (includes pure Lua JSON parser)
- **Model management** (list, pull, delete, show info)
- **Non-blocking** operations for smooth game performance

## Requirements

- [Love2D](https://love2d.org/) 11.0 or higher
- [Ollama](https://ollama.ai/) server running locally or remotely

## Installation

1. Download or clone this repository
2. Copy `ollama.lua` and `json.lua` to your Love2D project
3. Require the module in your code:

```lua
local Ollama = require("ollama")
```

## Quick Start

```lua
local Ollama = require("ollama")
local ollama_client

function love.load()
    -- Create Ollama client
    ollama_client = Ollama.new({
        host = "localhost",  -- Ollama server host
        port = 11434,        -- Ollama server port
        timeout = 30,        -- Request timeout in seconds
        stream = false       -- Enable/disable streaming responses
    })
    
    -- Generate a simple response
    ollama_client:generate("llama3.2", "Hello, world!", function(success, response)
        if success then
            print("Response:", response.response)
        else
            print("Error:", response)
        end
    end)
end

function love.update(dt)
    -- Process pending HTTP responses (REQUIRED)
    ollama_client:update()
end
```

## API Reference

### Constructor

#### `Ollama.new(config)`

Creates a new Ollama client instance.

**Parameters:**
- `config` (table, optional): Configuration options
  - `host` (string): Ollama server hostname (default: "localhost")
  - `port` (number): Ollama server port (default: 11434)
  - `timeout` (number): Request timeout in seconds (default: 30)
  - `stream` (boolean): Enable streaming responses (default: false)

**Returns:** Ollama client instance

### Text Generation

#### `ollama:generate(model, prompt, callback, options)`

Generate a completion from a prompt.

**Parameters:**
- `model` (string): Model name (e.g., "llama3.2", "codellama")
- `prompt` (string): Text prompt for generation
- `callback` (function): Callback function `(success, response)`
- `options` (table, optional): Additional generation options

**Example:**
```lua
ollama:generate("llama3.2", "Write a haiku about programming", function(success, response)
    if success then
        print(response.response)
    end
end)
```

### Chat Conversations

#### `ollama:chat(model, messages, callback, options)`

Start or continue a chat session with custom messages.

**Parameters:**
- `model` (string): Model name
- `messages` (table, optional): Array of message objects, uses chat history if nil
- `callback` (function): Callback function `(success, response)`
- `options` (table, optional): Additional chat options

#### `ollama:respond(model, message, callback, options)`

Add a user message to chat history and get a response.

**Parameters:**
- `model` (string): Model name
- `message` (string): User message
- `callback` (function): Callback function `(success, response)`
- `options` (table, optional): Additional options

**Example:**
```lua
-- Start a conversation
ollama:respond("llama3.2", "What's the capital of France?", function(success, response)
    if success then
        print("AI:", response.message.content)
        
        -- Continue the conversation
        ollama:respond("llama3.2", "What about Italy?", function(success2, response2)
            if success2 then
                print("AI:", response2.message.content)
            end
        end)
    end
end)
```

### Function Calling/Tools

#### `ollama:addTool(name, description, parameters, handler)`

Add a function/tool that the model can call.

**Parameters:**
- `name` (string): Tool name
- `description` (string): Tool description for the model
- `parameters` (table): JSON schema describing parameters
- `handler` (function): Function to execute when tool is called

**Example:**
```lua
ollama:addTool("get_weather", "Get current weather for a location", {
    type = "object",
    properties = {
        location = {
            type = "string",
            description = "The city and state, e.g. San Francisco, CA"
        }
    },
    required = {"location"}
}, function(args)
    return "The weather in " .. args.location .. " is sunny and 72°F"
end)

-- Use the tool
ollama:respond("llama3.2", "What's the weather in Tokyo?", function(success, response)
    if success and response.message.tool_calls then
        for _, tool_call in ipairs(response.message.tool_calls) do
            local result = ollama:_handleToolCall(tool_call)
            print("Tool result:", result)
        end
    end
end)
```

#### `ollama:removeTool(name)`

Remove a previously added tool.

### Chat History Management

#### `ollama:clearHistory()`

Clear the current chat history.

#### `ollama:getHistory()`

Get the current chat history as an array of messages.

### Model Management

#### `ollama:listModels(callback)`

List all available models.

```lua
ollama:listModels(function(success, response)
    if success then
        for _, model in ipairs(response.models or {}) do
            print("Model:", model.name)
        end
    end
end)
```

#### `ollama:pullModel(model, callback)`

Download/pull a model from the Ollama library.

#### `ollama:deleteModel(model, callback)`

Delete a model from local storage.

#### `ollama:showModel(model, callback)`

Get detailed information about a model.

### Utility Methods

#### `ollama:update()`

Process pending HTTP responses. **Must be called in `love.update()`**.

#### `ollama:setStreaming(enabled)`

Enable or disable streaming responses.

#### `ollama:isConnected(callback)`

Check if the Ollama server is reachable.

## Complete Example

```lua
local Ollama = require("ollama")

local ollama_client
local conversation = {}
local input_text = ""
local waiting_for_response = false

function love.load()
    ollama_client = Ollama.new()
    
    -- Add a simple tool
    ollama_client:addTool("roll_dice", "Roll a dice", {
        type = "object",
        properties = {
            sides = {type = "number", description = "Number of sides on the dice"}
        },
        required = {"sides"}
    }, function(args)
        return "Rolled: " .. math.random(1, args.sides)
    end)
    
    -- Check connection
    ollama_client:isConnected(function(success)
        if success then
            print("Connected to Ollama server!")
        else
            print("Failed to connect to Ollama server")
        end
    end)
end

function love.update(dt)
    -- REQUIRED: Process HTTP responses
    ollama_client:update()
end

function love.textinput(text)
    if not waiting_for_response then
        input_text = input_text .. text
    end
end

function love.keypressed(key)
    if key == "return" and input_text ~= "" and not waiting_for_response then
        waiting_for_response = true
        table.insert(conversation, {role = "user", content = input_text})
        
        ollama_client:respond("llama3.2", input_text, function(success, response)
            waiting_for_response = false
            if success then
                table.insert(conversation, {role = "assistant", content = response.message.content})
                
                -- Handle tool calls
                if response.message.tool_calls then
                    for _, tool_call in ipairs(response.message.tool_calls) do
                        local result = ollama_client:_handleToolCall(tool_call)
                        table.insert(conversation, {role = "tool", content = result})
                    end
                end
            else
                table.insert(conversation, {role = "error", content = "Error: " .. tostring(response)})
            end
            input_text = ""
        end)
    elseif key == "backspace" then
        input_text = input_text:sub(1, -2)
    end
end

function love.draw()
    -- Draw conversation
    local y = 10
    for _, msg in ipairs(conversation) do
        love.graphics.print(msg.role .. ": " .. msg.content, 10, y)
        y = y + 20
    end
    
    -- Draw input
    love.graphics.print("You: " .. input_text .. (waiting_for_response and " (waiting...)" or "_"), 10, y + 20)
end
```

## Configuration

The client can be configured with various options:

```lua
local ollama = Ollama.new({
    host = "192.168.1.100",  -- Remote Ollama server
    port = 11434,            -- Custom port
    timeout = 60,            -- Longer timeout for large models
    stream = true            -- Enable streaming for real-time responses
})
```

## Error Handling

All callbacks follow the pattern `(success, response)`:

```lua
ollama:generate("llama3.2", "Hello", function(success, response)
    if success then
        -- response contains the API response
        print("Generated:", response.response)
    else
        -- response contains error message
        print("Error:", response)
    end
end)
```

## Dependencies

This project includes:
- `json.lua`: Pure Lua JSON encoder/decoder
- `ollama.lua`: Main Ollama client implementation

No external dependencies or C libraries required!

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test with Love2D
5. Submit a pull request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [Ollama](https://ollama.ai/) for the excellent local LLM server
- [Love2D](https://love2d.org/) for the amazing game framework
- The Lua community for inspiration and support
