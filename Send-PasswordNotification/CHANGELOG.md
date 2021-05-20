# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [1.6.4] 2021-05-20

### Changed

- removed redundant `PasswordLastSet` property collected from AD
- change the way how version number obtained when no PowershellGet module
  present

## [1.6.3] 2021-03-11

### Fixed

- fixed version display

## [1.6.2] 2021-03-11

### Changed

- Now script uses AD user property `msDS-UserPasswordExpiryTimeComputed` to
  determine password expiration.

## [1.6.1] 2021-03-11

### Fixed

- Fixed filter that excludes users, whose password is already expired

## [1.6.0] 2021-02-16

### Added

- Possibility to use user account's manager e-mail address instead of user's.
  The setting (`useManagerMail`) is available in config file.

## [1.5.2] 2019-07-23

### Changed

- General comment cleanup
- published to Powershell Gallery

## [1.5.1] 2019-05-06

### Changed

- Changed Write-Debug with Max Password Age

## [1.5.0] 2019-04-30

### Added

- Added ability to limit user search based on OU

## [1.4.3] 2019-03-06

### Added

- added config file path checking
- established separate changelog

## [1.4.2] 2019-03-06

### Changed

- moved script to GitHub

## [1.4.1] 2014-09-06

- Initial release to Technet Script Gallery
