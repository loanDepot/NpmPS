function Publish-NpmPackage
{
    <#
        .Synopsis
        Publishes a npm package

        .Example

        $registry = 'https://contoso.local/npm'
        $credential = Get-Credential

        $publishLDNpmPackageSplat = @{
            Credential = $credential
            Path       = $path
            Registry   = $registry
            Version    = '0.1.0-rc.1'
            Tag        = 'testrelease'
        }
        Publish-NpmPackage @publishLDNpmPackageSplat

        .Notes

    #>
    [cmdletbinding()]
    param(
        # Location of the package.json
        [Parameter(
            Mandatory,
            Position = 0,
            ValueFromPipelineByPropertyName
        )]
        [ValidateNotNullOrEmpty()]
        [String]
        $Path,

        # NPM Registry to publish
        [Alias('Repository')]
        [String]
        $Registry,

        # Username and API Token as password
        [PSCredential]
        $Credential,

        # SemVer
        [String]
        $Version,

        # tags to set when publishing
        [Alias('Tags')]
        [String[]]
        $Tag,

        # Force publish even if package already exists
        [Switch]
        $Force
    )

    begin
    {
        $npmProtocolRegex = '^http?:'
    }

    process
    {
        try
        {
            $Path = $Path -replace '\\\\[\w\d-]*\\(\w)\$', '$1:'

            if ( -not ( Test-Path -Path $Path ) )
            {
                Write-Error "Could not find [$Path] or access is denied" -ErrorAction Stop
            }
            elseif ( Test-Path -Path $Path -PathType Leaf )
            {
                $Path = Split-Path -Path $Path
            }
            $package = Join-Path -Path $Path -ChildPath 'package.json'

            if ( -not ( Test-Path -Path $package ) )
            {
                Write-Error "Could not find NPM Package [$package] or access is denied" -ErrorAction Stop
            }

            if ( $Registry -notmatch $npmProtocolRegex )
            {
                Write-Error "Registry URI [$Registry] is not valid. Should match regex pattern [$npmProtocolRegex]" -ErrorAction Stop
            }

            Write-Verbose "Deploying package from path [$path]"

            Push-Location -Path $Path -StackName PublishNpmPackage
            Write-Verbose "Working directory [$pwd]"

            if ( ![string]::IsNullOrEmpty( $Version ) )
            {
                if ($Version -notmatch '^v?\d+\.\d+(\.\d+)?')
                {
                    Write-Error "Version [$Version] is not a valid SemVer" -ErrorAction 'Stop'
                }

                # ProGet needs to use period instead of plus for semver
                $Version -replace '\+', '.'

                $json = Get-Content $package -Raw | ConvertFrom-LDJson -ErrorAction Stop

                $json.version = $Version

                Write-Verbose "Set version to [{0}]" -f $json.version
                $json | Format-LDJson | Set-Content -Path $package -Encoding UTF8
            }

            Write-Verbose "Contents of [$package]:"
            $packageData = Get-Content -Path $package -Raw
            $packageObject = $packageData | ConvertFrom-JSON

            Write-Verbose "Package version [$($packageObject.Version)]"

            Write-Verbose "Checking to see if package is already published"

            if ( Test-NpmPackage -Name $packageObject.name -Version $packageObject.version )
            {
                Write-Verbose 'This package is already published'
                if ( !$Force )
                {
                    return
                }
                Write-Warning "This version of the package is already published. This will invalidate existing checksums for this version."
            }

            Write-Verbose "NPM Version [$(npm --version)]"

            $password = $Credential.GetNetworkCredential().password

            # need trailing slash on registry name
            if ( $Registry -notmatch '/$' )
            {
                $Registry = "$Registry/"
            }

            # need registry without protocol prefix
            $shortRegName = $Registry -replace $npmProtocolRegex

            $config = @"
registry=${Registry}
${shortRegName}:_password=$password
${shortRegName}:username=$($credential.username)
${shortRegName}:email=devops@loandepot.com
${shortRegName}:always-auth=false
"@
            $configPath = Join-Path $pwd -ChildPath '.npmrc'

            Write-Verbose "Saving registry info to project local config [$configPath]"
            Set-Content -Path $configPath -Value $config

            Write-Verbose "Running [npm config list]"
            npm config list

            if ( $null -eq $PSBoundParameters.Tag  )
            {
                Write-Verbose "Running [npm publish]"
                npm publish -tag prerelease
            }
            else
            {
                Write-Verbose "Publishing with tags [$( $Tag -join ',' )]"
                foreach ($publishTag in $Tag)
                {
                    Write-Verbose "Running [npm publish -tag $publishTag]"
                    npm publish -tag $publishTag
                }
            }

            if ( Test-NpmPackage -Name $packageObject.name -Version $packageObject.version )
            {
                Write-Verbose 'This package is now available in the registry'
            }
            else
            {
                Write-Error "This published package could not be found in the registry [$registry]"
            }
        }
        catch
        {
            $PSCmdlet.ThrowTerminatingError( $PSItem )
        }
        finally
        {
            Pop-Location -StackName PublishNpmPackage
        }
    }
}
