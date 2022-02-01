#####################################################
# HelloID-Conn-Prov-Source-SDBHR
#
# Version: 2.0.0.0
# Updated to output data record by record
#####################################################
$VerbosePreference = "Continue"

$config = $Configuration | ConvertFrom-Json

$ApiUser = $($config.ApiUser)
$ApiKey = $($config.ApiKey)
$KlantNummer = $($config.KlantNummer)
$BaseUrl = $($config.BaseUrl)

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
    }
    catch {
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
        }
        catch {
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
        }
        elseif ($ErrorObject.Exception.GetType().FullName -eq 'System.Net.WebException') {
            $stream = $ErrorObject.Exception.Response.GetResponseStream()
            $stream.Position = 0
            $streamReader = [System.IO.StreamReader]::new($Stream)
            $errorResponse = $StreamReader.ReadToEnd()
            $HttpErrorObj['ErrorMessage'] = $errorResponse
        }
        Write-Output "'$($HttpErrorObj.ErrorMessage)', TargetObject: '$($HttpErrorObj.TargetObject), InvocationCommand: '$($HttpErrorObj.InvocationInfo)"
    }
}
#endregion Helper Functions

try {
    $currentDateTime = (Get-Date).ToString("dd-MM-yyyy HH:mm:ss.fff")
    $hashedString = New-SDBHRCalculatedHash -ApiKey $ApiKey -KlantNummer $KlantNummer -CurrentDateTime $currentDateTime

    Write-Verbose 'Adding Authorization headers'
    $headers = [System.Collections.Generic.Dictionary[[String], [String]]]::new()
    $headers.Add("Content-Type", "application/json")
    $headers.Add("Timestamp", $currentDateTime)
    $headers.Add("Klantnummer", $klantnummer)
    $headers.Add("Authentication", "$($ApiUser):$($hashedString)")
    $headers.add("Api-Version", "2.0")


    Write-Verbose 'Retrieving departments data'
    $departmentsList = [System.Collections.generic.List[object]]::new()
    $splatParams = @{
        Uri     = "$BaseUrl/api/afdelingen"
        Headers = $headers
    }
    $departmentsResponse = Invoke-SDBHRRestMethod @splatParams
    $departmentsList.AddRange($departmentsResponse)
    Write-Verbose "Found $($departmentsResponse.Count) departments. Creating list of departments to return"

    $departmentsList = $departmentsList | Select-Object *, @{name = 'ExternalId'; expression = { $_.Code } }, @{name = 'DisplayName'; expression = { $_.Omschrijving } }
    foreach ($department in $departmentsList) {
        Write-Output $department | ConvertTo-Json -Depth 10
    }
}
catch {
    throw $_
}