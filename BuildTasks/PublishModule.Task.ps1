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

        $script:DotnetCommandPath = (Get-Command dotnet).path

        $script:IsNanoServer = & {
            if (!$script:IsWindows)
            {
                return $false
            }

            $serverLevelsPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Server\ServerLevels\'
            if (Test-Path -Path $serverLevelsPath)
            {
                $NanoItem = Get-ItemProperty -Name NanoServer -Path $serverLevelsPath -ErrorAction Ignore
                if ($NanoItem -and ($NanoItem.NanoServer -eq 1))
                {
                    return $true
                }
            }
            return $false
        }

        $script:IsCoreCLR = $PSVersionTable.ContainsKey('PSEdition') -and $PSVersionTable.PSEdition -eq 'Core'

        $script:Includes    = "PSIncludes"
        $script:DscResource = "PSDscResource"
        $script:Command     = "PSCommand"
        $script:Cmdlet      = "PSCmdlet"
        $script:Function    = "PSFunction"
        $script:Workflow    = "PSWorkflow"
        $script:RoleCapability = 'PSRoleCapability'

        $script:PSGetFormatVersion = "PowerShellGetFormatVersion"
        $script:PSGetRequireLicenseAcceptanceFormatVersion = [Version]'2.0'
        $script:CurrentPSGetFormatVersion = $script:PSGetRequireLicenseAcceptanceFormatVersion
        $script:PSArtifactTypeModule = 'Module'
        $script:TempPath = [System.IO.Path]::GetTempPath()
        Publish-ModuleVerbose @publishModuleSplat

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

function Publish-ModuleVerbose
{
    <#
    .ExternalHelp PSModule-help.xml
    #>
    [CmdletBinding(SupportsShouldProcess=$true,
                   PositionalBinding=$false,
                   HelpUri='https://go.microsoft.com/fwlink/?LinkID=398575',
                   DefaultParameterSetName="ModuleNameParameterSet")]
    Param
    (
        [Parameter(Mandatory=$true,
                   ParameterSetName="ModuleNameParameterSet",
                   ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name,

        [Parameter(Mandatory=$true,
                   ParameterSetName="ModulePathParameterSet",
                   ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Path,

        [Parameter(ParameterSetName="ModuleNameParameterSet")]
        [ValidateNotNullOrEmpty()]
        [string]
        $RequiredVersion,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $NuGetApiKey,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $Repository = $Script:PSGalleryModuleSource,

        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [PSCredential]
        $Credential,

        [Parameter()]
        [ValidateSet("2.0")]
        [Version]
        $FormatVersion,

        [Parameter()]
        [string[]]
        $ReleaseNotes,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $Tags,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [Uri]
        $LicenseUri,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [Uri]
        $IconUri,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [Uri]
        $ProjectUri,

        [Parameter()]
        [switch]
        $Force,

        [Parameter(ParameterSetName="ModuleNameParameterSet")]
        [switch]
        $AllowPrerelease
    )

    Begin
    {
        Get-PSGalleryApiAvailability -Repository $Repository

        if($LicenseUri -and -not (Test-WebUri -uri $LicenseUri))
        {
            $message = $LocalizedData.InvalidWebUri -f ($LicenseUri, "LicenseUri")
            ThrowError -ExceptionName "System.ArgumentException" `
                        -ExceptionMessage $message `
                        -ErrorId "InvalidWebUri" `
                        -CallerPSCmdlet $PSCmdlet `
                        -ErrorCategory InvalidArgument `
                        -ExceptionObject $LicenseUri
        }

        if($IconUri -and -not (Test-WebUri -uri $IconUri))
        {
            $message = $LocalizedData.InvalidWebUri -f ($IconUri, "IconUri")
            ThrowError -ExceptionName "System.ArgumentException" `
                        -ExceptionMessage $message `
                        -ErrorId "InvalidWebUri" `
                        -CallerPSCmdlet $PSCmdlet `
                        -ErrorCategory InvalidArgument `
                        -ExceptionObject $IconUri
        }

        if($ProjectUri -and -not (Test-WebUri -uri $ProjectUri))
        {
            $message = $LocalizedData.InvalidWebUri -f ($ProjectUri, "ProjectUri")
            ThrowError -ExceptionName "System.ArgumentException" `
                        -ExceptionMessage $message `
                        -ErrorId "InvalidWebUri" `
                        -CallerPSCmdlet $PSCmdlet `
                        -ErrorCategory InvalidArgument `
                        -ExceptionObject $ProjectUri
        }

        Install-NuGetClientBinaries -CallerPSCmdlet $PSCmdlet -BootstrapNuGetExe -Force:$Force
    }

    Process
    {
        if($Repository -eq $Script:PSGalleryModuleSource)
        {
            $moduleSource = Get-PSRepository -Name $Repository -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
            if(-not $moduleSource)
            {
                $message = $LocalizedData.PSGalleryNotFound -f ($Repository)
                ThrowError -ExceptionName "System.ArgumentException" `
                           -ExceptionMessage $message `
                           -ErrorId 'PSGalleryNotFound' `
                           -CallerPSCmdlet $PSCmdlet `
                           -ErrorCategory InvalidArgument `
                           -ExceptionObject $Repository
                return
            }
        }
        else
        {
            $ev = $null
            $moduleSource = Get-PSRepository -Name $Repository -ErrorVariable ev
            if($ev) { return }
        }

        $DestinationLocation = $moduleSource.PublishLocation

        if(-not $DestinationLocation -or
           (-not (Microsoft.PowerShell.Management\Test-Path $DestinationLocation) -and
           -not (Test-WebUri -uri $DestinationLocation)))

        {
            $message = $LocalizedData.PSGalleryPublishLocationIsMissing -f ($Repository, $Repository)
            ThrowError -ExceptionName "System.ArgumentException" `
                        -ExceptionMessage $message `
                        -ErrorId "PSGalleryPublishLocationIsMissing" `
                        -CallerPSCmdlet $PSCmdlet `
                        -ErrorCategory InvalidArgument `
                        -ExceptionObject $Repository
        }

        $message = $LocalizedData.PublishLocation -f ($DestinationLocation)
        Write-Verbose -Message $message

        if(-not $NuGetApiKey.Trim())
        {
            if(Microsoft.PowerShell.Management\Test-Path -Path $DestinationLocation)
            {
                $NuGetApiKey = "$(Get-Random)"
            }
            else
            {
                $message = $LocalizedData.NuGetApiKeyIsRequiredForNuGetBasedGalleryService -f ($Repository, $DestinationLocation)
                ThrowError -ExceptionName "System.ArgumentException" `
                           -ExceptionMessage $message `
                           -ErrorId "NuGetApiKeyIsRequiredForNuGetBasedGalleryService" `
                           -CallerPSCmdlet $PSCmdlet `
                           -ErrorCategory InvalidArgument
            }
        }

        $providerName = Get-ProviderName -PSCustomObject $moduleSource
        if($providerName -ne $script:NuGetProviderName)
        {
            $message = $LocalizedData.PublishModuleSupportsOnlyNuGetBasedPublishLocations -f ($moduleSource.PublishLocation, $Repository, $Repository)
            ThrowError -ExceptionName "System.ArgumentException" `
                        -ExceptionMessage $message `
                        -ErrorId "PublishModuleSupportsOnlyNuGetBasedPublishLocations" `
                        -CallerPSCmdlet $PSCmdlet `
                        -ErrorCategory InvalidArgument `
                        -ExceptionObject $Repository
        }

        $moduleName = $null

        if($Name)
        {
            if ($RequiredVersion)
            {
                $ValidationResult = Validate-VersionParameters -CallerPSCmdlet $PSCmdlet `
                                                               -Name $Name `
                                                               -RequiredVersion $RequiredVersion `
                                                               -AllowPrerelease:$AllowPrerelease
                if(-not $ValidationResult)
                {
                    # Validate-VersionParameters throws the error.
                    # returning to avoid further execution when different values are specified for -ErrorAction parameter
                    return
                }

                $reqResult = ValidateAndGet-VersionPrereleaseStrings -Version $RequiredVersion -CallerPSCmdlet $PSCmdlet
                if (-not $reqResult)
                {
                    # ValidateAndGet-VersionPrereleaseStrings throws the error.
                    # returning to avoid further execution when different values are specified for -ErrorAction parameter
                    return
                }
                $reqVersion = $reqResult["Version"]
                $reqPrerelease = $reqResult["Prerelease"]
            }
            else
            {
                $reqVersion = $null
                $reqPrerelease = $null
            }

            # Find the module to be published locally, search by name and RequiredVersion
            $module = Microsoft.PowerShell.Core\Get-Module -ListAvailable -Name $Name -Verbose:$false |
                          Microsoft.PowerShell.Core\Where-Object {
                                $modInfoPrerelease = $null
                                if ($_.PrivateData -and
                                    $_.PrivateData.GetType().ToString() -eq "System.Collections.Hashtable" -and
                                    $_.PrivateData["PSData"] -and
                                    $_.PrivateData.PSData.GetType().ToString() -eq "System.Collections.Hashtable" -and
                                    $_.PrivateData.PSData["Prerelease"])
                                {
                                    $modInfoPrerelease = $_.PrivateData.PSData.Prerelease
                                }
                                (-not $RequiredVersion) -or ( ($reqVersion -eq $_.Version) -and ($reqPrerelease -match $modInfoPrerelease) )
                            }

            if(-not $module)
            {
                if($RequiredVersion)
                {
                    $message = $LocalizedData.ModuleWithRequiredVersionNotAvailableLocally -f ($Name, $RequiredVersion)
                }
                else
                {
                    $message = $LocalizedData.ModuleNotAvailableLocally -f ($Name)
                }

                ThrowError -ExceptionName "System.ArgumentException" `
                           -ExceptionMessage $message `
                           -ErrorId "ModuleNotAvailableLocallyToPublish" `
                           -CallerPSCmdlet $PSCmdlet `
                           -ErrorCategory InvalidArgument `
                           -ExceptionObject $Name

            }
            elseif($module.GetType().ToString() -ne "System.Management.Automation.PSModuleInfo")
            {
                $message = $LocalizedData.AmbiguousModuleName -f ($Name)
                ThrowError -ExceptionName "System.ArgumentException" `
                           -ExceptionMessage $message `
                           -ErrorId "AmbiguousModuleNameToPublish" `
                           -CallerPSCmdlet $PSCmdlet `
                           -ErrorCategory InvalidArgument `
                           -ExceptionObject $Name
            }

            $moduleName = $module.Name
            $Path = $module.ModuleBase
        }
        else
        {
            $resolvedPath = Resolve-PathHelper -Path $Path -CallerPSCmdlet $PSCmdlet | Microsoft.PowerShell.Utility\Select-Object -First 1 -ErrorAction Ignore

            if(-not $resolvedPath -or
               -not (Microsoft.PowerShell.Management\Test-Path -Path $resolvedPath -PathType Container))
            {
                ThrowError -ExceptionName "System.ArgumentException" `
                           -ExceptionMessage ($LocalizedData.PathIsNotADirectory -f ($Path)) `
                           -ErrorId "PathIsNotADirectory" `
                           -CallerPSCmdlet $PSCmdlet `
                           -ErrorCategory InvalidArgument `
                           -ExceptionObject $Path
                return
            }

            $moduleName = Microsoft.PowerShell.Management\Split-Path -Path $resolvedPath -Leaf
            $modulePathWithVersion = $false

            # if the Leaf of the $resolvedPath is a version, use its parent folder name as the module name
            [Version]$ModuleVersion = $null
            if([System.Version]::TryParse($moduleName, ([ref]$ModuleVersion)))
            {
                $moduleName = Microsoft.PowerShell.Management\Split-Path -Path (Microsoft.PowerShell.Management\Split-Path $resolvedPath -Parent) -Leaf
                $modulePathWithVersion = $true
            }

            $manifestPath = Join-PathUtility -Path $resolvedPath -ChildPath "$moduleName.psd1" -PathType File
            $module = $null

            if(Microsoft.PowerShell.Management\Test-Path -Path $manifestPath -PathType Leaf)
            {
                $ev = $null
                $module = Microsoft.PowerShell.Core\Test-ModuleManifest -Path $manifestPath `
                                                                        -ErrorVariable ev `
                                                                        -Verbose:$VerbosePreference
                if($ev)
                {
                    # Above Test-ModuleManifest cmdlet should write an errors to the Errors stream and Console.
                    return
                }
            }
            elseif(-not $modulePathWithVersion -and ($PSVersionTable.PSVersion -ge '5.0.0'))
            {
                $module = Microsoft.PowerShell.Core\Get-Module -Name $resolvedPath -ListAvailable -ErrorAction SilentlyContinue -Verbose:$false
            }

            if(-not $module)
            {
                $message = $LocalizedData.InvalidModulePathToPublish -f ($Path)

                ThrowError -ExceptionName "System.ArgumentException" `
                           -ExceptionMessage $message `
                           -ErrorId 'InvalidModulePathToPublish' `
                           -CallerPSCmdlet $PSCmdlet `
                           -ErrorCategory InvalidArgument `
                           -ExceptionObject $Path
            }
            elseif($module.GetType().ToString() -ne "System.Management.Automation.PSModuleInfo")
            {
                $message = $LocalizedData.AmbiguousModulePath -f ($Path)
                ThrowError -ExceptionName "System.ArgumentException" `
                           -ExceptionMessage $message `
                           -ErrorId 'AmbiguousModulePathToPublish' `
                           -CallerPSCmdlet $PSCmdlet `
                           -ErrorCategory InvalidArgument `
                           -ExceptionObject $Path
            }

            if($module -and (-not $module.Path.EndsWith('.psd1', [System.StringComparison]::OrdinalIgnoreCase)))
            {
                $message = $LocalizedData.InvalidModuleToPublish -f ($module.Name)
                ThrowError -ExceptionName "System.InvalidOperationException" `
                           -ExceptionMessage $message `
                           -ErrorId "InvalidModuleToPublish" `
                           -CallerPSCmdlet $PSCmdlet `
                           -ErrorCategory InvalidOperation `
                           -ExceptionObject $module.Name
            }

            $moduleName = $module.Name
            $Path = $module.ModuleBase
        }

        $message = $LocalizedData.PublishModuleLocation -f ($moduleName, $Path)
        Write-Verbose -Message $message

        #If users are providing tags using -Tags while running PS 5.0, will show warning messages
        if($Tags)
        {
            $message = $LocalizedData.TagsShouldBeIncludedInManifestFile -f ($moduleName, $Path)
            Write-Warning $message
        }

        if($ReleaseNotes)
        {
            $message = $LocalizedData.ReleaseNotesShouldBeIncludedInManifestFile -f ($moduleName, $Path)
            Write-Warning $message
        }

        if($LicenseUri)
        {
            $message = $LocalizedData.LicenseUriShouldBeIncludedInManifestFile -f ($moduleName, $Path)
            Write-Warning $message
        }

        if($IconUri)
        {
            $message = $LocalizedData.IconUriShouldBeIncludedInManifestFile -f ($moduleName, $Path)
            Write-Warning $message
        }

        if($ProjectUri)
        {
            $message = $LocalizedData.ProjectUriShouldBeIncludedInManifestFile -f ($moduleName, $Path)
            Write-Warning $message
        }


        # Copy the source module to temp location to publish
        $tempModulePath = Microsoft.PowerShell.Management\Join-Path -Path $script:TempPath `
                              -ChildPath "$(Microsoft.PowerShell.Utility\Get-Random)\$moduleName"


        if ($FormatVersion -eq "1.0")
        {
            $tempModulePathForFormatVersion = Microsoft.PowerShell.Management\Join-Path $tempModulePath "Content\Deployment\$script:ModuleReferences\$moduleName"
        }
        else
        {
            $tempModulePathForFormatVersion = $tempModulePath
        }

        $null = Microsoft.PowerShell.Management\New-Item -Path $tempModulePathForFormatVersion -ItemType Directory -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue -Confirm:$false -WhatIf:$false
        Microsoft.PowerShell.Management\Copy-Item -Path "$Path\*" -Destination $tempModulePathForFormatVersion -Force -Recurse -Confirm:$false -WhatIf:$false

        try
        {
            $manifestPath = Join-PathUtility -Path $tempModulePathForFormatVersion -ChildPath "$moduleName.psd1" -PathType File

            if(-not (Microsoft.PowerShell.Management\Test-Path $manifestPath))
            {
                $message = $LocalizedData.InvalidModuleToPublish -f ($moduleName)
                ThrowError -ExceptionName "System.InvalidOperationException" `
                           -ExceptionMessage $message `
                           -ErrorId "InvalidModuleToPublish" `
                           -CallerPSCmdlet $PSCmdlet `
                           -ErrorCategory InvalidOperation `
                           -ExceptionObject $moduleName
            }

            $ev = $null
            $moduleInfo = Microsoft.PowerShell.Core\Test-ModuleManifest -Path $manifestPath `
                                                                        -ErrorVariable ev `
                                                                        -Verbose:$VerbosePreference
            if($ev)
            {
                # Above Test-ModuleManifest cmdlet should write an errors to the Errors stream and Console.
                return
            }

            if(-not $moduleInfo -or
               -not $moduleInfo.Author -or
               -not $moduleInfo.Description)
            {
                $message = $LocalizedData.MissingRequiredManifestKeys -f ($moduleName)
                ThrowError -ExceptionName "System.InvalidOperationException" `
                           -ExceptionMessage $message `
                           -ErrorId "MissingRequiredModuleManifestKeys" `
                           -CallerPSCmdlet $PSCmdlet `
                           -ErrorCategory InvalidOperation `
                           -ExceptionObject $moduleName
            }

            # Validate Prerelease string
            $moduleInfoPrerelease = $null
            if ($moduleInfo.PrivateData -and
                $moduleInfo.PrivateData.GetType().ToString() -eq "System.Collections.Hashtable" -and
                $moduleInfo.PrivateData["PSData"] -and
                $moduleInfo.PrivateData.PSData.GetType().ToString() -eq "System.Collections.Hashtable" -and
                $moduleInfo.PrivateData.PSData["Prerelease"])
            {
                $moduleInfoPrerelease = $moduleInfo.PrivateData.PSData.Prerelease
            }

            $result = ValidateAndGet-VersionPrereleaseStrings -Version $moduleInfo.Version -Prerelease $moduleInfoPrerelease -CallerPSCmdlet $PSCmdlet
            if (-not $result)
            {
                # ValidateAndGet-VersionPrereleaseStrings throws the error.
                # returning to avoid further execution when different values are specified for -ErrorAction parameter
                return
            }
            $moduleInfoVersion = $result["Version"]
            $moduleInfoPrerelease = $result["Prerelease"]
            $moduleInfoFullVersion = $result["FullVersion"]

            $FindParameters = @{
                Name = $moduleName
                Repository = $Repository
                Tag = 'PSScript'
                AllowPrerelease = $true
                Verbose = $VerbosePreference
                ErrorAction = 'SilentlyContinue'
                WarningAction = 'SilentlyContinue'
                Debug = $DebugPreference
            }

            if($Credential)
            {
                $FindParameters[$script:Credential] = $Credential
            }

            # Check if the specified module name is already used for a script on the specified repository
            # Use Find-Script to check if that name is already used as scriptname
            $scriptPSGetItemInfo = Find-Script @FindParameters |
                                        Microsoft.PowerShell.Core\Where-Object {$_.Name -eq $moduleName} |
                                            Microsoft.PowerShell.Utility\Select-Object -Last 1 -ErrorAction Ignore
            if($scriptPSGetItemInfo)
            {
                $message = $LocalizedData.SpecifiedNameIsAlearyUsed -f ($moduleName, $Repository, 'Find-Script')
                ThrowError -ExceptionName "System.InvalidOperationException" `
                           -ExceptionMessage $message `
                           -ErrorId "SpecifiedNameIsAlearyUsed" `
                           -CallerPSCmdlet $PSCmdlet `
                           -ErrorCategory InvalidOperation `
                           -ExceptionObject $moduleName
            }

            $null = $FindParameters.Remove('Tag')
            $currentPSGetItemInfo = Find-Module @FindParameters |
                                        Microsoft.PowerShell.Core\Where-Object {$_.Name -eq $moduleInfo.Name} |
                                            Microsoft.PowerShell.Utility\Select-Object -Last 1 -ErrorAction Ignore

            if($currentPSGetItemInfo)
            {
                $result = ValidateAndGet-VersionPrereleaseStrings -Version $currentPSGetItemInfo.Version -CallerPSCmdlet $PSCmdlet
                if (-not $result)
                {
                    # ValidateAndGet-VersionPrereleaseStrings throws the error.
                    # returning to avoid further execution when different values are specified for -ErrorAction parameter
                    return
                }
                $currentPSGetItemVersion = $result["Version"]
                $currentPSGetItemPrereleaseString = $result["Prerelease"]
                $currentPSGetItemFullVersion = $result["FullVersion"]

                if($currentPSGetItemVersion -eq $moduleInfoVersion)
                {
                    # Compare Prerelease strings
                    if (-not $currentPSGetItemPrereleaseString -and -not $moduleInfoPrerelease)
                    {
                        $message = $LocalizedData.ModuleVersionIsAlreadyAvailableInTheGallery -f ($moduleInfo.Name, $moduleInfoFullVersion, $currentPSGetItemFullVersion, $currentPSGetItemInfo.RepositorySourceLocation)
                        ThrowError -ExceptionName 'System.InvalidOperationException' `
                                   -ExceptionMessage $message `
                                   -ErrorId 'ModuleVersionIsAlreadyAvailableInTheGallery' `
                                   -CallerPSCmdlet $PSCmdlet `
                                   -ErrorCategory InvalidOperation
                    }
                    elseif (-not $Force -and (-not $currentPSGetItemPrereleaseString -and $moduleInfoPrerelease))
                    {
                        # User is trying to publish a new Prerelease version AFTER publishing the stable version.
                        $message = $LocalizedData.ModuleVersionShouldBeGreaterThanGalleryVersion -f ($moduleInfo.Name, $moduleInfoFullVersion, $currentPSGetItemFullVersion, $currentPSGetItemInfo.RepositorySourceLocation)
                        ThrowError -ExceptionName "System.InvalidOperationException" `
                                   -ExceptionMessage $message `
                                   -ErrorId "ModuleVersionShouldBeGreaterThanGalleryVersion" `
                                   -CallerPSCmdlet $PSCmdlet `
                                   -ErrorCategory InvalidOperation
                    }

                    # elseif ($currentPSGetItemPrereleaseString -and -not $moduleInfoPrerelease) --> allow publish
                    # User is attempting to publish a stable version after publishing a Prerelease version (allowed).

                    elseif ($currentPSGetItemPrereleaseString -and $moduleInfoPrerelease)
                    {
                        if ($currentPSGetItemPrereleaseString -eq $moduleInfoPrerelease)
                        {
                            $message = $LocalizedData.ModuleVersionIsAlreadyAvailableInTheGallery -f ($moduleInfo.Name, $moduleInfoFullVersion, $currentPSGetItemFullVersion, $currentPSGetItemInfo.RepositorySourceLocation)
                            ThrowError -ExceptionName 'System.InvalidOperationException' `
                                       -ExceptionMessage $message `
                                       -ErrorId 'ModuleVersionIsAlreadyAvailableInTheGallery' `
                                       -CallerPSCmdlet $PSCmdlet `
                                       -ErrorCategory InvalidOperation
                        }

                        elseif (-not $Force -and ($currentPSGetItemPrereleaseString -gt $moduleInfoPrerelease))
                        {
                            $message = $LocalizedData.ModuleVersionShouldBeGreaterThanGalleryVersion -f ($moduleInfo.Name, $moduleInfoFullVersion, $currentPSGetItemFullVersion, $currentPSGetItemInfo.RepositorySourceLocation)
                            ThrowError -ExceptionName "System.InvalidOperationException" `
                                       -ExceptionMessage $message `
                                       -ErrorId "ModuleVersionShouldBeGreaterThanGalleryVersion" `
                                       -CallerPSCmdlet $PSCmdlet `
                                       -ErrorCategory InvalidOperation
                        }

                        # elseif ($currentPSGetItemPrereleaseString -lt $moduleInfoPrerelease) --> allow publish
                    }
                }
                elseif(-not $Force -and (Compare-PrereleaseVersions -FirstItemVersion $moduleInfoVersion `
                                                                    -FirstItemPrerelease $moduleInfoPrerelease `
                                                                    -SecondItemVersion $currentPSGetItemVersion `
                                                                    -SecondItemPrerelease $currentPSGetItemPrereleaseString))
                {
                    $message = $LocalizedData.ModuleVersionShouldBeGreaterThanGalleryVersion -f ($moduleInfo.Name, $moduleInfoVersion, $currentPSGetItemFullVersion, $currentPSGetItemInfo.RepositorySourceLocation)
                    ThrowError -ExceptionName "System.InvalidOperationException" `
                               -ExceptionMessage $message `
                               -ErrorId "ModuleVersionShouldBeGreaterThanGalleryVersion" `
                               -CallerPSCmdlet $PSCmdlet `
                               -ErrorCategory InvalidOperation
                }

                # else ($currentPSGetItemVersion -lt $moduleInfoVersion) --> allow publish
            }

            $shouldProcessMessage = $LocalizedData.PublishModulewhatIfMessage -f ($moduleInfo.Version, $moduleInfo.Name)
            if($Force -or $PSCmdlet.ShouldProcess($shouldProcessMessage, "Publish-Module"))
            {
                $PublishPSArtifactUtility_Params = @{
                    PSModuleInfo=$moduleInfo
                    ManifestPath=$manifestPath
                    NugetApiKey=$NuGetApiKey
                    Destination=$DestinationLocation
                    Repository=$Repository
                    NugetPackageRoot=$tempModulePath
                    FormatVersion=$FormatVersion
                    ReleaseNotes=$($ReleaseNotes -join "`r`n")
                    Tags=$Tags
                    LicenseUri=$LicenseUri
                    IconUri=$IconUri
                    ProjectUri=$ProjectUri
                    Verbose=$VerbosePreference
                    WarningAction=$WarningPreference
                    ErrorAction=$ErrorActionPreference
                    Debug=$DebugPreference
                }
                if ($PSBoundParameters.Containskey('Credential'))
                {
                    $PublishPSArtifactUtility_Params.Add('Credential',$Credential)
                }
                Publish-PSArtifactUtility @PublishPSArtifactUtility_Params
            }
        }
        finally
        {
            Microsoft.PowerShell.Management\Remove-Item $tempModulePath -Force -Recurse -ErrorAction Ignore -WarningAction SilentlyContinue -Confirm:$false -WhatIf:$false
        }
    }
}

function Publish-PSArtifactUtility
{
    [CmdletBinding(PositionalBinding=$false)]
    Param
    (
        [Parameter(Mandatory=$true, ParameterSetName='PublishModule')]
        [ValidateNotNullOrEmpty()]
        [PSModuleInfo]
        $PSModuleInfo,

        [Parameter(Mandatory=$true, ParameterSetName='PublishScript')]
        [ValidateNotNullOrEmpty()]
        [PSCustomObject]
        $PSScriptInfo,

        [Parameter(Mandatory=$true, ParameterSetName='PublishModule')]
        [ValidateNotNullOrEmpty()]
        [string]
        $ManifestPath,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Destination,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Repository,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $NugetApiKey,

        [Parameter(Mandatory=$false)]
        [pscredential]
        $Credential,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $NugetPackageRoot,

        [Parameter(ParameterSetName='PublishModule')]
        [Version]
        $FormatVersion,

        [Parameter(ParameterSetName='PublishModule')]
        [string]
        $ReleaseNotes,

        [Parameter(ParameterSetName='PublishModule')]
        [string[]]
        $Tags,

        [Parameter(ParameterSetName='PublishModule')]
        [Uri]
        $LicenseUri,

        [Parameter(ParameterSetName='PublishModule')]
        [Uri]
        $IconUri,

        [Parameter(ParameterSetName='PublishModule')]
        [Uri]
        $ProjectUri
    )

    Install-NuGetClientBinaries -CallerPSCmdlet $PSCmdlet -BootstrapNuGetExe

    $PSArtifactType = $script:PSArtifactTypeModule
    $Name = $null
    $Description = $null
    $Version = ""
    $Author = $null
    $CompanyName = $null
    $Copyright = $null
    $requireLicenseAcceptance = "false"

    if($PSModuleInfo)
    {
        $Name = $PSModuleInfo.Name
        $Description = $PSModuleInfo.Description
        $Version = $PSModuleInfo.Version
        $Author = $PSModuleInfo.Author
        $CompanyName = $PSModuleInfo.CompanyName
        $Copyright = $PSModuleInfo.Copyright

        if($PSModuleInfo.PrivateData -and
           ($PSModuleInfo.PrivateData.GetType().ToString() -eq "System.Collections.Hashtable") -and
           $PSModuleInfo.PrivateData["PSData"] -and
           ($PSModuleInfo.PrivateData["PSData"].GetType().ToString() -eq "System.Collections.Hashtable")
           )
        {
            if( -not $Tags -and $PSModuleInfo.PrivateData.PSData["Tags"])
            {
                $Tags = $PSModuleInfo.PrivateData.PSData.Tags
            }

            if( -not $ReleaseNotes -and $PSModuleInfo.PrivateData.PSData["ReleaseNotes"])
            {
                $ReleaseNotes = $PSModuleInfo.PrivateData.PSData.ReleaseNotes
            }

            if( -not $LicenseUri -and $PSModuleInfo.PrivateData.PSData["LicenseUri"])
            {
                $LicenseUri = $PSModuleInfo.PrivateData.PSData.LicenseUri
            }

            if( -not $IconUri -and $PSModuleInfo.PrivateData.PSData["IconUri"])
            {
                $IconUri = $PSModuleInfo.PrivateData.PSData.IconUri
            }

            if( -not $ProjectUri -and $PSModuleInfo.PrivateData.PSData["ProjectUri"])
            {
                $ProjectUri = $PSModuleInfo.PrivateData.PSData.ProjectUri
            }

            if ($PSModuleInfo.PrivateData.PSData["Prerelease"])
            {
                $psmoduleInfoPrereleaseString = $PSModuleInfo.PrivateData.PSData.Prerelease
                if ($psmoduleInfoPrereleaseString -and $psmoduleInfoPrereleaseString.StartsWith("-"))
                {
                    $Version = [string]$Version + $psmoduleInfoPrereleaseString
                }
                else
                {
                    $Version = [string]$Version + "-" + $psmoduleInfoPrereleaseString
                }
            }

            if($PSModuleInfo.PrivateData.PSData["RequireLicenseAcceptance"])
            {
                $requireLicenseAcceptance = $PSModuleInfo.PrivateData.PSData.requireLicenseAcceptance.ToString().ToLower()
                if($requireLicenseAcceptance -eq "true")
                {
                    if($FormatVersion -and ($FormatVersion.Major -lt $script:PSGetRequireLicenseAcceptanceFormatVersion.Major))
                    {
                        $message = $LocalizedData.requireLicenseAcceptanceNotSupported -f($FormatVersion)
                        ThrowError -ExceptionName "System.InvalidOperationException" `
                        -ExceptionMessage $message `
                        -ErrorId "requireLicenseAcceptanceNotSupported" `
                        -CallerPSCmdlet $PSCmdlet `
                        -ErrorCategory InvalidData
                    }

                    if(-not $LicenseUri)
                    {
                        $message = $LocalizedData.LicenseUriNotSpecified
                        ThrowError -ExceptionName "System.InvalidOperationException" `
                            -ExceptionMessage $message `
                            -ErrorId "LicenseUriNotSpecified" `
                            -CallerPSCmdlet $PSCmdlet `
                            -ErrorCategory InvalidData
                    }

                    $LicenseFilePath = Join-PathUtility -Path $NugetPackageRoot -ChildPath 'License.txt' -PathType File
                    if(-not $LicenseFilePath -or -not (Test-Path -Path $LicenseFilePath -PathType Leaf))
                    {
                        $message = $LocalizedData.LicenseTxtNotFound
                        ThrowError -ExceptionName "System.InvalidOperationException" `
                        -ExceptionMessage $message `
                        -ErrorId "LicenseTxtNotFound" `
                        -CallerPSCmdlet $PSCmdlet `
                        -ErrorCategory InvalidData
                    }

                    if((Get-Content -LiteralPath $LicenseFilePath) -eq $null)
                    {
                        $message = $LocalizedData.LicenseTxtEmpty
                        ThrowError -ExceptionName "System.InvalidOperationException" `
                        -ExceptionMessage $message `
                        -ErrorId "LicenseTxtEmpty" `
                        -CallerPSCmdlet $PSCmdlet `
                        -ErrorCategory InvalidData
                    }

                    #RequireLicenseAcceptance is true, License uri and license.txt exist. Bump Up the FormatVersion
                    if(-not $FormatVersion)
                    {
                        $FormatVersion = $script:CurrentPSGetFormatVersion
                    }
                }
                elseif($requireLicenseAcceptance -ne "false")
                {
                    $InvalidValueForRequireLicenseAcceptance = $LocalizedData.InvalidValueBoolean -f ($requireLicenseAcceptance, "requireLicenseAcceptance")
                    Write-Warning -Message $InvalidValueForRequireLicenseAcceptance
                }
            }
        }
    }
    else
    {
        $PSArtifactType = $script:PSArtifactTypeScript

        $Name = $PSScriptInfo.Name
        $Description = $PSScriptInfo.Description
        $Version = $PSScriptInfo.Version
        $Author = $PSScriptInfo.Author
        $CompanyName = $PSScriptInfo.CompanyName
        $Copyright = $PSScriptInfo.Copyright

        if($PSScriptInfo.'Tags')
        {
            $Tags = $PSScriptInfo.Tags
        }

        if($PSScriptInfo.'ReleaseNotes')
        {
            $ReleaseNotes = $PSScriptInfo.ReleaseNotes
        }

        if($PSScriptInfo.'LicenseUri')
        {
            $LicenseUri = $PSScriptInfo.LicenseUri
        }

        if($PSScriptInfo.'IconUri')
        {
            $IconUri = $PSScriptInfo.IconUri
        }

        if($PSScriptInfo.'ProjectUri')
        {
            $ProjectUri = $PSScriptInfo.ProjectUri
        }
    }


    # Add PSModule and PSGet format version tags
    if(-not $Tags)
    {
        $Tags = @()
    }

    if($FormatVersion)
    {
        $Tags += "$($script:PSGetFormatVersion)_$FormatVersion"
    }

    $DependentModuleDetails = @()

    if($PSScriptInfo)
    {
        $Tags += "PSScript"

        if($PSScriptInfo.DefinedCommands)
        {
            if($PSScriptInfo.DefinedFunctions)
            {
                $Tags += "$($script:Includes)_Function"
                $Tags += $PSScriptInfo.DefinedFunctions | Microsoft.PowerShell.Core\ForEach-Object { "$($script:Function)_$_" }
            }

            if($PSScriptInfo.DefinedWorkflows)
            {
                $Tags += "$($script:Includes)_Workflow"
                $Tags += $PSScriptInfo.DefinedWorkflows | Microsoft.PowerShell.Core\ForEach-Object { "$($script:Workflow)_$_" }
            }

            $Tags += $PSScriptInfo.DefinedCommands | Microsoft.PowerShell.Core\ForEach-Object { "$($script:Command)_$_" }
        }

        # Populate the dependencies elements from RequiredModules and RequiredScripts
        #
        $ValidateAndGetScriptDependencies_Params = @{
            Repository=$Repository
            DependentScriptInfo=$PSScriptInfo
            CallerPSCmdlet=$PSCmdlet
            Verbose=$VerbosePreference
            Debug=$DebugPreference
        }
        if ($PSBoundParameters.ContainsKey('Credential'))
        {
            $ValidateAndGetScriptDependencies_Params.Add('Credential',$Credential)
        }
        $DependentModuleDetails += ValidateAndGet-ScriptDependencies @ValidateAndGetScriptDependencies_Params
    }
    else
    {
        $Tags += "PSModule"

        $ModuleManifestHashTable = Get-ManifestHashTable -Path $ManifestPath

        if($PSModuleInfo.ExportedCommands.Count)
        {
            if($PSModuleInfo.ExportedCmdlets.Count)
            {
                $Tags += "$($script:Includes)_Cmdlet"
                $Tags += $PSModuleInfo.ExportedCmdlets.Keys | Microsoft.PowerShell.Core\ForEach-Object { "$($script:Cmdlet)_$_" }

                #if CmdletsToExport field in manifest file is "*", we suggest the user to include all those cmdlets for best practice
                if($ModuleManifestHashTable -and $ModuleManifestHashTable.ContainsKey('CmdletsToExport') -and ($ModuleManifestHashTable.CmdletsToExport -eq "*"))
                {
                    $WarningMessage = $LocalizedData.ShouldIncludeCmdletsToExport -f ($ManifestPath)
                    Write-Warning -Message $WarningMessage
                }
            }

            if($PSModuleInfo.ExportedFunctions.Count)
            {
                $Tags += "$($script:Includes)_Function"
                $Tags += $PSModuleInfo.ExportedFunctions.Keys | Microsoft.PowerShell.Core\ForEach-Object { "$($script:Function)_$_" }

                if($ModuleManifestHashTable -and $ModuleManifestHashTable.ContainsKey('FunctionsToExport') -and ($ModuleManifestHashTable.FunctionsToExport -eq "*"))
                {
                    $WarningMessage = $LocalizedData.ShouldIncludeFunctionsToExport -f ($ManifestPath)
                    Write-Warning -Message $WarningMessage
                }
            }

            $Tags += $PSModuleInfo.ExportedCommands.Keys | Microsoft.PowerShell.Core\ForEach-Object { "$($script:Command)_$_" }
        }

        $dscResourceNames = Get-ExportedDscResources -PSModuleInfo $PSModuleInfo
        if($dscResourceNames)
        {
            $Tags += "$($script:Includes)_DscResource"

            $Tags += $dscResourceNames | Microsoft.PowerShell.Core\ForEach-Object { "$($script:DscResource)_$_" }

            #If DscResourcesToExport is commented out or "*" is used, we will write-warning
            if($ModuleManifestHashTable -and
                ($ModuleManifestHashTable.ContainsKey("DscResourcesToExport") -and
                $ModuleManifestHashTable.DscResourcesToExport -eq "*") -or
                -not $ModuleManifestHashTable.ContainsKey("DscResourcesToExport"))
            {
                $WarningMessage = $LocalizedData.ShouldIncludeDscResourcesToExport -f ($ManifestPath)
                Write-Warning -Message $WarningMessage
            }
        }

        $RoleCapabilityNames = Get-AvailableRoleCapabilityName -PSModuleInfo $PSModuleInfo
        if($RoleCapabilityNames)
        {
            $Tags += "$($script:Includes)_RoleCapability"

            $Tags += $RoleCapabilityNames | Microsoft.PowerShell.Core\ForEach-Object { "$($script:RoleCapability)_$_" }
        }

        # Populate the module dependencies elements from RequiredModules and
        # NestedModules properties of the current PSModuleInfo
        $GetModuleDependencies_Params = @{
            PSModuleInfo=$PSModuleInfo
            Repository=$Repository
            CallerPSCmdlet=$PSCmdlet
            Verbose=$VerbosePreference
            Debug=$DebugPreference
        }
        if ($PSBoundParameters.ContainsKey('Credential'))
        {
            $GetModuleDependencies_Params.Add('Credential',$Credential)
        }
        $DependentModuleDetails = Get-ModuleDependencies @GetModuleDependencies_Params
    }

    $dependencies = @()
    ForEach($Dependency in $DependentModuleDetails)
    {
        $ModuleName = $Dependency.Name
        $VersionString = $null

        # Version format in NuSpec:
        # "[2.0]" --> (== 2.0) Required Version
        # "2.0" --> (>= 2.0) Minimum Version
        #
        # When only MaximumVersion is specified in the ModuleSpecification
        # (,1.0]  = x <= 1.0
        #
        # When both Minimum and Maximum versions are specified in the ModuleSpecification
        # [1.0,2.0] = 1.0 <= x <= 2.0

        if($Dependency.Keys -Contains "RequiredVersion")
        {
            $VersionString = "[$($Dependency.RequiredVersion)]"
        }
        elseif($Dependency.Keys -Contains 'MinimumVersion' -and $Dependency.Keys -Contains 'MaximumVersion')
        {
            $VersionString = "[$($Dependency.MinimumVersion),$($Dependency.MaximumVersion)]"
        }
        elseif($Dependency.Keys -Contains 'MaximumVersion')
        {
            $VersionString = "(,$($Dependency.MaximumVersion)]"
        }
        elseif($Dependency.Keys -Contains 'MinimumVersion')
        {
            $VersionString = "$($Dependency.MinimumVersion)"
        }

        if ([System.string]::IsNullOrWhiteSpace($VersionString))
        {
            $dependencies += "<dependency id='$($ModuleName)'/>"
        }
        else
        {
            $dependencies += "<dependency id='$($ModuleName)' version='$($VersionString)' />"
        }
    }

    # Populate the nuspec elements
    $nuspec = @"
<?xml version="1.0"?>
<package >
    <metadata>
        <id>$(Get-EscapedString -ElementValue "$Name")</id>
        <version>$($Version)</version>
        <authors>$(Get-EscapedString -ElementValue "$Author")</authors>
        <owners>$(Get-EscapedString -ElementValue "$CompanyName")</owners>
        <description>$(Get-EscapedString -ElementValue "$Description")</description>
        <releaseNotes>$(Get-EscapedString -ElementValue "$ReleaseNotes")</releaseNotes>
        <requireLicenseAcceptance>$($requireLicenseAcceptance.ToString())</requireLicenseAcceptance>
        <copyright>$(Get-EscapedString -ElementValue "$Copyright")</copyright>
        <tags>$(if($Tags){ Get-EscapedString -ElementValue ($Tags -join ' ')})</tags>
        $(if($LicenseUri){
         "<licenseUrl>$(Get-EscapedString -ElementValue "$LicenseUri")</licenseUrl>"
        })
        $(if($ProjectUri){
        "<projectUrl>$(Get-EscapedString -ElementValue "$ProjectUri")</projectUrl>"
        })
        $(if($IconUri){
        "<iconUrl>$(Get-EscapedString -ElementValue "$IconUri")</iconUrl>"
        })
        <dependencies>
            $dependencies
        </dependencies>
    </metadata>
</package>
"@

# When packaging we must build something.
# So, we are building an empty assembly called NotUsed, and discarding it.
$CsprojContent = @"
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <AssemblyName>NotUsed</AssemblyName>
    <Description>Temp project used for creating nupkg file.</Description>
    <NuspecFile>$Name.nuspec</NuspecFile>
    <NuspecBasePath>$NugetPackageRoot</NuspecBasePath>
    <TargetFramework>netcoreapp2.0</TargetFramework>
  </PropertyGroup>
</Project>
"@
    $NupkgPath = Microsoft.PowerShell.Management\Join-Path -Path $NugetPackageRoot -ChildPath "$Name.$Version.nupkg"

    $csprojBasePath = $null
    if($script:DotnetCommandPath) {
        $csprojBasePath = Microsoft.PowerShell.Management\Join-Path -Path $script:TempPath -ChildPath ([System.Guid]::NewGuid())
        $null = Microsoft.PowerShell.Management\New-Item -Path $csprojBasePath -ItemType Directory -Force -WhatIf:$false -Confirm:$false
        $NuspecPath = Microsoft.PowerShell.Management\Join-Path -Path $csprojBasePath -ChildPath "$Name.nuspec"
        $CsprojFilePath = Microsoft.PowerShell.Management\Join-Path -Path $csprojBasePath -ChildPath "$Name.csproj"
    }
    else {
        $NuspecPath = Microsoft.PowerShell.Management\Join-Path -Path $NugetPackageRoot -ChildPath "$Name.nuspec"
    }

    $tempErrorFile = $null
    $tempOutputFile = $null

    try
    {
        # Remove existing nuspec and nupkg files
        if($NupkgPath -and (Test-Path -Path $NupkgPath -PathType Leaf))
        {
            Microsoft.PowerShell.Management\Remove-Item $NupkgPath  -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue -Confirm:$false -WhatIf:$false
        }

        if($NuspecPath -and (Test-Path -Path $NuspecPath -PathType Leaf))
        {
            Microsoft.PowerShell.Management\Remove-Item $NuspecPath -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue -Confirm:$false -WhatIf:$false
        }

        Microsoft.PowerShell.Management\Set-Content -Value $nuspec -Path $NuspecPath -Force -Confirm:$false -WhatIf:$false

        # Create .nupkg file
        if($script:DotnetCommandPath) {
            Microsoft.PowerShell.Management\Set-Content -Value $CsprojContent -Path $CsprojFilePath -Force -Confirm:$false -WhatIf:$false

            $arguments = @('pack')
            $arguments += $csprojBasePath
            $arguments += @('--output',$NugetPackageRoot)
            $arguments += "/p:StagingPath=$NugetPackageRoot"
            $output = & $script:DotnetCommandPath $arguments
            Write-Debug -Message "dotnet pack output:  $output"
        }
        elseif($script:NuGetExePath) {
            $output = & $script:NuGetExePath pack $NuspecPath -OutputDirectory $NugetPackageRoot
        }

        if(-not (Test-Path -Path $NupkgPath -PathType Leaf)) {
            $SemanticVersionString = Get-NormalizedVersionString -Version $Version
            $NupkgPath = Join-PathUtility -Path $NugetPackageRoot -ChildPath "$Name.$($SemanticVersionString).nupkg" -PathType File
        }

        if($LASTEXITCODE -or -not $NupkgPath -or -not (Test-Path -Path $NupkgPath -PathType Leaf))
        {
            if($PSArtifactType -eq $script:PSArtifactTypeModule)
            {
                $message = $LocalizedData.FailedToCreateCompressedModule -f ($output)
                $errorId = "FailedToCreateCompressedModule"
            }
            else
            {
                $message = $LocalizedData.FailedToCreateCompressedScript -f ($output)
                $errorId = "FailedToCreateCompressedScript"
            }

            Write-Error -Message $message -ErrorId $errorId -Category InvalidOperation
            return
        }

        # Publish the .nupkg to gallery
        $tempErrorFile = Microsoft.PowerShell.Management\Join-Path -Path $nugetPackageRoot -ChildPath "TempPublishError.txt"
        $tempOutputFile = Microsoft.PowerShell.Management\Join-Path -Path $nugetPackageRoot -ChildPath "TempPublishOutput.txt"

        $errorMsg = $null
        $outputMsg = $null
        $StartProcess_params = @{
            RedirectStandardError = $tempErrorFile
            RedirectStandardOutput = $tempOutputFile
            NoNewWindow = $true
            Wait = $true
            PassThru = $true
        }

        if($script:DotnetCommandPath) {
            $StartProcess_params['FilePath'] = $script:DotnetCommandPath

            $ArgumentList = @('nuget')
            $ArgumentList += 'push'
            $ArgumentList += "`"$NupkgPath`""
            $ArgumentList += @('--source', "`"$($Destination.TrimEnd('\'))`"")
            $ArgumentList += @('--api-key', "`"$NugetApiKey`"")
            $ArgumentList += @('-v','diag')

        }
        elseif($script:NuGetExePath) {
            $StartProcess_params['FilePath'] = $script:NuGetExePath

            $ArgumentList = @('push')
            $ArgumentList += "`"$NupkgPath`""
            $ArgumentList += @('-source', "`"$($Destination.TrimEnd('\'))`"")
            $ArgumentList += @('-apikey', "`"$NugetApiKey`"")
            $ArgumentList += '-NonInteractive'
        }
        $StartProcess_params['ArgumentList'] = $ArgumentList

        if($script:IsCoreCLR -and -not $script:IsNanoServer) {
            $StartProcess_params['WhatIf'] = $false
            $StartProcess_params['Confirm'] = $false
        }

        $process = Microsoft.PowerShell.Management\Start-Process @StartProcess_params

        if(Test-Path -Path $tempErrorFile -PathType Leaf) {
            $errorMsg = Microsoft.PowerShell.Management\Get-Content -Path $tempErrorFile -Raw

            if($errorMsg) {
                Write-Verbose -Message $errorMsg
            }
        }

        if(Test-Path -Path $tempOutputFile -PathType Leaf) {
            $outputMsg = Microsoft.PowerShell.Management\Get-Content -Path $tempOutputFile -Raw

            if($outputMsg) {
                Write-Verbose -Message $outputMsg
            }
        }

        # The newer version of dotnet cli writes the error message into output stream instead of error stream
        # Get the error message from output stream when ExitCode is non zero (error).
        if($process -and $process.ExitCode -and -not $errorMsg -and $outputMsg) {
            $errorMsg = $outputMsg
        }

        if(-not $process -or $process.ExitCode)
        {
            if(($NugetApiKey -eq 'VSTS') -and
               ($errorMsg -match 'Cannot prompt for input in non-interactive mode.') )
            {
                $errorMsg = $LocalizedData.RegisterVSTSFeedAsNuGetPackageSource -f ($Destination, $script:VSTSAuthenticatedFeedsDocUrl)
            }

            if($PSArtifactType -eq $script:PSArtifactTypeModule)
            {
                $message = $LocalizedData.FailedToPublish -f ($Name,$errorMsg)
                $errorId = "FailedToPublishTheModule"
            }
            else
            {
                $message = $LocalizedData.FailedToPublishScript -f ($Name,$errorMsg)
                $errorId = "FailedToPublishTheScript"
            }

            Write-Error -Message $message -ErrorId $errorId -Category InvalidOperation
        }
        else
        {
            if($PSArtifactType -eq $script:PSArtifactTypeModule)
            {
                $message = $LocalizedData.PublishedSuccessfully -f ($Name, $Destination, $Name)
            }
            else
            {
                $message = $LocalizedData.PublishedScriptSuccessfully -f ($Name, $Destination, $Name)
            }

            Write-Verbose -Message $message
        }
    }
    finally
    {
        if($NupkgPath -and (Test-Path -Path $NupkgPath -PathType Leaf))
        {
            Microsoft.PowerShell.Management\Remove-Item $NupkgPath  -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue -Confirm:$false -WhatIf:$false
        }

        if($NuspecPath -and (Test-Path -Path $NuspecPath -PathType Leaf))
        {
            Microsoft.PowerShell.Management\Remove-Item $NuspecPath -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue -Confirm:$false -WhatIf:$false
        }

        if($tempErrorFile -and (Test-Path -Path $tempErrorFile -PathType Leaf))
        {
            Microsoft.PowerShell.Management\Remove-Item $tempErrorFile -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue -Confirm:$false -WhatIf:$false
        }

        if($tempOutputFile -and (Test-Path -Path $tempOutputFile -PathType Leaf))
        {
            Microsoft.PowerShell.Management\Remove-Item $tempOutputFile -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue -Confirm:$false -WhatIf:$false
        }

        if($csprojBasePath -and (Test-Path -Path $csprojBasePath -PathType Container))
        {
            Microsoft.PowerShell.Management\Remove-Item -Path $csprojBasePath -Recurse -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue -Confirm:$false -WhatIf:$false
        }
    }
}
