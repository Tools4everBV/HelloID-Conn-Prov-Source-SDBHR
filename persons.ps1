#####################################################
# HelloID-Conn-Prov-Source-SDBHR
#
# Version: 1.0.0.0
#####################################################
$VerbosePreference = "Continue"

#region Functions functions
function Get-SDBHREmployeeData {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]
        $ApiUser,

        [Parameter(Mandatory)]
        [string]
        $ApiKey,

        [Parameter(Mandatory)]
        [string]
        $KlantNummer,

        [Parameter(Mandatory)]
        [string]
        $BaseUrl
    )

    try {
        $currentDateTime = (Get-Date).ToString("dd-MM-yyyy HH:mm:ss.fff")
        $hashedString = New-SDBHRCalculatedHash -ApiKey $ApiKey -KlantNummer $KlantNummer -CurrentDateTime $currentDateTime

        Write-Verbose 'Adding Authorization headers'
        $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
        $headers.Add("Content-Type", "application/json")
        $headers.Add("Timestamp", $currentDateTime)
        $headers.Add("Klantnummer", $klantnummer)
        $headers.Add("Authentication", "$($ApiUser):$($hashedString)")
        $headers.add("Api-Version", "2.0")

        Write-Verbose 'Retrieving employee data'
        $splatParams = @{
            Uri     = "$BaseUrl/api/MedewerkersBasic"
            Headers = $headers
        }
        $medewerkersResponse = Invoke-SDBHRRestMethod @splatParams


        Write-Verbose 'Retrieving employments data'
        $employmentsList = [System.Collections.generic.List[object]]::new()
        $splatParams['Uri'] = "$BaseUrl/api/DienstverbandenBasic"
        $employmentsResponse = Invoke-SDBHRRestMethod @splatParams
        $employmentsList.AddRange($employmentsResponse)
        $employmentsList = $employmentsList | Select-Object *, @{name = 'ExternalId'; expression = { $_.Id } }
        $employmentsGrouped = $employmentsList | Group-Object PersoneelsNummer -AsString -AsHashTable

        Write-Verbose 'Creating list of employees to return'
        $returnMedewerkers = [System.Collections.generic.List[object]]::new()
        foreach ($medewerker in $medewerkersResponse) {
            $medewerker | Add-Member -MemberType NoteProperty -Name 'DisplayName' -Value "$($medewerker.RoepNaam) $($medewerker.AchterNaam)".trim(" ")
            $medewerker | Add-Member -MemberType NoteProperty -Name 'ExternalId'  -Value $medewerker.Id
            $medewerker | Add-Member -MemberType NoteProperty -Name 'Contracts'   -Value $employmentsGrouped["$($medewerker.Id)"]
            $returnMedewerkers.Add($medewerker)
        }
        Write-Output $returnMedewerkers
    } catch {
        $PScmdlet.ThrowTerminatingError($_)
    }
}
#endregion Functions

#region Helper Functions
function New-SDBHRCalculatedHash {
    [CmdletBinding()]
    param (

        [Parameter(Mandatory)]
        [string]
        $ApiKey,

        [Parameter(Mandatory)]
        [string]
        $KlantNummer,

        [Parameter(Mandatory)]
        [string]
        $CurrentDateTime
    )

    try {
        Write-Verbose 'Calculating SDHBR hash'
        $baseString = "$($CurrentDateTime.Substring(0,10))|$($CurrentDateTime.Substring(11,12))|$KlantNummer"
        $key = [System.Text.Encoding]::UTF8.GetBytes($ApiKey)
        $hmac256 = [System.Security.Cryptography.HMACSHA256]::new()
        $hmac256.key = $key
        $hash = $hmac256.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($baseString))
        $hashedString = [System.Convert]::ToBase64String($hash)

        Write-Output $hashedString
    } catch {
        $PScmdlet.ThrowTerminatingError($_)
    }
}
function Invoke-SDBHRRestMethod {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Uri,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary]
        $Headers
    )

    process {
        try {
            Write-Verbose "Invoking command '$($MyInvocation.MyCommand)' to Uri '$Uri'"
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::tls12

            $splatRestMethodParameters = @{
                Uri         = $Uri
                Method      = 'Get'
                ContentType = 'application/json'
                Headers     = $Headers
            }
            Invoke-RestMethod @splatRestMethodParameters
        } catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}

function Resolve-HTTPError {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory,
            ValueFromPipeline
        )]
        [object]$ErrorObject
    )
    process {
        $HttpErrorObj = @{
            FullyQualifiedErrorId = $ErrorObject.FullyQualifiedErrorId
            InvocationInfo        = $ErrorObject.InvocationInfo.MyCommand
            TargetObject          = $ErrorObject.TargetObject.RequestUri
        }
        if ($ErrorObject.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') {
            $HttpErrorObj['ErrorMessage'] = $ErrorObject.ErrorDetails.Message
        } elseif ($ErrorObject.Exception.GetType().FullName -eq 'System.Net.WebException') {
            $stream = $ErrorObject.Exception.Response.GetResponseStream()
            $stream.Position = 0
            $streamReader = New-Object System.IO.StreamReader $Stream
            $errorResponse = $StreamReader.ReadToEnd()
            $HttpErrorObj['ErrorMessage'] = $errorResponse
        }
        Write-Output "'$($HttpErrorObj.ErrorMessage)', TargetObject: '$($HttpErrorObj.TargetObject), InvocationCommand: '$($HttpErrorObj.InvocationInfo)"
    }
}
#endregion Helper Functions

$connectionSettings = $Configuration | ConvertFrom-Json
$splatParams = @{
    ApiUser     = $($connectionSettings.ApiUser)
    ApiKey      = $($connectionSettings.ApiKey)
    KlantNummer = $($connectionSettings.KlantNummer)
    BaseUrl     = $($connectionSettings.BaseUrl)
}
$persons = Get-SDBHREmployeeData @splatParams
Write-Output $persons | ConvertTo-Json -Depth 10