function Use-ObjectPageSchematic
{
    <#
    .Synopsis
        Builds a web application according to a schematic
    .Description
        Use-Schematic builds a web application according to a schematic.
        
        Web applications should not be incredibly unique: they should be built according to simple schematics.        
    .Notes
    
        When ConvertTo-ModuleService is run with -UseSchematic, if a directory is found beneath either Pipeworks 
        or the published module's Schematics directory with the name Use-Schematic.ps1 and containing a function 
        Use-Schematic, then that function will be called in order to generate any pages found in the schematic.
        
        The schematic function should accept a hashtable of parameters, which will come from the appropriately named 
        section of the pipeworks manifest
        (for instance, if -UseSchematic Blog was passed, the Blog section of the Pipeworks manifest would be used for the parameters).
        
        It should return a hashtable containing the content of the pages.  Content can either be static HTML or .PSPAGE                
    #>
    [OutputType([Hashtable])]
    param(
    # Any parameters for the schematic
    [Parameter(Mandatory=$true)][Hashtable]$Parameter,
    
    # The pipeworks manifest, which is used to validate common parameters
    [Parameter(Mandatory=$true)][Hashtable]$Manifest,
    
    # The directory the schemtic is being deployed to
    [Parameter(Mandatory=$true)][string]$DeploymentDirectory,
    
    # The directory the schematic is being deployed from
    [Parameter(Mandatory=$true)][string]$InputDirectory  
    )
    
    begin {
        $pages = @{}
    }
    
    process {                    
        if (-not $Manifest.Table.Name) {
            Write-Error "No table found in manifest"
            return
        }
        
        if (-not $Manifest.Table.StorageAccountSetting) {
            Write-Error "No storage account name setting found in manifest"
            return
        }
        
        if (-not $manifest.Table.StorageKeySetting) {
            Write-Error "No storage account key setting found in manifest"
            return
        }
        

                                
        foreach ($objectPageInfo in $parameter.GetEnumerator()) {
            $pagename = $objectPageInfo.Key
            $value = $objectPageInfo.Value                


            $webOBjectPage = @"
        `$storageAccount  = Get-WebConfigurationSetting -Setting `$pipeworksManifest.Table.StorageAccountSetting 
        `$storageKey= Get-WebConfigurationSetting -Setting `$pipeworksManifest.Table.StorageKeySetting 
        `$part, `$row  = '$($objectPageInfo.Value.Id)' -split '\:'
        `$lMargin = '$marginPercentLeftString'
        `$rMargin = '$marginPercentRightString'
        `$pageName = '$($value.Title)'
"@ + {
        if (-not $session["ObjectPage$($PageName)"]) {
        $session["ObjectPage$($PageName)"] = 
            Show-WebObject -StorageAccount $storageAccount -StorageKey $storageKey -Table $pipeworksManifest.Table.Name -Part $part -Row $row |
            New-Region -Style @{
                'Margin-Left' = $lMargin
                'Margin-Right' = $rMargin
                'Margin-Top' = '2%'
            } |
            New-WebPage  -Title $pageName    
        }

        $session["ObjectPage$($PageName)"] | Out-HTML -WriteResponse
                                            
    }                
        
            $pages["$pagename.pspage"] ="<|
$webObjectPage
|>"     
        }        
    }
    end {
        $pages
    }
} 

