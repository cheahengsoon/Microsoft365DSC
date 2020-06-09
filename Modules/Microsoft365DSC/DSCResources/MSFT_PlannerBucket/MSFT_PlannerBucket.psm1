function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [Parameter(Mandatory = $true)]
        [System.String]
        $PlanId,

        [Parameter()]
        [System.String]
        $BucketId,

        [Parameter()]
        [System.String]
        [ValidateSet("Present", "Absent")]
        $Ensure = 'Present',

        [Parameter()]
        [System.String]
        $ApplicationId,

        [Parameter()]
        [System.String]
        $TenantId,

        [Parameter()]
        [System.String]
        $CertificateThumbprint
    )
    Write-Verbose -Message "Getting configuration of Planner Bucket {$Name}"

    #region Telemetry
    $data = [System.Collections.Generic.Dictionary[[String], [String]]]::new()
    $data.Add("Resource", $MyInvocation.MyCommand.ModuleName)
    $data.Add("Method", $MyInvocation.MyCommand)
    Add-M365DSCTelemetryEvent -Data $data
    #endregion

    Connect-Graph -Scopes "Group.ReadWrite.All" | Out-Null

    if (-not [System.String]::IsNullOrEmpty($BucketId))
    {
        $bucket = Get-MGPlannerPlanBucket -PlannerPlanId $PlanId | Where-Object -FilterScript {$_.Id -eq $BucketId}
    }
    else
    {
        [Array]$bucket = Get-MGPlannerPlanBucket -PlannerPlanId $PlanId | Where-Object -FilterScript {$_.Name -eq $Name}

        if ($bucket.Length -gt 1)
        {
            throw "Multiple Buckets with Name {$Name} were found for Plan with ID {$PlanID}." + `
                " Please use the BucketId property to identify the exact bucket."
        }
    }

    if ($null -eq $bucket[0])
    {
        $results = @{
            Name                  = $Name
            PlanId                = $PlanId
            Ensure                = "Absent"
            ApplicationId         = $ApplicationId
            TenantID              = $TenantId
            CertificateThumbprint = $CertificateThumbprint
        }
        return $results
    }

    $results = @{
        Name                  = $Name
        PlanId                = $PlanId
        BucketId              = $bucket[0].Id
        Ensure                = "Present"
        ApplicationId         = $ApplicationId
        TenantID              = $TenantId
        CertificateThumbprint = $CertificateThumbprint
    }
    Write-Verbose -Message "Get-TargetResource Result: `n $(Convert-M365DscHashtableToString -Hashtable $results)"
    return $results
}

function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [Parameter(Mandatory = $true)]
        [System.String]
        $PlanId,

        [Parameter()]
        [System.String]
        $BucketId,

        [Parameter()]
        [System.String]
        [ValidateSet("Present", "Absent")]
        $Ensure = 'Present',

        [Parameter()]
        [System.String]
        $ApplicationId,

        [Parameter()]
        [System.String]
        $TenantId,

        [Parameter()]
        [System.String]
        $CertificateThumbprint
    )
    Write-Verbose -Message "Setting configuration of Planner Bucket {$Name}"

    #region Telemetry
    $data = [System.Collections.Generic.Dictionary[[String], [String]]]::new()
    $data.Add("Resource", $MyInvocation.MyCommand.ModuleName)
    $data.Add("Method", $MyInvocation.MyCommand)
    Add-M365DSCTelemetryEvent -Data $data
    #endregion

    Connect-Graph -Scopes "Group.ReadWrite.All" | Out-Null

    # If the BucketID is null, assume we are creating a new one no matter what;
    if ($null -eq $BucketId)
    {
        $results = @{
            Name                  = $Name
            PlanId                = $PlanId
            BucketId              = $BucketId
            Ensure                = "Absent"
            ApplicationId         = "ApplicationId"
            TenantId              = "TenantId"
            CertificateThumbprint = $CertificateThumbprint
        }
        return $results
    }

    $SetParams = $PSBoundParameters
    $currentValues = Get-TargetResource @PSBoundParameters
    $SetParams.Remove("ApplicationId") | Out-Null
    $SetParams.Remove("TenantId") | Out-Null
    $SetParams.Remove("CertificateThumbprint") | Out-Null
    $SetParams.Remove("Ensure") | Out-Null

    if ($Ensure -eq 'Present' -and $currentValues.Ensure -eq 'Absent')
    {
        Write-Verbose -Message "Planner Bucket {$Name} doesn't already exist. Creating it."
        New-MGPlannerBucket -Name $Name -PlanId $PlanId | Out-Null
    }
    elseif ($Ensure -eq 'Present' -and $currentValues.Ensure -eq 'Present')
    {
        Write-Verbose -Message "Planner Bucket {$Bucket} already exists, but is not in the " + `
            "Desired State. Updating it."
        $currentBucket = Get-MgPlannerPlanBucket -PlannerPlanId $PlanId | Where-Object -FilterScript {$_.Id -eq $BucketId}
        Update-MGPlannerPlan @SetParams
    }
    elseif ($Ensure -eq 'Absent' -and $currentValues.Ensure -eq 'Present')
    {
        Write-Verbose -Message "Planner Bucket {$Name} exists, but is should not. " + `
            "Removing it."
        # TODO - Implement when available in the MSGraph PowerShell SDK
    }
}

function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [Parameter(Mandatory = $true)]
        [System.String]
        $PlanId,

        [Parameter()]
        [System.String]
        $BucketId,

        [Parameter()]
        [System.String]
        [ValidateSet("Present", "Absent")]
        $Ensure = 'Present',

        [Parameter()]
        [System.String]
        $ApplicationId,

        [Parameter()]
        [System.String]
        $TenantId,

        [Parameter()]
        [System.String]
        $CertificateThumbprint
    )

    Write-Verbose -Message "Testing configuration of Planner Bucket {$Name}"

    $CurrentValues = Get-TargetResource @PSBoundParameters
    Write-Verbose -Message "Target Values: $(Convert-M365DscHashtableToString -Hashtable $PSBoundParameters)"

    $ValuesToCheck = $PSBoundParameters
    $ValuesToCheck.Remove('ApplicationId') | Out-Null
    $ValuesToCheck.Remove('TenantId') | Out-Null
    $ValuesToCheck.Remove('CertificateThumbprint') | Out-Null
    $TestResult = Test-Microsoft365DSCParameterState -CurrentValues $CurrentValues `
        -Source $($MyInvocation.MyCommand.Source) `
        -DesiredValues $PSBoundParameters `
        -ValuesToCheck $ValuesToCheck.Keys

    Write-Verbose -Message "Test-TargetResource returned $TestResult"

    return $TestResult
}

function Export-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.String])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $ApplicationId,

        [Parameter(Mandatory = $true)]
        [System.String]
        $TenantId,

        [Parameter(Mandatory = $true)]
        [System.String]
        $CertificateThumbprint
    )
    $InformationPreference = 'Continue'

    #region Telemetry
    $data = [System.Collections.Generic.Dictionary[[String], [String]]]::new()
    $data.Add("Resource", $MyInvocation.MyCommand.ModuleName)
    $data.Add("Method", $MyInvocation.MyCommand)
    Add-M365DSCTelemetryEvent -Data $data
    #endregion

    $ConnectionMode = New-M365DSCConnection -Platform 'AzureAD' `
        -InboundParameters $PSBoundParameters

    [array]$groups = Get-AzureADGroup -All:$true

    $ConnectionMode = Connect-Graph -Scopes "Group.ReadWrite.All"
    $i = 1
    $content = ''
    foreach ($group in $groups)
    {
        Write-Information "    [$i/$($groups.Length)] $($group.DisplayName) - {$($group.ObjectID)}"
        try
        {
            [Array]$plans = Get-MgGroupPlannerPlan -GroupId $group.ObjectId -ErrorAction 'SilentlyContinue'

            $j = 1
            foreach ($plan in $plans)
            {
                Write-Information "        [$j/$($plans.Length)] $($plan.Title)"
                $buckets = Get-MGPlannerPlanBucket -PlannerPlanId $plan.Id
                $k = 1
                foreach ($bucket in $buckets)
                {
                    Write-Information "            [$k/$($buckets.Length)] $($bucket.Name)"
                    $params = @{
                        Name                  = $bucket.Name
                        PlanId                = $plan.Id
                        BucketId              = $Bucket.Id
                        ApplicationId         = $ApplicationId
                        TenantId              = $TenantId
                        CertificateThumbprint = $CertificateThumbprint
                    }
                    $result = Get-TargetResource @params
                    $content += "        PlannerBucket " + (New-GUID).ToString() + "`r`n"
                    $content += "        {`r`n"
                    $currentDSCBlock = Get-DSCBlock -Params $result -ModulePath $PSScriptRoot
                    $content += $currentDSCBlock
                    $content += "        }`r`n"
                    $k++
                }
                $j++
            }
            $i++
        }
        catch
        {
            Write-Verbose -Message $_
        }
    }
    return $content
}

Export-ModuleMember -Function *-TargetResource
