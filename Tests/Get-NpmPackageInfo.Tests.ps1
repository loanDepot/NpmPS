InModuleScope -ModuleName NpmPS {
    Describe 'Function Get-NpmPackageInfo' -Tag Build {

        $examplePackage = Join-Path $PSScriptRoot 'data/npmpackage.json'
        Mock -CommandName Invoke-RestMethod -Verifiable  {
            Get-Content $examplePackage -Raw | ConvertFrom-Json
        }

        It 'Should get an NPM Package' {
            $result = Get-NpmPackageInfo -Name contoso-component -Registry 'http://localhost/feed'
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -BeExactly 'contoso-component'
        }
    }
}
