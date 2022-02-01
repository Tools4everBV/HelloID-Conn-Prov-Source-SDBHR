#####################################################
# HelloID-Conn-Prov-Source-SDBHR
#
# Version: 2.0.0.0
# Updated with filters to include only persons with contracts within thresholds and to output data record by record
#####################################################
$VerbosePreference = "Continue"

$config = $Configuration | ConvertFrom-Json

$ApiUser = $($config.ApiUser)
$ApiKey = $($config.ApiKey)
$KlantNummer = $($config.KlantNummer)
$BaseUrl = $($config.BaseUrl)
$PastThreshold = $($config.PastThreshold)
$FutureThreshold = $($config.FutureThreshold)

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

    Write-Verbose 'Retrieving employee data'
    $splatParams = @{
        Uri     = "$BaseUrl/api/MedewerkersBasic"
        Headers = $headers
    }
    $personsResponse = Invoke-SDBHRRestMethod @splatParams

    Write-Verbose 'Retrieving employments data'
    $employmentsList = [System.Collections.generic.List[object]]::new()
    $splatParams['Uri'] = "$BaseUrl/api/DienstverbandenBasic"
    $employmentsResponse = Invoke-SDBHRRestMethod @splatParams

    # Filter for employments within thresholds (default: active start date of maximum 3 months in futuru and end date of maximum 6 months in past)
    Write-Verbose "Found $($employmentsResponse.Count) employments. Filtering for employments within thresholds"
    $PastThresholdDate = Get-Date (Get-Date).AddMonths(-$PastThreshold)
    $FutureThresholdDate = Get-Date (Get-Date).AddMonths($FutureThreshold)
    foreach ($employment in $employmentsResponse) {
        $startDate = if (![String]::IsNullOrEmpty($employment.DatumInDienst)) { [datetime]$employment.DatumInDienst } else { $employment.DatumInDienst }
        $endDate = if (![String]::IsNullOrEmpty($employment.DatumUitDienst)) { [datetime]$employment.DatumUitDienst } else { $employment.DatumUitDienst }
        if ( $startDate -le $FutureThresholdDate -and ($endDate -ge $PastThresholdDate -or [String]::IsNullOrEmpty($endDate)) ) {
            $null = $employmentsList.Add($employment)
        }
    }
    Write-Verbose "Filtered down to $($employmentsList.Count) employments"

    $employmentsList = $employmentsList | Select-Object *, @{name = 'ExternalId'; expression = { $_.Id } }
    $employmentsGrouped = $employmentsList | Group-Object PersoneelsNummer -AsString -AsHashTable


    Write-Verbose "Found $($personsResponse.Count) employees. Filtering for employees with contracts within thresholds and creating list of employees to return"
    $returnPersons = [System.Collections.generic.List[object]]::new()
    foreach ($person in $personsResponse) {
        $person | Add-Member -MemberType NoteProperty -Name 'DisplayName' -Value "$($person.RoepNaam) $($person.AchterNaam)".trim(" ")
        $person | Add-Member -MemberType NoteProperty -Name 'ExternalId'  -Value $person.Id
        $person | Add-Member -MemberType NoteProperty -Name 'Contracts'   -Value $employmentsGrouped["$($person.Id)"]

        # Filter for employees with contracts
        if ($person.Contracts.Id.Count -ge 1) {
            $null = $returnPersons.Add($person)
            Write-Output $person | ConvertTo-Json -Depth 10
        }
        else {
            # Employee has no contracts within thresholds, not importing employee data
        }
    }
    Write-Verbose "Filtered down to $($returnPersons.Count) employees"
}
catch {
    throw $_
}