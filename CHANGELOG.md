# Change Log
All notable changes to this project will be documented in this file. The format is based on Keep a Changelog, and this project adheres to Semantic Versioning.

## [3.0.0] - 24-08-2026

### Changed
  - Make the use of periods `/api/dienstverbandperiodesbasic/periode` optional.

## [2.1.1] - 22-10-2025

### Added
- **GitHub workflows for automation:**
  - Added `.github/workflows/createRelease.yaml` to automate release creation based on CHANGELOG.md.
  - Added `.github/workflows/verifyChangelog.yaml` to enforce CHANGELOG.md updates on pull requests.

## [2.1.0] - 22-10-2025

### Added
- **Actual employment data retrieval:**
  - persons.ps1 now retrieves employment data for the current period, ensuring imported data reflects the real situation as of today, not just the latest values.
- **Property overwrite logic:**
  - Added logic to update employment properties from period data if they differ, improving data accuracy for rights assignment and mapping.
- **Expanded documentation:**
  - README.md restructured and expanded with clear warnings, supported features, API endpoint documentation, and mapping instructions.
- **Changelog introduced:**
  - Added this changelog file to document all notable changes, following Keep a Changelog format and Semantic Versioning.

### Changed
- **Threshold filtering:**
  - PastThreshold and FutureThreshold in configuration.json now use days instead of months for more precise contract filtering.
  - Updated default values to 180 days (past) and 90 days (future).
- **Logging and output:**
  - persons.ps1 now uses Write-Information for improved traceability and debugging.
- **README.md:**
  - Slight rewrite for clarity, completeness, and alignment with current connector logic.

### Fixed
- **Asset cleanup:**
  - Removed unused asset/logo.jpg.

## [2.0.1] - 17-04-2023

### Fixed
- **Departments script:**
  - Only sends specific object and no longer all available data.


## [2.0.0] - 01-02-2022

### Added
- **Threshold-based filtering:**
  - Added filters to only import persons with contracts within thresholds.


## [1.0.0] - 03-06-2021

This is the first official release of HelloID-Conn-Prov-Source-SDBHR.
