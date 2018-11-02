function Test-NpmPackage
{
    <#
        .Synopsis
        Tests to see if specified package is already published

        .Example
        $Name = 'contoso-component'
        $Registry = 'http://contoso.local/npm/'
        Test-NpmPackage -Name $Name -Registry $Registry

        .Example
        $Name = 'contoso-component'
        $Registry = 'http://contoso.local/npm/'
        Test-NpmPackage -Name $Name -Registry $Registry -Version 0.0.1 -Tag Latest

        .Notes

    #>
    [cmdletbinding()]
    param(
        # Name of the npm package
        [Alias('PackageName')]
        [Parameter(
            Mandatory,
            Position = 0,
            ValueFromPipelineByPropertyName
        )]
        [ValidateNotNullOrEmpty()]
        [String]
        $Name,

        # NPM Registry uri
        [Alias('URI','Repository')]
        [Parameter(
            Mandatory,
            Position = 1,
            ValueFromPipelineByPropertyName
        )]
        [ValidateNotNullOrEmpty()]
        [String]
        $Registry,

        # NPM Package Version
        [Parameter(
            Position = 2,
            ValueFromPipelineByPropertyName
        )]
        [String]
        $Version,

        # Package tag
        [Parameter(
            Position = 3,
            ValueFromPipelineByPropertyName
        )]
        [String]
        $Tag
    )

    process
    {
        try
        {
            try
            {
                Write-Verbose "Querying for [$Name] in [$Registry]"
                $package = Get-NpmPackageInfo -Name $Name -Registry $Registry -ErrorAction Stop
            }
            catch
            {
                Write-Verbose 'Was not able to connect to registry or find the package'
                Write-Verbose $PSItem
                return $false
            }

            if ( $null -eq $package )
            {
                Write-Verbose 'No package was found'
                return $false
            }

            if ( ![String]::IsNullOrEmpty( $Version ) )
            {
                if ( $null -eq $package.versions )
                {
                    Write-Verbose "This package does not have a version"
                    return $false
                }

                if ( -not $package.versions.contains($Version) )
                {
                    Write-Verbose "This package version [$Version] was not found"
                    return $false
                }
            }

            if ( ![String]::IsNullOrEmpty( $Tag ) )
            {
                if ( $null -eq $package.'dist-tags' -or @($package.'dist-tags').count -lt 1 )
                {
                    Write-Verbose "This package does not have a tag"
                    return $false
                }

                if ( -not $package.'dist-tags'.contains( $Tag ) )
                {
                    Write-Verbose "This package tag [$Tag] was not found"
                    return $false
                }
            }

            if ( ![String]::IsNullOrEmpty( $Version ) -and
                 ![String]::IsNullOrEmpty( $Tag ) )
            {
                if ( $package.'dist-tags'.$Tag -ne $Version )
                {
                    Write-Verbose ( "This package has tag [{0}][{1}] but did not match version [{2}]" -f $Tag,$package.'dist-tags'[$Tag],$Version )
                    return $false
                }
            }

            $true
        }
        catch
        {
            $PSCmdlet.ThrowTerminatingError( $PSItem )
        }
    }
}
