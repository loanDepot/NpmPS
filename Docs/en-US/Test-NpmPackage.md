---
external help file: NpmPS-help.xml
Module Name: NpmPS
online version:
schema: 2.0.0
---

# Test-NpmPackage

## SYNOPSIS
Tests to see if specified package is already published

## SYNTAX

```
Test-NpmPackage [-Name] <String> [-Registry] <String> [[-Version] <String>] [[-Tag] <String>]
 [<CommonParameters>]
```

## DESCRIPTION
{{Fill in the Description}}

## EXAMPLES

### EXAMPLE 1
```
$Name = 'contoso-component'
```

$Registry = 'http://contoso.local/npm/'
Test-NpmPackage -Name $Name -Registry $Registry

### EXAMPLE 2
```
$Name = 'contoso-component'
```

$Registry = 'http://contoso.local/npm/'
Test-NpmPackage -Name $Name -Registry $Registry -Version 0.0.1 -Tag Latest

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
NPM Registry uri

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

### -Tag
Package tag

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 4
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Version
NPM Package Version

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see about_CommonParameters (http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES

## RELATED LINKS
