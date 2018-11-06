InModuleScope -ModuleName NpmPS {
    Describe 'Function Test-NpmPackage' -Tag Build {

        $examplePackage = Join-Path $PSScriptRoot 'data/npmpackage.json'
        Mock -CommandName Invoke-RestMethod -Verifiable {
            if ( $Name -eq 'contoso-component' )
            {
                Get-Content $examplePackage -Raw | ConvertFrom-Json
            }
        }

        $testCases = @(
            @{
                Name   = 'contoso-component'
                Result = $true
            }
            @{
                Name    = 'contoso-component'
                Version = '0.0.1'
                Result  = $true
            }
            @{
                Name   = 'contoso-component'
                Tag    = 'latest'
                Result = $true
            }
            @{
                Name    = 'contoso-component'
                Version = '0.0.0-rc.5'
                Result  = $true
            }
            @{
                Name   = 'contoso-component'
                Tag    = 'prerelease'
                Result = $true
            }
            @{
                Name    = 'contoso-component'
                Version = '0.0.0-rc.5'
                Tag     = 'prerelease'
                Result  = $true
            }
            @{
                Name   = 'contoso-component-missing'
                Result = $false
            }
            @{
                Name    = 'contoso-component'
                Version = '0.0.0-missing'
                Result  = $false
            }
            @{
                Name   = 'contoso-component'
                Tag    = 'missing'
                Result = $false
            }
            @{
                Name    = 'contoso-component'
                Version = '0.0.0-rc.5'
                Tag     = 'latest'
                Result  = $false
            }
            @{
                Name    = 'contoso-component'
                Version = ''
                Tag     = ''
                Result  = $true
            }
        )

        It 'Test <Name>@<Version> <Tag> should be <Result>' -TestCases $testCases {
            param ( $Name, $Version, $Tag, $Result )

            $PSBoundParameters.Remove('Result')
            $output = Test-NpmPackage @PSBoundParameters -Registry http://localhost/feed/

            $output | Should -Not -BeNullOrEmpty
            $output | Should -BeExactly $Result
        }
    }
}
