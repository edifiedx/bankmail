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

-- Sort options
Options.SORT_KEYS = {
    { text = "Name",    value = "name" },
    { text = "Age",     value = "daysLeft" },
    { text = "Quality", value = "quality" },
    { text = "Count",   value = "count" },
    { text = "Sender",  value = "sender" }
}

Options.SORT_DIRECTIONS = {
    { text = "Ascending",  value = true },
    { text = "Descending", value = false }
}

-- Function to create dropdown menu
local function CreateDropdown(parent, name, options, defaultValue, onSelect)
    local dropdown = CreateFrame("Frame", name, parent, "UIDropDownMenuTemplate")

    local function Initialize(self, level)
        local info = UIDropDownMenu_CreateInfo()
        for _, option in ipairs(options) do
            info.text = option.text
            info.value = option.value
            info.func = function()
                UIDropDownMenu_SetSelectedValue(dropdown, option.value)
                onSelect(option.value)
            end
            UIDropDownMenu_AddButton(info)
        end
    end

    UIDropDownMenu_Initialize(dropdown, Initialize)
    UIDropDownMenu_SetWidth(dropdown, 120)
    UIDropDownMenu_SetSelectedValue(dropdown, defaultValue)

    return dropdown
end

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

local function checkbox(label, description, tooltip, defaultValue, onclick)
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
    check:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(label, 1, 1, 1)
        GameTooltip:AddLine(description, nil, nil, nil, true)
        GameTooltip:AddLine(" ") -- Spacer
        GameTooltip:AddLine(tooltip, 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine(" ") -- Spacer
        GameTooltip:AddLine("Default: " .. (defaultValue and "Enabled" or "Disabled"), 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    check:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    check.label = _G[check:GetName() .. "Text"]
    check.label:SetText(label)
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
        local enableAddon = checkbox(
            "Enable BankMail",
            "Enable or disable all BankMail features",
            "When enabled, BankMail will provide automatic mail tab switching, recipient auto-fill, and other quality of life improvements for mail handling.",
            true, -- Default value
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

        -- Add tooltip to bank character input
        bankCharInput:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine("Default Bank Character", 1, 1, 1)
            GameTooltip:AddLine(
                "Set the character that will automatically be filled in as the recipient when sending mail.", nil, nil,
                nil,
                true)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(
                "You can specify a character from any realm by including the realm name (e.g., CharacterName-RealmName)",
                0.8,
                0.8, 0.8, true)
            GameTooltip:AddLine("If no realm is specified, your current realm will be used.", 0.8, 0.8, 0.8, true)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Default: None", 0.7, 0.7, 0.7)
            GameTooltip:Show()
        end)
        bankCharInput:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
        end)

        local bg = bankCharInput:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.03, 0.03, 0.03, 0.75)

        -- Create Default Sort Options section
        local sortOptionsLabel = self:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        sortOptionsLabel:SetPoint("TOPLEFT", bankCharInput, "BOTTOMLEFT", -2, -20)
        sortOptionsLabel:SetText("Default Search Sort Options")

        -- Create sort key dropdown
        local sortKeyLabel = self:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        sortKeyLabel:SetPoint("TOPLEFT", sortOptionsLabel, "BOTTOMLEFT", 2, -8)
        sortKeyLabel:SetText("Sort By")

        local sortKeyDropdown = CreateDropdown(
            self,
            "BankMailSortKeyDropdown",
            Options.SORT_KEYS,
            BankMailDB.defaultSort and BankMailDB.defaultSort.key or "daysLeft",
            function(value)
                if not BankMailDB.defaultSort then BankMailDB.defaultSort = {} end
                BankMailDB.defaultSort.key = value
                print("BankMail: Default sort key set to: " .. value)
            end
        )
        sortKeyDropdown:SetPoint("TOPLEFT", sortKeyLabel, "BOTTOMLEFT", -15, -2)

        -- Create sort direction dropdown
        local sortDirLabel = self:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        sortDirLabel:SetPoint("LEFT", sortKeyLabel, "RIGHT", 100, 0)
        sortDirLabel:SetText("Sort Direction")

        local sortDirDropdown = CreateDropdown(
            self,
            "BankMailSortDirDropdown",
            Options.SORT_DIRECTIONS,
            BankMailDB.defaultSort and BankMailDB.defaultSort.ascending or false,
            function(value)
                if not BankMailDB.defaultSort then BankMailDB.defaultSort = {} end
                BankMailDB.defaultSort.ascending = value
                print("BankMail: Default sort direction set to: " .. (value and "ascending" or "descending"))
            end
        )
        sortDirDropdown:SetPoint("TOPLEFT", sortDirLabel, "BOTTOMLEFT", -15, -2)

        -- Add tooltips for sort options
        local function AddDropdownTooltip(frame, title, description)
            frame:HookScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:AddLine(title, 1, 1, 1)
                GameTooltip:AddLine(description, nil, nil, nil, true)
                GameTooltip:Show()
            end)
            frame:HookScript("OnLeave", function(self)
                GameTooltip:Hide()
            end)
        end

        AddDropdownTooltip(sortKeyDropdown, "Default Sort Key",
            "Choose how your search results will be sorted by default.\n\nThis setting will be used whenever you open the search interface.")
        AddDropdownTooltip(sortDirDropdown, "Default Sort Direction",
            "Choose whether items should be sorted in ascending (A to Z, lowest to highest)\nor descending (Z to A, highest to lowest) order by default.")

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

        -- Add feature checkboxes
        local enableAutoSwitch = checkbox(
            "Enable Auto-Switch on Bank Character",
            "Enable automatic tab switching when on the bank character",
            "When enabled, BankMail will automatically switch to the Send Mail tab even when you're on your bank character.\n\nWhen disabled (default), your bank character won't automatically switch tabs when checking mail.",
            false, -- Default value
            function(_, checked)
                if not BankMailDB then BankMailDB = {} end
                BankMailDB.enableAutoSwitchOnBank = checked
                print("BankMail: Auto-switch for bank character " .. (checked and "enabled" or "disabled"))
            end)
        enableAutoSwitch:SetPoint("TOPLEFT", sortKeyDropdown, "BOTTOMLEFT", -2, -8)

        local enableCoinSubject = checkbox(
            "Enable Coin Subject Auto-fill",
            "Enable automatic subject filling when attaching money",
            "When enabled, BankMail will automatically set the mail subject when you attach money to a mail.\n\nThe subject will be set to:\n'coin: Xg Ys Zc' and will update as you adjust the amount.",
            true, -- Default value
            function(_, checked)
                if not BankMailDB then BankMailDB = {} end
                BankMailDB.enableCoinSubject = checked
                print("BankMail: Coin subject auto-fill " .. (checked and "enabled" or "disabled"))
            end)
        enableCoinSubject:SetPoint("TOPLEFT", enableAutoSwitch, "BOTTOMLEFT", 0, -8)

        -- Add Auto-Attach options
        local enableAutoAttach = checkbox(
            "Enable Auto-Attach",
            "Automatically attach BoE items when sending mail",
            "When enabled, BankMail will automatically attach unbound BoE items when the mail window opens and switches to send mode.",
            true, -- Default value
            function(_, checked)
                if not BankMailDB then BankMailDB = {} end
                BankMailDB.enableAutoAttach = checked
                print("BankMail: Auto-attach " .. (checked and "enabled" or "disabled"))
            end)
        enableAutoAttach:SetPoint("TOPLEFT", enableCoinSubject, "BOTTOMLEFT", 0, -8)
        self.enableAutoAttach = enableAutoAttach

        local enableAutoAttachmentDetails = checkbox(
            "Detailed Attachment Printing",
            "Show detailed list of attached items",
            "When enabled, BankMail will print a detailed list of items that were automatically attached.",
            true, -- Default value
            function(_, checked)
                if not BankMailDB then BankMailDB = {} end
                BankMailDB.enableAutoAttachmentDetails = checked
                print("BankMail: Detailed printing " .. (checked and "enabled" or "disabled"))
            end)
        enableAutoAttachmentDetails:SetPoint("TOPLEFT", enableAutoAttach, "BOTTOMLEFT", 0, -8)
        self.enableAutoAttachmentDetails = enableAutoAttachmentDetails

        local enableSearchAutoFocus = checkbox(
            "Enable Search Auto-focus",
            "Automatically focus the search box when opening mail",
            "When enabled, the search box will automatically gain focus when you open your mailbox.\n\nWhen disabled, you'll need to click the search box to start searching.",
            true,
            function(_, checked)
                BankMailDB.enableSearchAutoFocus = checked
                print("BankMail: Search auto-focus " .. (checked and "enabled" or "disabled"))
            end
        )
        enableSearchAutoFocus:SetPoint("TOPLEFT", enableAutoAttachmentDetails, "BOTTOMLEFT", 0, -8)
        self.enableSearchAutoFocus = enableSearchAutoFocus

        -- debug mode
        local debugMode = checkbox(
            "Debug Mode",
            "Enable debug logging",
            "When enabled, BankMail will print additional information to the chat window to help diagnose issues.\n\nThis should typically be left disabled unless you're troubleshooting a problem.",
            false, -- Default value
            function(_, checked)
                if not BankMailDB then BankMailDB = {} end
                BankMailDB.debugMode = checked
                print("BankMail: Debug mode " .. (checked and "enabled" or "disabled"))
            end)
        debugMode:SetPoint("TOPLEFT", enableSearchAutoFocus, "BOTTOMLEFT", 0, -8)

        -- Create Restore Defaults button
        local defaultsButton = CreateFrame("Button", nil, self, "UIPanelButtonTemplate")
        defaultsButton:SetText("Restore Defaults")
        defaultsButton:SetSize(120, 22)
        defaultsButton:SetPoint("TOPLEFT", debugMode, "BOTTOMLEFT", 0, -16)
        defaultsButton:SetScript("OnClick", function()
            -- Show confirmation dialog
            StaticPopupDialogs["BANKMAIL_RESET_DEFAULTS"] = {
                text = "Are you sure you want to reset all BankMail settings to their defaults?",
                button1 = "Yes",
                button2 = "No",
                OnAccept = function()
                    -- Reset to defaults
                    BankMailDB = {
                        enabled = true,
                        accountDefaultRecipient = nil,
                        characterRecipients = {},
                        debugMode = false,
                        enableAutoSwitchOnBank = false,
                        enableCoinSubject = true
                    }
                    -- Update UI
                    self.enableAddon:SetChecked(true)
                    self.bankCharInput:SetText("")
                    self.enableAutoSwitch:SetChecked(false)
                    self.enableCoinSubject:SetChecked(true)
                    self.debugMode:SetChecked(false)
                    print("BankMail: All settings have been reset to defaults")
                end,
                timeout = 0,
                whileDead = true,
                hideOnEscape = true,
                preferredIndex = 3
            }
            StaticPopup_Show("BANKMAIL_RESET_DEFAULTS")
        end)
        defaultsButton:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine("Restore Defaults", 1, 1, 1)
            GameTooltip:AddLine("Reset all BankMail settings to their default values.", nil, nil, nil, true)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("This will:", 0.8, 0.8, 0.8)
            GameTooltip:AddLine("- Enable the addon", 0.8, 0.8, 0.8)
            GameTooltip:AddLine("- Clear bank character", 0.8, 0.8, 0.8)
            GameTooltip:AddLine("- Disable auto-switch on bank", 0.8, 0.8, 0.8)
            GameTooltip:AddLine("- Enable coin subject auto-fill", 0.8, 0.8, 0.8)
            GameTooltip:AddLine("- Disable debug mode", 0.8, 0.8, 0.8)
            GameTooltip:Show()
        end)
        defaultsButton:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
        end)

        self.enableAutoSwitch = enableAutoSwitch
        self.enableCoinSubject = enableCoinSubject
        self.debugMode = debugMode
        self.initialized = true
    end

    -- Update values
    if not BankMailDB then BankMailDB = {} end
    -- Initialize with defaults if not set
    if not BankMailDB.defaultSort then
        BankMailDB.defaultSort = {
            key = "daysLeft",
            ascending = false
        }
    end
    if BankMailDB.enabled == nil then BankMailDB.enabled = true end
    if BankMailDB.enableAutoSwitchOnBank == nil then BankMailDB.enableAutoSwitchOnBank = false end
    if BankMailDB.enableCoinSubject == nil then BankMailDB.enableCoinSubject = true end
    if BankMailDB.debugMode == nil then BankMailDB.debugMode = false end
    if BankMailDB.enableAutoAttach == nil then BankMailDB.enableAutoAttach = true end
    if BankMailDB.enableAutoAttachmentDetails == nil then BankMailDB.enableAutoAttachmentDetails = true end
    if BankMailDB.enableSearchAutoFocus == nil then BankMailDB.enableSearchAutoFocus = true end

    -- Update UI to match current values
    self.enableAddon:SetChecked(BankMailDB.enabled)
    self.bankCharInput:SetText(BankMailDB.accountDefaultRecipient or "")
    self.enableAutoSwitch:SetChecked(BankMailDB.enableAutoSwitchOnBank)
    self.enableCoinSubject:SetChecked(BankMailDB.enableCoinSubject)
    self.enableAutoAttach:SetChecked(BankMailDB.enableAutoAttach)
    self.enableAutoAttachmentDetails:SetChecked(BankMailDB.enableAutoAttachmentDetails)
    self.enableSearchAutoFocus:SetChecked(BankMailDB.enableSearchAutoFocus)
    self.debugMode:SetChecked(BankMailDB.debugMode)
end

panel:SetScript("OnShow", function(self)
    Options.Show(self)
end)

Settings.RegisterAddOnCategory(category)

return Options
