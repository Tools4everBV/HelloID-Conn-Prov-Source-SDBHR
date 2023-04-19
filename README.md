# HelloID-Conn-Prov-Source-SDBHR

| :information_source: Information |
|:---------------------------|
| This repository contains the connector and configuration code only. The implementer is responsible to acquire the connection details such as username, password, certificate, etc. You might even need to sign a contract or agreement with the supplier before implementing this connector. Please contact the client's application manager to coordinate the connector requirements.       |

### Remarks

| ⚠️ Warning |
|:---------------------------|
| The employee data set can contain **multiple person objects for a single identity**. There is **no identifier** available that is identifiable to a single (real) person. And each person's object includes single employment. This can result in **multiple persons in HelloID for the same person** |
|There are **multiple (2) start and end date fields**, both on the employment (dienstverband) and the contract (contract), please be wary when selecting these in the mapping. **By default** we use the **date fields of the employment (dienstverband)**. |
| Currently, we only receive **one single contract per employment**, **this is always the latest contract!** from the SDB endpoints that we invoke. Because of this, in most situations we use the start and end date of the **employment**. <br/><br/> This is not the optimal situation (as we, Tools4ever are accustomed to), as we "normally" get the history and future contracts as well. <br/> This history and future data is needed so that we can optionally also assign rights prior to an active contract or just after. <br/><br/> For this reason it is also required that in the case where **double rights** are required (based on multiple active contracts), there is also an a **extra employment** and the rights can therefore be assigned based on both employments. |
| This connector (now) **only imports the persons with a contract within the threshold**, this also uses the date fields on the employment (dienstverband), please keep this in mind and change this accordingly if needed.       |

<br />

![Logo](asset/logo.jpg)

## Versioning
| Version | Description | Date |
| - | - | - |
| 2.0.1   | Hotfix for departments script: only send specific object and no longer all available data | 2023/04/17  |
| 2.0.0   | Added filters to only import persons with contracts within thresholds | 2022/02/01  |
| 1.0.0   | Initial release | 2021/06/03  |

## Table of contents

- [HelloID-Conn-Prov-Source-SDBHR](#helloid-conn-prov-source-sdbhr)
    - [Remarks](#remarks)
  - [Versioning](#versioning)
  - [Table of contents](#table-of-contents)
  - [Introduction](#introduction)
  - [Getting started](#getting-started)
    - [Connection settings](#connection-settings)
    - [Contents](#contents)
  - [Getting help](#getting-help)
  - [HelloID Docs](#helloid-docs)

## Introduction

The SDB-HR connector is a source and provides a set of REST API's that allow you to programmatically interact with it's data. The HelloID connector uses the API endpoints in the table below.

https://api.sdbstart.nl/swagger/ui/index#Resources

| Endpoint     | Description |
| ------------ | ----------- |
| /MedewerkersBasic    | Contains the same information as the /Mederwerkers Endpoint, but does not include a BSN |
| /DienstverbandenBasic     |  Contains the same information as the /Dienstverbanden Endpoint, but does not include a salary information |
| /afdelingen |     -        |


## Getting started

### Connection settings

The following settings are required to connect to the API.

| Setting     | Description |
| ------------ | ----------- |
| ApiUser     | The UserName for the ApiUser that has rights to connect to the SDBHR API   |
| ApiKey     | The ApiKey to connect to the SDBHR API  |
| KlantNummer    |   The number of the customer. Usually these are three digit numbers |
| BaseUrl | The BaseUrl to the SDBHR environment (https://api-<Customer>.sdbstart.nl)  |

### Contents

| Files       | Description                                |
| ----------- | ------------------------------------------ |
| Persons.ps1 | Retrieves the employees and the contracts                      |
| Department.ps1  | Retrieves the departments |

## Getting help

> _For  information on how to configure a HelloID PowerShell connector, please refer to our [documentation](https://docs.helloid.com/hc/en-us/articles/360012557600-Configure-a-custom-PowerShell-source-system) pages_

> _If you need help, feel free to ask questions on our [forum](https://forum.helloid.com)_

## HelloID Docs

The official HelloID documentation can be found at: https://docs.helloid.com/

