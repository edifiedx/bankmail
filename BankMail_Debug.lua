-- Create the module
local addonName = "BankMail"
local Debug = {
    initialized = false,
    modules = {}
}
_G[addonName .. "_Debug"] = Debug

-- Function to handle debug messages
function Debug:Log(module, message, ...)
    if not BankMailDB or not BankMailDB.debugMode then return end
    
    -- Format additional args if provided
    local formattedMessage = message
    if ... then
        formattedMessage = string.format(message, ...)
    end
    
    -- Print with module prefix
    print("BankMail [" .. module .. "]: " .. formattedMessage)
end

-- Helper to create a module-specific debug function
function Debug:CreateDebugger(moduleName)
    return function(message, ...)
        self:Log(moduleName, message, ...)
    end
end

-- Initialize module
function Debug:Init()
    if self.initialized then
        self:Log("Debug", "Already initialized")
        return
    end

    self.initialized = true
    self:Log("Debug", "Initialization complete")
end

return Debug