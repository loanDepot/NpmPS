function Get-NpmPackageInfo
{
    <#
        .Synopsis
        Get package info from NPM registry

        .Example
        Get-NpmPackageInfo -Name contoso-component -Registry 'http://contoso.local/npm'
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

        # NPM registry uri
        [Alias('URI','Repository')]
        [Parameter(
            Mandatory,
            Position = 1,
            ValueFromPipelineByPropertyName
        )]
        [ValidateNotNullOrEmpty()]
        [String]
        $Registry
    )

    process
    {
        try
        {
            # need trailing slash on registry name
            if ( $Registry -notmatch '/$' )
            {
                $Registry = "$Registry/"
            }

            $uri = "{0}{1}" -f $Registry, $Name

            Invoke-RestMethod -Uri $uri
        }
        catch
        {
            $PSCmdlet.ThrowTerminatingError( $PSItem )
        }
    }
}
