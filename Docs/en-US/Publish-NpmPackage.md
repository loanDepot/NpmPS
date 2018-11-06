---
external help file: NpmPS-help.xml
Module Name: NpmPS
online version:
schema: 2.0.0
---

# Publish-NpmPackage

## SYNOPSIS
Publishes a npm package

## SYNTAX

```
Publish-NpmPackage [-Path] <String> [-Registry <String>] [-Credential <PSCredential>] [-Version <String>]
 [-Tag <String[]>] [-Force] [<CommonParameters>]
```

## DESCRIPTION
{{Fill in the Description}}

## EXAMPLES

### EXAMPLE 1
```
$registry = 'https://contoso.local/npm'
```

$credential = Get-Credential

$publishLDNpmPackageSplat = @{
    Credential = $credential
    Path       = $path
    Registry   = $registry
    Version    = '0.1.0-rc.1'
    Tag        = 'testrelease'
}
Publish-NpmPackage @publishLDNpmPackageSplat

## PARAMETERS

### -Credential
Username and API Token as password

```yaml
Type: PSCredential
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Force
Force publish even if package already exists

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -Path
Location of the package.json

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Registry
NPM Registry to publish

```yaml
Type: String
Parameter Sets: (All)
Aliases: Repository

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Tag
tags to set when publishing

```yaml
Type: String[]
Parameter Sets: (All)
Aliases: Tags

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Version
SemVer

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see about_CommonParameters (http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES

## RELATED LINKS
