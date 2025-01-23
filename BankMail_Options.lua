-- BankMail_Options.lua
print("Loading Options, BankMailDB exists:", BankMailDB ~= nil)

local addonName = "BankMail"
local Options = {
    Panel = CreateFrame("Frame")
}
_G[addonName .. "_Options"] = Options

local panel = Options.Panel
panel.name = "BankMail"
panel:Hide()

local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
Options.Category = category

-- Add function to set account-wide default recipient
function Options.SetAccountDefaultRecipient(recipient)
    if not recipient then return nil end

    -- Only modify the recipient if it explicitly includes a realm
    if recipient:find("-") then
        -- Recipient already has realm specification, use as-is
        BankMailDB.accountDefaultRecipient = recipient
    else
        -- Store just the character name
        BankMailDB.accountDefaultRecipient = recipient
    end
    print("BankMail: Account-wide default recipient set to: " .. recipient)
    return BankMailDB.accountDefaultRecipient
end

-- Counter for unique checkbox names
local checkCounter = 0

local function checkbox(label, description, onclick)
    local check = CreateFrame(
        "CheckButton",
        "BankMailOptCheck" .. checkCounter,
        panel,
        "InterfaceOptionsCheckButtonTemplate"
    )
    check:SetScript("OnClick", function(self)
        local checked = self:GetChecked()
        PlaySound(checked and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
        onclick(self, checked and true or false)
    end)
    check.label = _G[check:GetName() .. "Text"]
    check.label:SetText(label)
    check.tooltipText = label
    check.tooltipRequirement = description
    checkCounter = checkCounter + 1
    return check
end

function Options.Show(self)
    -- Create or get existing elements
    if not self.initialized then
        local title = self:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", 16, -16)
        title:SetText("BankMail Options")

        -- Enable/Disable checkbox
        local enableAddon = checkbox("Enable BankMail",
            "Enable or disable automatic mail tab switching",
            function(_, checked)
                BankMailDB.enabled = checked
                print("BankMail: " .. (checked and "Enabled" or "Disabled"))
            end)
        enableAddon:SetPoint("TOPLEFT", title, "BOTTOMLEFT", -2, -16)

        -- Bank Character label and input
        local bankCharLabel = self:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        bankCharLabel:SetPoint("TOPLEFT", enableAddon, "BOTTOMLEFT", 2, -8)
        bankCharLabel:SetTextColor(1, 1, 1)
        bankCharLabel:SetText("Default Bank Character (press enter to apply)")

        local bankCharInput = CreateFrame("EditBox", "BankMailOptBankChar", self)
        bankCharInput:SetSize(150, 22)
        bankCharInput:SetPoint("TOPLEFT", bankCharLabel, "BOTTOMLEFT", 2, -8)
        bankCharInput:SetFontObject("GameFontHighlight")
        bankCharInput:SetAutoFocus(false)
        bankCharInput:EnableMouse(true)

        local bg = bankCharInput:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.03, 0.03, 0.03, 0.75)

        -- Setup autocomplete
        bankCharInput:SetHyperlinksEnabled(false)
        bankCharInput:EnableMouse(true)
        bankCharInput:SetAutoFocus(false)
        bankCharInput:SetScript("OnTabPressed", function(self)
            AutoCompleteEditBox_OnTabPressed(self)
        end)
        bankCharInput:SetScript("OnChar", function(self, char)
            AutoCompleteEditBox_OnChar(self, char)
        end)
        bankCharInput:SetScript("OnTextChanged", function(self, userInput)
            AutoCompleteEditBox_OnTextChanged(self, userInput)
        end)
        bankCharInput:SetScript("OnEditFocusLost", function(self)
            AutoCompleteEditBox_OnEditFocusLost(self)
            self:HighlightText(0, 0)
        end)
        bankCharInput:SetScript("OnEditFocusGained", function(self)
            self:HighlightText()
        end)
        bankCharInput:SetScript("OnEnterPressed", function(self)
            local value = self:GetText()
            if value and value ~= "" then
                local fullRecipient = Options.SetAccountDefaultRecipient(value)
                self:SetText(fullRecipient) -- Update with full name
            end
            self:ClearFocus()
        end)
        bankCharInput:SetScript("OnEscapePressed", function(self)
            self:SetText(BankMailDB.accountDefaultRecipient or "")
            self:ClearFocus()
        end)

        -- Add debug functions
        local function OnAutoComplete(self, text, fullText, multipleMatches)
            if BankMailDB and BankMailDB.debugMode then
                print("BankMail Debug: Autocomplete triggered")
                print("Text:", text)
                print("Full Text:", fullText)
                print("Multiple Matches:", multipleMatches)
            end
        end

        bankCharInput.autoCompleteCallback = OnAutoComplete
        bankCharInput.autoCompleteParams = AUTOCOMPLETE_LIST.MAIL
        bankCharInput.autoCompleteFunction = GetAutoCompleteResults
        AutoCompleteEditBox_SetAutoCompleteSource(bankCharInput, GetAutoCompleteResults, bankCharInput
            .autoCompleteParams)
        bankCharInput:SetScript("OnTabPressed", AutoCompleteEditBox_OnTabPressed)
        bankCharInput:SetScript("OnTextChanged", AutoCompleteEditBox_OnTextChanged)
        bankCharInput:SetScript("OnEditFocusLost", AutoCompleteEditBox_OnEditFocusLost)
        bankCharInput:SetScript("OnEscapePressed", function(self)
            self:SetText(BankMailDB.accountDefaultRecipient or "")
            self:ClearFocus()
        end)
        bankCharInput:SetScript("OnEnterPressed", function(self)
            local value = self:GetText()
            if value and value ~= "" then
                local fullRecipient = Options.SetAccountDefaultRecipient(value)
                self:SetText(fullRecipient) -- Update with full name including realm
            end
            self:ClearFocus()
        end)

        self.bankCharInput = bankCharInput
        self.enableAddon = enableAddon

        -- Add remaining checkboxes...
        local enableAutoSwitch = checkbox("Enable Auto-Switch on Bank Character",
            "Enable automatic tab switching when on the bank character",
            function(_, checked)
                if not BankMailDB then BankMailDB = {} end
                BankMailDB.enableAutoSwitchOnBank = checked
                print("BankMail: Auto-switch for bank character " .. (checked and "enabled" or "disabled"))
            end)
        enableAutoSwitch:SetPoint("TOPLEFT", bankCharInput, "BOTTOMLEFT", -2, -8)

        local enableCoinSubject = checkbox("Enable Coin Subject Auto-fill",
            "Enable automatic subject filling when attaching money",
            function(_, checked)
                if not BankMailDB then BankMailDB = {} end
                BankMailDB.enableCoinSubject = checked
                print("BankMail: Coin subject auto-fill " .. (checked and "enabled" or "disabled"))
            end)
        enableCoinSubject:SetPoint("TOPLEFT", enableAutoSwitch, "BOTTOMLEFT", 0, -8)

        local debugMode = checkbox("Debug Mode",
            "Enable debug logging",
            function(_, checked)
                if not BankMailDB then BankMailDB = {} end
                BankMailDB.debugMode = checked
                print("BankMail: Debug mode " .. (checked and "enabled" or "disabled"))
            end)
        debugMode:SetPoint("TOPLEFT", enableCoinSubject, "BOTTOMLEFT", 0, -8)

        self.enableAutoSwitch = enableAutoSwitch
        self.enableCoinSubject = enableCoinSubject
        self.debugMode = debugMode
        self.initialized = true
    end

    -- Update values
    if not BankMailDB then BankMailDB = {} end
    -- Initialize with defaults if not set
    if BankMailDB.enabled == nil then BankMailDB.enabled = true end
    if BankMailDB.enableAutoSwitchOnBank == nil then BankMailDB.enableAutoSwitchOnBank = false end
    if BankMailDB.enableCoinSubject == nil then BankMailDB.enableCoinSubject = true end
    if BankMailDB.debugMode == nil then BankMailDB.debugMode = false end

    -- Update UI to match current values
    self.enableAddon:SetChecked(BankMailDB.enabled)
    self.bankCharInput:SetText(BankMailDB.accountDefaultRecipient or "")
    self.enableAutoSwitch:SetChecked(BankMailDB.enableAutoSwitchOnBank)
    self.enableCoinSubject:SetChecked(BankMailDB.enableCoinSubject)
    self.debugMode:SetChecked(BankMailDB.debugMode)
end

panel:SetScript("OnShow", function(self)
    Options.Show(self)
end)

Settings.RegisterAddOnCategory(category)

return Options
