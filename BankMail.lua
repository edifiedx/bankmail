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
local BankMail_AutoSwitch = _G[addonName .. "_AutoSwitch"]
local BankMail_AutoAttach = _G[addonName .. "_AutoAttach"]
local BankMail_Options = _G[addonName .. "_Options"]

-- Update default settings
local defaults = {
    enabled = true,
    accountDefaultRecipient = nil,
    characterRecipients = {},
    debugMode = false,
    enableAutoSwitchOnBank = false,
    enableCoinSubject = true,
    enableAutoAttach = true,
    enableAutoAttachmentDetails = true

}

-- Function to set character-specific default recipient
local function SetCharacterDefaultRecipient(recipient)
    local charKey = BankMail_AutoSwitch:GetCharacterKey()
    BankMailDB.characterRecipients[charKey] = recipient
    print("BankMail: Character-specific default recipient for " .. charKey .. " set to: " .. recipient)
end

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

-- Slash command handler
local function HandleSlashCommand(msg)
    local command, arg = msg:match("^(%S*)%s*(.-)$")
    command = command:lower()

    if command == "config" or command == "options" then
        Settings.OpenToCategory(BankMail_Options.Category:GetID())
    elseif command == "toggle" then
        BankMailDB.enabled = not BankMailDB.enabled
        print("BankMail: " .. (BankMailDB.enabled and "Enabled" or "Disabled"))
    elseif command == "set" then
        if arg == "" then
            BankMailDB.accountDefaultRecipient = nil
            print("BankMail: Cleared account-wide default recipient")
        else
            BankMail_Options.SetAccountDefaultRecipient(arg)
        end
    elseif command == "setchar" or command == "sc" then
        if arg == "" then
            local charKey = BankMail_AutoSwitch:GetCharacterKey()
            BankMailDB.characterRecipients[charKey] = nil
            print("BankMail: Cleared character-specific recipient")
        else
            SetCharacterDefaultRecipient(arg)
        end
    elseif command == "show" then
        local charKey = BankMail_AutoSwitch:GetCharacterKey()
        local charRecipient = BankMailDB.characterRecipients[charKey]
        local accountRecipient = BankMailDB.accountDefaultRecipient
        local effectiveRecipient = BankMail_AutoSwitch:GetDefaultRecipient()

        print("BankMail settings:")
        print("- Account default: " .. (accountRecipient or "none"))
        print("- Character default: " .. (charRecipient or "none"))
        print("- Currently using: " .. (effectiveRecipient or "none"))
    else
        print("BankMail commands:")
        print("/bank toggle - Enable/disable automatic tab switching")
        print("/bank set <CharacterName> - Set account-wide default recipient (use empty to clear)")
        print("/bank setchar <CharacterName> - Set character-specific default recipient (use empty to clear)")
        print("/bank show - Show current recipient settings")
        print("/bank config - Shortcut to options panel")
    end
end

-- Register slash commands
SLASH_BANKMAIL1 = "/bankmail"
SLASH_BANKMAIL2 = "/bank"
SlashCmdList["BANKMAIL"] = HandleSlashCommand

-- Event handler
frame:SetScript("OnEvent", function(self, event, ...)
    local arg1 = ...
    -- if BankMailDB and BankMailDB.debugMode then
    --     print("BankMail: Event fired:", event, "arg1:", arg1 or "nil")
    -- end

    if BankMailDB and BankMailDB.debugMode and arg1 == addonName then
        print("BankMail: Event fired:", event, "arg1:", arg1 or "nil")
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

        if BankMail_AutoSwitch and BankMail_AutoSwitch.Init then
            BankMail_AutoSwitch:Init()
        else
            print("BankMail: Warning - AutoSwitch module not found")
        end
        if BankMail_AutoAttach and BankMail_AutoAttach.Init then
            BankMail_AutoAttach:Init()
        else
            print("BankMail: Warning - AutoAttach module not found")
        end
        if BankMail_Money and BankMail_Money.Init then
            BankMail_Money:Init()
        else
            print("BankMail: Warning - Money module not found")
        end
    end

    -- Handle mail window opening
    if event == "MAIL_SHOW" then
        if BankMailDB.debugMode then
            print("BankMail: Mail show - current session:", BankMail_AutoSwitch.currentMailSession)
        end

        -- Start mail load process
        BankMail_AutoSwitch:StartMailLoad()

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
                BankMail_AutoSwitch:FinishMailLoad()
            end
        end)
    end

    -- Handle mail window closing
    if event == "MAIL_CLOSED" then
        if BankMailDB and BankMailDB.debugMode then
            print("BankMail Debug: MAIL_CLOSED event triggered")
            if BankMail_AutoSwitch then
                local oldSession = BankMail_AutoSwitch.currentMailSession
                print("BankMail Debug: Current session state before reset:",
                    oldSession and date("[%I:%M:%S %p]", oldSession) or "nil")
            else
                print("BankMail Debug: AutoSwitch module not found!")
            end
        end

        -- Reset session state in auto-switch module
        if BankMail_AutoSwitch then
            BankMail_AutoSwitch.currentMailSession = nil

            if BankMailDB and BankMailDB.debugMode then
                print("BankMail Debug: Session reset complete. New state:",
                    BankMail_AutoSwitch.currentMailSession and
                    date("[%I:%M:%S %p]", BankMail_AutoSwitch.currentMailSession) or "nil")
            end
        end
    end
end)
