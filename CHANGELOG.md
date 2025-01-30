# BankMail Changelog

## [0.12.10] - (2025-01-30)

- Fixed an issue where right-clicking an item in search would not collect all matching items

## [0.12.9] - (2025-01-29)

- Enhanced search module state management:
  - Fixed inconsistent search behavior when clearing results
  - Added state persistence between mail frame sessions
  - Improved search clear button functionality
  - Fixed browse/hide button state consistency
  - Ensured search results always match current search text
  - Added proper state cleanup when closing mail frame

## [0.12.8] - (2025-01-29)

- Enhanced search results display:
  - Added quality-based colored borders for items
  - Added sender, subject, and days remaining to item tooltips
  - Increased maximum search results from 100 to 200

## [0.12.7] - (2025-01-29)

- Fixed an issue where money could not be collected with right-click

## [0.12.6] - (2025-01-28)

- Fixed an issue where auction house mail could cause UI elements to overlap
- Added improved handling of mail loading states
- Enhanced mail tab switching logic to be more reliable
- Added additional debug logging for mail state transitions

## [0.12.5] - (2025-01-28)

- Interface version update for 1.15.6

## [0.12.4] - (2025-01-27)

- Fixed an issue where search box focus could not be cleared
- Fixed Escape key behavior to properly clear focus before closing window
- Added option to control Search Auto-focus behavior
- Added debugging to focus state transitions

## [0.12.3] - (2025-01-27)

- Fixed an issue where search debug was ignoring debug setting

## [0.12.2] - (2025-01-27)

- Enhanced mail search functionality:
  - Added right-click support to take all stacks of the same item
  - Added auto-refresh when taking items from search results
  - Improved tooltip to show left/right click options
  - Added sorting to take items from oldest mail first
  - Fixed search results not updating after taking items

## [0.12.1] - (2025-01-27)

- Fixed an issue with search box Escape key behavior
- Now properly closes mailbox when search is empty

## [0.12.0] - (2025-01-27)

- Added inbox search functionality
  - Search bar for filtering items by name
  - Browse button to view all items in inbox
  - Grid view of searchable mail attachments
  - Direct item collection via click interface
  - Clear visual separation of search results
  - Instant search updates as you type
  - Search results maintain stack count display
  - Tooltip preview for all items

## [0.11.2] - (2025-01-26)

- Fixed an issue with "AutoAttach" button placement

## [0.11.1] - (2025-01-26)

- Fixed "Detailed Attachment Printing" option not saving correctly
- Improved options panel state management

## [0.11.0] - (2025-01-26)

- Added automatic BoE item attachment feature
  - Automatically attaches unbound BoE items when sending mail
  - New "Auto Attach" button in the mail window
  - Configurable via options panel
- Added detailed attachment printing option
  - Lists each item attached when enabled
  - Provides stack count information
- Added new options panel settings:
  - Enable Auto-Attach (default: on)
  - Detailed Attachment Printing (default: on)

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
