# HelloID-Conn-Prov-Source-SDBHR

> [!WARNING]
> This repository contains the connector and configuration code only. The implementer is responsible to acquire the connection details such as username, password, certificate, etc. You might even need to sign a contract or agreement with the supplier before implementing this connector. Please contact the client's application manager to coordinate the connector requirements.

<p align="center">
  <img src="https://github.com/Tools4everBV/HelloID-Conn-Prov-Source-SDBHR/blob/main/Logo.png">
</p> 

## Table of contents

- [HelloID-Conn-Prov-Source-SDBHR](#helloid-conn-prov-source-sdbhr)
  - [Table of contents](#table-of-contents)
  - [Introduction](#introduction)
  - [Supported features](#supported-features)
  - [Getting started](#getting-started)
    - [Requirements](#requirements)
    - [Connection settings](#connection-settings)
    - [Mapping](#mapping)
  - [Remarks](#remarks)
  - [Development resources](#development-resources)
    - [API endpoints](#api-endpoints)
    - [API documentation](#api-documentation)
  - [Getting help](#getting-help)
  - [HelloID Docs](#helloid-docs)

## Introduction

The SDB-HR connector is a source and provides a set of REST API's that allow you to programmatically interact with it's data.

## Supported features

The following features are available:

| Feature                | Supported | Remarks                                   |
| ---------------------- | --------- | ----------------------------------------- |
| **Persons import**     | ✅         | Retrieves the employees and the contracts |
| **Departments import** | ✅         | Retrieves the departments                 |

## Getting started

### Requirements

- A valid **API User** and **API Key** to authenticate with the SDB API.
- **Access** for the API User to the following **API endpoints**:
  - /api/medewerkersbasic (GET)
  - /api/dienstverbandenbasic (GET)
  - /api/dienstverbandperiodesbasic/periode/{jaar}/{maand} (GET)
  - /api/afdelingen (GET)

Note: both have to be created and configured by an SDB consultant.

### Connection settings

The following settings are required to connect to the API.

| Setting         | Description                                                                                         | Mandatory |
| --------------- | --------------------------------------------------------------------------------------------------- | --------- |
| ApiUser         | The UserName for the ApiUser that has rights to connect to the SDBHR API                            | Yes       |
| ApiKey          | The ApiKey to connect to the SDBHR API                                                              | Yes       |
| KlantNummer     | The number of the customer. Usually these are three-digit numbers                                   | Yes       |
| BaseUrl         | The BaseUrl to the SDBHR environment (e.g., https://api-<Customer>.sdbstart.nl)                     | Yes       |
| PastThreshold   | The amount of days a contract's end date can be in the past and still be included in the import     | Yes       |
| FutureThreshold | The amount of days a contract's start date can be in the future and still be included in the import | Yes       |

### Mapping

The field mapping can be imported by using the _mapping.json_ file.


## Remarks

**Multiple person objects per identity**  
- The employee dataset can contain **multiple person objects for a single identity**. There is **no unique identifier** that guarantees a single real person. Each person object includes one employment, which can result in **multiple persons in HelloID for the same individual**.

**Start and end date fields**  
- There are **two sets of start and end date fields**: one on the employment (dienstverband) and one on the contract. Be careful when mapping these fields. **By default**, the connector uses the **employment (dienstverband) dates**.

**Single contract per employment**  
- SDB endpoints return **only one single contract per employment**. This means that future changes (e.g., a new role effective next month) only appear on the day they become active and are not available beforehand (or after they were active).
- This is not ideal because historical and future contract data are missing. These are often needed to assign rights before or after an active contract.
- If **additional rights** are required (based on multiple active contracts), an extra employment must exist so rights can be assigned based on both employments.

**Threshold-based filtering**  
- This connector **only imports persons with a contract within the configured thresholds**, based on employment (dienstverband) dates. Adjust these thresholds if needed.

## Development resources

### API endpoints

The following endpoints are used by the connector

| Endpoint                                                     | Description                                                                                                                                                                                                   |
| ------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| /api/medewerkersbasic (GET)                                  | Retrieve all employees                                                                                                                                                                                        |
| /api/dienstverbandenbasic (GET)                              | Retrieve all employments. **Note:** This endpoint always returns the latest known values, which may include future changes (e.g., a new role effective next month) after a salary run.                        |
| /api/dienstverbandperiodesbasic/periode/{year}/{month} (GET) | Retrieve actual employment data for the specified period. This ensures the data reflects the real situation as of today, rather than future changes that are already processed in the latest employment data. |
| /api/afdelingen (GET)                                        | Retrieve all departments                                                                                                                                                                                      |
### API documentation

[https://api.sdbstart.nl/swagger/ui/index#Resources](https://api.sdbstart.nl/swagger/ui/index#Resources)

## Getting help

> _For  information on how to configure a HelloID PowerShell connector, please refer to our [documentation](https://docs.helloid.com/hc/en-us/articles/360012557600-Configure-a-custom-PowerShell-source-system) pages_

> _If you need help, feel free to ask questions on our [forum](https://forum.helloid.com)_

## HelloID Docs

The official HelloID documentation can be found at: https://docs.helloid.com/

