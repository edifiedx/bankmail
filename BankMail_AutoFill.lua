-- Create the module
local addonName = "BankMail"
local AutoFill = {
    initialized = false
}
_G[addonName .. "_AutoFill"] = AutoFill

-- Local variables
local currentRealm = GetRealmName()
local currentChar = UnitName("player")

-- Function to get current character's full name
function AutoFill:GetCharacterKey()
    return currentChar .. "-" .. currentRealm
end

-- Function to get default recipient for current character
function AutoFill:GetDefaultRecipient()
    local charKey = self:GetCharacterKey()
    -- First check character-specific recipient
    if BankMailDB.characterRecipients[charKey] then
        return BankMailDB.characterRecipients[charKey]
    end
    -- Fall back to account-wide default
    return BankMailDB.accountDefaultRecipient
end

-- Helper function to check if current character is the bank character
local function IsCurrentCharacterBank()
    local currentCharKey = AutoFill:GetCharacterKey()
    local bankChar = BankMailDB.accountDefaultRecipient

    -- If bank character doesn't include realm, append current realm
    if bankChar and not bankChar:find("-") then
        bankChar = bankChar .. "-" .. currentRealm
    end

    return bankChar and currentCharKey == bankChar
end

-- Function to format money amount as text
local function FormatMoneyText(copper)
    if not copper or copper == 0 then return "0c" end

    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local remainingCopper = copper % 100

    local parts = {}
    if gold > 0 then table.insert(parts, gold .. "g") end
    if silver > 0 then table.insert(parts, silver .. "s") end
    if remainingCopper > 0 then table.insert(parts, remainingCopper .. "c") end

    return table.concat(parts, " ")
end

-- Function to auto-fill subject when money is attached
local function AutoFillMoneySubject()
    if not BankMailDB or not BankMailDB.enabled or BankMailDB.enableCoinSubject == false then return end

    local currentSubject = SendMailSubjectEditBox:GetText()
    -- Proceed if subject is empty or matches our coin format
    if currentSubject ~= "" and not currentSubject:match("^coin: .*[gsc]$") then return end

    local moneyAmount = MoneyInputFrame_GetCopper(SendMailMoney)
    if moneyAmount and moneyAmount > 0 then
        SendMailSubjectEditBox:SetText("coin: " .. FormatMoneyText(moneyAmount))
    end
end

-- Function to auto-fill recipient
function AutoFill:AutoFillRecipient()
    if not BankMailDB.enabled then return end

    local recipient = self:GetDefaultRecipient()
    if not recipient then return end

    local currentCharKey = self:GetCharacterKey()
    if not recipient:find("-") then
        recipient = recipient .. "-" .. currentRealm
    end

    if currentCharKey == recipient then
        if BankMailDB.debugMode then
            print("BankMail: Skipping autofill - recipient would be current character")
        end
        return
    end

    -- Check if we should disable auto-fill for bank character
    if not BankMailDB.enableAutoSwitchOnBank and IsCurrentCharacterBank() then
        if BankMailDB.debugMode then
            print("BankMail: Auto-fill disabled for bank character")
        end
        return
    end

    -- Only auto-fill if the recipient field is empty
    if SendMailNameEditBox and SendMailNameEditBox:GetText() == "" then
        local recipient = self:GetDefaultRecipient()
        if recipient then
            SendMailNameEditBox:SetText(recipient)
            -- Add delay before focusing subject box
            C_Timer.After(0.1, function()
                if SendMailSubjectEditBox then
                    SendMailSubjectEditBox:SetFocus()
                end
            end)
        end
    end
end

-- Initialize module
function AutoFill:Init()
    if self.initialized then
        print("BankMail AutoFill: Already initialized")
        return
    end

    -- Hook money input fields for subject autofill
    if SendMailMoneyGold then
        SendMailMoneyGold:HookScript("OnTextChanged", AutoFillMoneySubject)
    end
    if SendMailMoneySilver then
        SendMailMoneySilver:HookScript("OnTextChanged", AutoFillMoneySubject)
    end
    if SendMailMoneyCopper then
        SendMailMoneyCopper:HookScript("OnTextChanged", AutoFillMoneySubject)
    end

    -- Hook the mail tab for auto-fill
    if MailFrameTab2 then
        MailFrameTab2:HookScript("OnClick", function()
            C_Timer.After(0.1, function()
                AutoFill:AutoFillRecipient()
            end)
        end)
    end

    -- Hook the send mail button for auto-fill after sending
    if SendMailMailButton then
        SendMailMailButton:HookScript("OnClick", function()
            C_Timer.After(0.2, function()
                AutoFill:AutoFillRecipient()
            end)
        end)
    end

    if BankMailDB.debugMode then
        print("BankMail AutoFill: Initialized for", currentChar, "on", currentRealm)
    end

    self.initialized = true
end

return AutoFill
