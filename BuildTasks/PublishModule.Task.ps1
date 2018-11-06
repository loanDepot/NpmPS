task PublishModule {

    if ( $ENV:BHBuildSystem -ne 'Unknown' -and
        $ENV:BHBranchName -eq "master" -and
        -not [string]::IsNullOrWhiteSpace($ENV:nugetapikey))
    {
        $publishModuleSplat = @{
            Path        = $Destination
            NuGetApiKey = $ENV:nugetapikey
            Verbose     = $true
            Force       = $true
            Repository  = $PSRepository
            ErrorAction = 'Stop'
        }
        "Files in module output:"
        Get-ChildItem $Destination -Recurse -File |
            Select-Object -Expand FullName

        if (Get-Command dotnet -ErrorAction Ignore)
        {
            "Dotnet version"
            dotnet --Version
        }
        else
        {
            "nuget version"
            nuget help | Select-First -First 1
        }

        "Publishing [$Destination] to [$PSRepository]"

        Publish-Module @publishModuleSplat

        $moduleSource = Get-PSRepository -Name PSGallery
        $Destination = $moduleSource.PublishLocation

        "Finding nupkg"
        $NupkgPath = Get-ChildItem -Recurse *.nupkg | % FullName
        "  [$NupkgPath]"

        $workingdirectory = Split-Path $NupkgPath
        $tempErrorFile = Join-Path $workingdirectory 'errorout.txt'
        $tempOutputFile = Join-Path $workingdirectory 'stdout.txt'

        "Manual Publish of package"
        $errorMsg = $null
        $outputMsg = $null
        $StartProcess_params = @{
            RedirectStandardError = $tempErrorFile
            RedirectStandardOutput = $tempOutputFile
            NoNewWindow = $true
            Wait = $true
            PassThru = $true
        }

        $StartProcess_params['FilePath'] = (Get-Command dotnet).Path

        $ArgumentList = @('nuget')
        $ArgumentList += 'push'
        $ArgumentList += "`"$NupkgPath`""
        $ArgumentList += @('--source', "`"$($Destination.TrimEnd('\'))`"")
        $ArgumentList += @('--api-key', "`"$env:NugetApiKey`"")
        $ArgumentList += @('-v','diag')

        $StartProcess_params['ArgumentList'] = $ArgumentList

        if($script:IsCoreCLR -and -not $script:IsNanoServer) {
            $StartProcess_params['WhatIf'] = $false
            $StartProcess_params['Confirm'] = $false
        }

        $process = Microsoft.PowerShell.Management\Start-Process @StartProcess_params

        if(Test-Path -Path $tempErrorFile -PathType Leaf) {
            $errorMsg = Microsoft.PowerShell.Management\Get-Content -Path $tempErrorFile -Raw

            if($errorMsg) {

                Write-Verbose -Message $tempErrorFile -Verbose:$true
                Write-Verbose -Message $errorMsg -Verbose:$true
            }
        }

        if(Test-Path -Path $tempOutputFile -PathType Leaf) {
            $outputMsg = Microsoft.PowerShell.Management\Get-Content -Path $tempOutputFile -Raw

            if($outputMsg) {
                Write-Verbose -Message $tempOutputFile -Verbose:$true
                Write-Verbose -Message $outputMsg -Verbose:$true
            }
        }
    }
    else
    {
        "Skipping deployment: To deploy, ensure that...`n" +
        "`t* You are in a known build system (Current: $ENV:BHBuildSystem)`n" +
        "`t* You are committing to the master branch (Current: $ENV:BHBranchName) `n" +
        "`t* The repository APIKey is defined in `$ENV:nugetapikey (Current: $(![string]::IsNullOrWhiteSpace($ENV:nugetapikey))) `n" +
        "`t* This is not a pull request"
    }
}
