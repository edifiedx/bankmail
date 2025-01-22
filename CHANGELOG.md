# BankMail Changelog

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
