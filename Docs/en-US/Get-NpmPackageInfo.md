---
external help file: NpmPS-help.xml
Module Name: NpmPS
online version:
schema: 2.0.0
---

# Get-NpmPackageInfo

## SYNOPSIS
Get package info from NPM registry

## SYNTAX

```
Get-NpmPackageInfo [-Name] <String> [-Registry] <String> [<CommonParameters>]
```

## DESCRIPTION
{{Fill in the Description}}

## EXAMPLES

### EXAMPLE 1
```
Get-NpmPackageInfo -Name contoso-component -Registry 'http://contoso.local/npm'
```

## PARAMETERS

### -Name
Name of the npm package

```yaml
Type: String
Parameter Sets: (All)
Aliases: PackageName

Required: True
Position: 1
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Registry
NPM registry uri

```yaml
Type: String
Parameter Sets: (All)
Aliases: URI, Repository

Required: True
Position: 2
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable.
For more information, see about_CommonParameters (http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES

## RELATED LINKS
