# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [0.5.3] 2022-02-09

### Changed

Changed warning message, when connecting with ExO v2 module failed.

## [0.5.2] 2021-12-31

### Changed

Moved script to Github

## [0.5.1] 2021-06-01

### Changed

- renamed parameter _-UseMfa_ to _-Interactive_
- When providing password, MSOnline connection doesn't use interactive logon.

## [0.5.0] 2021-06-01

### Added

- Added support for using accounts with MFA
- Added support for using accounts from partner tenant

### Changed

- Exchange connection loading can be now suppressed.

## [0.4.0] 2021-06-01

### Removed

- Skype for Business module loading.

## [0.3.1] 2021-06-01

### Changed

- ExO module is also loaded in PowerShell 7.
- Connect to Security & Compliance Center with ExO module, if possible.

## [0.3.0] 2020-09-03

### Added

- Added code that skips loading incompatible modules in PowerShell 7
- Added loading EXO v2 module, if present.

## [0.2.2] 2020-04-21

### Changed

- Raised PowerShell version requirement to 5.1
- Corrected warning, when Teams module not present

## [0.2.1] 2020-02-18

### Added

- validated values for -AdModule parameter

### Changed

- Imported PSSession output is now hidden.
- Initial domain detection, when using MSOnline module.

## [0.2.0] 2020-02-18

### Added

- -All parameter to connect all available services
- delegated partner support for Exchange

### Changed

- renamed -EOP (Exchange Online Protection) to -CC (Security & Compliance Center)

## [0.1.7] 2020-02-18

### Added

- Skype for Business connection
- Teams connection
- if -AdModule is not specified, both MSOnline and AzureAD is assumed.

### Changed

- renamed -EOP (Exchange Online Protection) to -CC (Security & Compliance Center)

## [0.1.6] 2020-02-18

### Added

- Sharepoint Online connection

## [0.1.5] 2020-02-17

Initial Release
