#####################################################
# HelloID-Conn-Prov-Source-SDBHR
#
# Version: 2.1.0
# Updated with filters to include only persons with contracts within thresholds and to output data record by record
# Updated to retrieve actual employment data for current period instead of latest values
#####################################################
$VerbosePreference = "Continue"

$config = $Configuration | ConvertFrom-Json

$ApiUser = $($config.ApiUser)
$ApiKey = $($config.ApiKey)
$KlantNummer = $($config.KlantNummer)
$BaseUrl = $($config.BaseUrl)
$PastThreshold = $($config.PastThreshold)
$FutureThreshold = $($config.FutureThreshold)

# Define Properties to check on employment for period to overwrite on employment if different
$propertiesToCheckOnPeriodEmployment = @(
    'Afdeling',
    'Functie',
    'Kostensoort1',
    'Kostensoort2',
    'Kostensoort3',
    'Kostensoort4',
    'Kostenplaats1',
    'Kostenplaats2',
    'Kostenplaats3',
    'Kostenplaats4'
)

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
        Write-Information "Calculating SDHBR hash"
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
            # Write-Information "Invoking command '$($MyInvocation.MyCommand)' to Uri '$Uri'"
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::tls12

            $splatRestMethodParameters = @{
                Uri         = $Uri
                Method      = 'Get'
                ContentType = 'application/json'
                Headers     = $Headers
                Verbose     = $false
                ErrorAction = 'Stop'
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

    Write-Information "Adding Authorization headers"
    $headers = [System.Collections.Generic.Dictionary[[String], [String]]]::new()
    $headers.Add("Content-Type", "application/json")
    $headers.Add("Timestamp", $currentDateTime)
    $headers.Add("Klantnummer", $klantnummer)
    $headers.Add("Authentication", "$($ApiUser):$($hashedString)")
    $headers.add("Api-Version", "2.0")

    Write-Information "Retrieving employee data"
    $splatParams = @{
        Uri     = "$BaseUrl/api/MedewerkersBasic"
        Headers = $headers
    }
    $personsResponse = Invoke-SDBHRRestMethod @splatParams

    Write-Information "Retrieving employments data"
    $employmentsList = [System.Collections.generic.List[object]]::new()
    $splatParams['Uri'] = "$BaseUrl/api/DienstverbandenBasic"
    $employmentsResponse = Invoke-SDBHRRestMethod @splatParams
    Write-Information "Retrieved $($employmentsResponse.Count) employments"

    # Filter for employments within thresholds (default: active start date of maximum 3 months in futuru and end date of maximum 6 months in past)
    $PastThresholdDate = Get-Date (Get-Date).AddMonths(-$PastThreshold)
    $FutureThresholdDate = Get-Date (Get-Date).AddMonths($FutureThreshold)
    Write-Information "Filtering for employments within thresholds. Past threshold date: $($PastThresholdDate), Future threshold date: $($FutureThresholdDate)"
    foreach ($employment in $employmentsResponse) {
        $startDate = if (![String]::IsNullOrEmpty($employment.DatumInDienst)) { [datetime]$employment.DatumInDienst } else { $employment.DatumInDienst }
        $endDate = if (![String]::IsNullOrEmpty($employment.DatumUitDienst)) { [datetime]$employment.DatumUitDienst } else { $employment.DatumUitDienst }
        if ( $startDate -le $FutureThresholdDate -and ($endDate -ge $PastThresholdDate -or [String]::IsNullOrEmpty($endDate)) ) {
            $null = $employmentsList.Add($employment)
        }
    }
    Write-Information "Filtered down to $($employmentsList.Count) employments within thresholds"

    # Get employments for current period and overwrite employment data if it differs to get actual values as of today instead of the "latest values"
    $currentYear = (Get-Date).Year
    $currentMonth = (Get-Date).Month
    Write-Information "Retrieving employments data for period $($currentYear)/$($currentMonth)"
    $employmentsListPeriods = [System.Collections.generic.List[object]]::new()
    $splatParams['Uri'] = "$BaseUrl/api/dienstverbandperiodesbasic/periode/$($currentYear)/$($currentMonth)?api-version=2.0"
    $employmentsPeriodResponse = Invoke-SDBHRRestMethod @splatParams
    foreach ($employmentPeriod in $employmentsPeriodResponse) {
        $null = $employmentsListPeriods.Add($employmentPeriod)
    }

    # Group on DienstverbandId (to match to employments)
    $employmentsListPeriodsGrouped = $employmentsListPeriods | Group-Object DienstverbandId -AsString -AsHashTable

    Write-Information "Retrieved $($employmentsListPeriods.Count) employments for period $($currentYear)/$($currentMonth)"

    foreach ($employment in $employmentsList) {
        $employmentForPeriod = $employmentsListPeriodsGrouped["$($employment.Id)"]
        if ($null -ne $employmentForPeriod) {
            # Should always only result in a single employment for period, but just in case, select the first one
            $employmentForPeriod = $employmentForPeriod | Select-Object -First 1

            if (![string]::IsNullOrEmpty($employmentForPeriod)) {
                foreach ($property in $propertiesToCheckOnPeriodEmployment) {
                    # If property from employment for period is different than employment, use property from employment for period
                    if ( $employment.$property -ne $employmentForPeriod.$property) {
                        $employment.$property = $employmentForPeriod.$property
                    }
                }
            }
        }
        else {
            Write-Warning "No employment for period found for employment $($employment.Id)"
        }
    }

    $employmentsList = $employmentsList | Select-Object *, @{name = 'ExternalId'; expression = { $_.Id } }
    $employmentsGrouped = $employmentsList | Group-Object PersoneelsNummer -AsString -AsHashTable

    Write-Information "Importing persons with contracts within thresholds"
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
    Write-Information "Imported $($returnPersons.Count) persons with contracts within thresholds"
}
catch {
    throw $_
}