# HelloID-Conn-Prov-Source-SDBHR

![Logo](asset\logo.jpg)

#####This connector is not yet tested on a Customer Production Environment!

## Table of contents

- [Introduction](#Introduction)
- [Getting started](#Getting-started)
  + [Connection settings](#Connection-settings)
  + [Remarks](#Remarks)
  + [Contents](#Contents)
- [Getting help](Getting-help)
- [Contributing](Contributing)
- [Code Contributors](Code-Contributors)

## Introduction

The SDB-HR connector is a source and provides a set of REST API's that allow you to programmatically interact with it's data. The HelloID connector uses the API endpoints in the table below.

| Endpoint     | Description |
| ------------ | ----------- |
| /MedewerkersBasic    | Contains the same information as the /Mederwerkers Endpoint, but does not include a BSN |
| /DienstverbandenBasic     |  Contains the same information as the /ienstverbanden Endpoint, but does not include a salary information |
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


### Remarks

- The employee data set can contain multiple person objects for a single identity. There is no identifier available that is identifiable to a single (real) person. And each person's object includes single employment.

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

