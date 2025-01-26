# BankMail Changelog

## [0.10.5] - (2025-01-26)

- Improved money collection categorization
- Added separate tracking for auction returns, cancellations, and purchases
- Enhanced tooltip clarity for different money sources

## [0.10.4] - (2025-01-25)

- Fixed an issue with command bindings

## [0.10.3] - (2025-01-24)

- Fixed an issue where the mail session was not properly closed
- Enhancements to mail session debugging

## [0.10.2] - (2025-01-24)

- Fixed an issue where mail session state was not properly tracked
- Fixed an issue where auto-switch behavior incorrectly triggered
- Auto-switch no longer incorrectly triggers when reading mail during an active mail session

## [0.10.1] - (2025-01-23)

- Added options panel option for coin subject autofill
- Enhanced options panel with detailed tooltips for all settings
- Added "Restore Defaults" button to options panel
- Renamed settings to use positive boolean names for clarity
- Fixed some options panel state persistence issues

## [0.10.0] - (2025-01-23)

- Added automatic subject line for mails with money attachments
- Money mails use format "coin: Xg Ys Zc"
- Subject updates automatically as money amounts change

## [0.9.3] - (2025-01-22)

- Fixed an issue where the options panel wouldn't open
- Added `/bank config` command to open panel directly

## [0.9.2] - (2025-01-22)

- Fixed an issue where the options panel wouldn't save

## [0.9.1] - (2025-01-22)

- Release workflow tweaks

## [0.9.0] - (2025-01-22)

- Added player support to coin collection
- Coin tooltip tweaks

## [0.8.2] - (2025-01-22)

- Removed deploy script from package

## [0.8.1] - (2025-01-22)

- Fixed an issue with autofill not triggering without AutoSwitch

## [0.8.0] - (2025-01-21)

- Extracted auto-switch functionality into new BankMail_AutoSwitch module
- Added debug logging for mail sessions and switch conditions
- Module initialization and dependency handling improvements
- Fixed timer cleanup when closing mail window
- Better character/realm data initialization
- Improved error handling for missing modules
- Recipient management handling in AutoSwitch module
- Updated TOC

## [0.7.0] - (2025-01-21)

- Fixed critical bug where addon settings weren't properly initializing for new users
- Removed unused right-click menu system in favor of the options panel
- Fixed character and realm detection
- Added safety checks to prevent errors when mail UI elements aren't fully loaded
- Improved timer handling to prevent conflicts when opening/closing mail
- Added delay when auto-focusing mail subject box to prevent autocomplete issues

## [0.6.0] - (2025-01-20)

- Initial GitHub release
- Added automatic tab switching for mail
- Added bank character configuration
- Added auction money collection feature
- Added options panel
