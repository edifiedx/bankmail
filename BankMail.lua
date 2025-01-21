-- Create the addon frame and register for events
local frame = CreateFrame("Frame")
frame:RegisterEvent("MAIL_CLOSED")
frame:RegisterEvent("MAIL_SHOW")
frame:RegisterEvent("MAIL_INBOX_UPDATE")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")

-- Addon name
local addonName = "BankMail"

local BankMail_Money = _G[addonName .. "_Money"]

-- Update default settings
local defaults = {
    enabled = true,
    accountDefaultRecipient = nil,
    characterRecipients = {},
    debugMode = false,
    disableAutoSwitchOnBank = true -- Default to true since it's likely desired behavior
}

local currentRealm
local currentChar
local mailLoadTimer = nil
local currentMailSession = false

-- Helper function to check if current character is the bank character
local function IsCurrentCharacterBank()
    local currentCharKey = GetCharacterKey()
    local bankChar = BankMailDB.accountDefaultRecipient

    -- If bank character doesn't include realm, append current realm
    if bankChar and not bankChar:find("-") then
        bankChar = bankChar .. "-" .. currentRealm
    end

    return bankChar and currentCharKey == bankChar
end

-- Function to get current character's full name
local function GetCharacterKey()
    return currentChar .. "-" .. currentRealm
end

-- Function to get default recipient for current character
local function GetDefaultRecipient()
    local charKey = GetCharacterKey()
    -- First check character-specific recipient
    if BankMailDB.characterRecipients[charKey] then
        return BankMailDB.characterRecipients[charKey]
    end
    -- Fall back to account-wide default
    return BankMailDB.accountDefaultRecipient
end

local function SetAccountDefaultRecipient(recipient)
    -- If recipient doesn't include a realm, append current realm
    if not recipient:find("-") then
        recipient = recipient .. "-" .. currentRealm
    end
    BankMailDB.accountDefaultRecipient = recipient
    print("BankMail: Account-wide default recipient set to: " .. recipient)
end

local function SetCharacterDefaultRecipient(recipient)
    local charKey = GetCharacterKey()
    BankMailDB.characterRecipients[charKey] = recipient
    print("BankMail: Character-specific default recipient for " .. charKey .. " set to: " .. recipient)
end

-- Function to check for unread mail
local function HasUnreadMail()
    local numItems = GetInboxNumItems()
    for i = 1, numItems do
        local _, _, _, _, _, _, _, _, wasRead = GetInboxHeaderInfo(i)
        if not wasRead then
            return true
        end
    end
    return false
end

-- CheckAndSwitchTab function
local function CheckAndSwitchTab()
    -- Validate requirements before proceeding
    if not BankMailDB or not BankMailDB.enabled then
        return
    end

    if not currentRealm or not currentChar then
        if BankMailDB.debugMode then
            print("BankMail: Missing character data, aborting tab switch")
        end
        return
    end

    if not MailFrame:IsVisible() then
        return
    end

    -- Cancel any pending timer
    if mailLoadTimer then
        mailLoadTimer:Cancel()
        mailLoadTimer = nil
    end

    -- Check if we should disable auto-switch for bank character
    if BankMailDB.disableAutoSwitchOnBank and IsCurrentCharacterBank() then
        if BankMailDB.debugMode then
            print("BankMail: Auto-switch disabled for bank character")
        end
        return
    end

    -- Set up new timer with error handling
    mailLoadTimer = C_Timer.NewTimer(0.3, function()
        if not MailFrame:IsVisible() then return end

        if not HasUnreadMail() then
            -- Ensure the UI elements exist before trying to use them
            if MailFrameTab2 and SendMailNameEditBox then
                MailFrameTab2:Click()

                -- Auto-fill recipient if one is set
                local recipient = GetDefaultRecipient()
                if recipient and SendMailNameEditBox:GetText() == "" then
                    SendMailNameEditBox:SetText(recipient)
                    -- Add delay before focusing subject box
                    C_Timer.After(0.1, function()
                        if SendMailSubjectEditBox then
                            SendMailSubjectEditBox:SetFocus()
                        end
                    end)
                end

                currentMailSession = true
            end
        end
        mailLoadTimer = nil
    end)
end

-- Update the StartMailLoad and FinishMailLoad functions
local function StartMailLoad()
    if BankMailDB.debugMode then
        print("BankMail: Starting mail load")
    end
    if mailLoadTimer then
        mailLoadTimer:Cancel()
        mailLoadTimer = nil
    end
end

local function FinishMailLoad()
    if BankMailDB.debugMode then
        print("BankMail: Finishing mail load")
        print("BankMail: Status:")
        print("BankMail: - Addon Enabled:", BankMailDB.enabled)
        print("BankMail: - Mail Frame Visible:", MailFrame:IsVisible())
        print("BankMail: - Has Unread Mail:", HasUnreadMail())
        print("BankMail: - Is Bank Character:", IsCurrentCharacterBank())
        print("BankMail: - Auto-switch Disabled for Bank:", BankMailDB.disableAutoSwitchOnBank)
    end
    CheckAndSwitchTab()
end

-- Slash command handler
local function HandleSlashCommand(msg)
    local command, arg = msg:match("^(%S*)%s*(.-)$")
    command = command:lower()

    if command == "toggle" then
        BankMailDB.enabled = not BankMailDB.enabled
        print("BankMail: " .. (BankMailDB.enabled and "Enabled" or "Disabled"))
    elseif command == "set" then
        if arg == "" then
            BankMailDB.accountDefaultRecipient = nil
            print("BankMail: Cleared account-wide default recipient")
        else
            SetAccountDefaultRecipient(arg)
        end
    elseif command == "setcharacter" or command == "sc" then
        if arg == "" then
            local charKey = GetCharacterKey()
            BankMailDB.characterRecipients[charKey] = nil
            print("BankMail: Cleared character-specific recipient")
        else
            SetCharacterDefaultRecipient(arg)
        end
    elseif command == "show" then
        local charKey = GetCharacterKey()
        local charRecipient = BankMailDB.characterRecipients[charKey]
        local accountRecipient = BankMailDB.accountDefaultRecipient
        local effectiveRecipient = GetDefaultRecipient()

        print("BankMail settings:")
        print("- Account default: " .. (accountRecipient or "none"))
        print("- Character default: " .. (charRecipient or "none"))
        print("- Currently using: " .. (effectiveRecipient or "none"))
    else
        print("BankMail commands:")
        print("/bank toggle - Enable/disable automatic tab switching")
        print("/bank set CharacterName - Set account-wide default recipient (use empty to clear)")
        print("/bank setcharacter CharacterName - Set character-specific default recipient (use empty to clear)")
        print("/bank show - Show current recipient settings")
    end
end

-- Register slash commands
SLASH_BANKMAIL1 = "/bankmail"
SLASH_BANKMAIL2 = "/bank"
SlashCmdList["BANKMAIL"] = HandleSlashCommand

-- Function to take all attachments from a mail
local function TakeAllAttachments(mailIndex)
    local hasItem = select(8, GetInboxHeaderInfo(mailIndex))
    if not hasItem then return end

    if BankMailDB.debugMode then
        print("BankMail: Starting mail", mailIndex)
    end

    -- First, scan the mail to know what we're dealing with
    local attachments = {}
    for i = 1, ATTACHMENTS_MAX_RECEIVE do
        local name, _, _, count = GetInboxItem(mailIndex, i)
        if name then
            table.insert(attachments, {
                slot = i,
                name = name,
                count = count or 0
            })
            if BankMailDB.debugMode then
                print(string.format("BankMail: Found slot %d: %s x%d", i, name, count or 0))
            end
        end
    end

    -- Take money if present
    local _, _, _, _, money = GetInboxHeaderInfo(mailIndex)
    if money and money > 0 then
        TakeInboxMoney(mailIndex)
    end

    -- Take items one at a time, waiting for confirmation
    local currentIndex = 1

    local function TakeNext()
        if currentIndex > #attachments then
            print("BankMail Debug: Finished taking all items")
            return
        end

        local item = attachments[currentIndex]
        print(string.format("Taking slot %d: %s x%d", item.slot, item.name, item.count))

        -- Take the item
        TakeInboxItem(mailIndex, item.slot)

        -- Wait for the MAIL_INBOX_UPDATE event before proceeding
        local function WaitForUpdate()
            -- Check if item was actually taken
            local newName = select(1, GetInboxItem(mailIndex, item.slot))
            if newName == item.name then
                -- Item still exists, wait a bit and try again
                C_Timer.After(0.3, WaitForUpdate)
            else
                -- Item was taken, move to next after a short delay
                currentIndex = currentIndex + 1
                C_Timer.After(0.3, TakeNext)
            end
        end

        -- Start waiting for update
        C_Timer.After(0.3, WaitForUpdate)
    end

    -- Start the process
    TakeNext()
end

-- Hook function for mail item buttons
local function HookInboxButtons()
    for i = 1, 7 do
        local button = _G["MailItem" .. i .. "Button"]
        if button then
            button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            button:HookScript("OnClick", function(self, buttonName)
                if buttonName == "RightButton" then
                    local mailIndex = self.index
                    if mailIndex then
                        TakeAllAttachments(mailIndex)
                    end
                end
                -- Left click retains default behavior
            end)
        end
    end
end

-- Event handler
-- Event handler with proper initialization and error handling
frame:SetScript("OnEvent", function(self, event, ...)
    local arg1 = ...

    if BankMailDB and BankMailDB.debugMode then
        print("BankMail: Event fired:", event)
    end

    -- Handle addon initialization
    if event == "ADDON_LOADED" and arg1 == addonName then
        -- Initialize database with defaults
        if not BankMailDB then
            BankMailDB = defaults
        else
            -- Merge any missing defaults while preserving existing settings
            for k, v in pairs(defaults) do
                if BankMailDB[k] == nil then
                    BankMailDB[k] = v
                end
            end
        end

        -- Initialize saved variables that might be nil
        BankMailDB.characterRecipients = BankMailDB.characterRecipients or {}

        if BankMailDB.debugMode then
            print("BankMail: Database initialized")
        end
    end

    -- Handle player login - initialize character data
    if event == "PLAYER_LOGIN" then
        -- Initialize character and realm data
        currentRealm = GetRealmName()
        currentChar = UnitName("player")

        if BankMailDB.debugMode then
            print("BankMail: Logged in as", currentChar, "on", currentRealm)
        end

        -- Initialize money module after character data is available
        if BankMail_Money and BankMail_Money.Init then
            BankMail_Money:Init()
        else
            print("BankMail: Warning - Money module not found")
        end
    end

    -- Handle mail window opening
    if event == "MAIL_SHOW" then
        if BankMailDB.debugMode then
            print("BankMail: Mail show - current session:", currentMailSession)
        end

        -- Ensure we have character data before proceeding
        if not currentRealm or not currentChar then
            currentRealm = GetRealmName()
            currentChar = UnitName("player")
        end

        -- Cancel any existing timer to prevent overlap
        if mailLoadTimer then
            mailLoadTimer:Cancel()
            mailLoadTimer = nil
        end

        -- Start mail load process
        StartMailLoad()

        -- Hook UI elements safely
        if not InboxFrame.bmHooked then
            HookInboxButtons()
            InboxFrame.bmHooked = true
        end
    end

    -- Handle mail inbox updates
    if event == "MAIL_INBOX_UPDATE" then
        -- Add a small delay to ensure mail data is fully loaded
        C_Timer.After(0.1, function()
            if MailFrame:IsVisible() then
                FinishMailLoad()
            end
        end)
    end

    -- Handle mail window closing
    if event == "MAIL_CLOSED" then
        if BankMailDB.debugMode then
            print("BankMail: Mail closed - resetting session")
        end

        -- Clean up timers
        if mailLoadTimer then
            mailLoadTimer:Cancel()
            mailLoadTimer = nil
        end

        -- Reset session state
        currentMailSession = false

        -- Clear any pending operations
        if isCollecting then
            isCollecting = false
        end
    end
end)
