function Use-BlogSchematic
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
    
    process {
    
        if (-not $Parameter.Name) {
            Write-Error "No Blog name found in parameters"
            return
        }
        
        
        $blogName = $parameter.Name 
        if (-not $Parameter.Description) {
            Write-Error "No description found in parameters"
            return
        }
        
        
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
        
        
        #$manifest.AcceptAnyUrl = $true


        $psm1 = Get-childItem $DeploymentDirectory -Filter bin | 
            Get-ChildItem -Filter "$($module)" | 
            Get-ChildItem -Filter "*.psm1"


        # If we find a PSM1, we can do something pretty nifty:
        # Slightly rewrite it with a couple of new commands and aliases:                
        # - Get-$ModuleFeed (alias rss)         
        # - Show-$ModuleTag (alias tag/tags)
        if ($psm1) {
            
        }
        



                                        
        
        $blogPage = {

#region Resolve the absolute URL
$protocol = ($request['Server_Protocol'] -split '/')[0]  # Split out the protocol
$serverName= $request['Server_Name']                     # And what it thinks it called the server
$shortPath = Split-Path $request['PATH_INFO']            # And the relative path beneath that URL
$remoteCommandUrl =                                      # Put them all together
    $Protocol + '://' + $ServerName.Replace('\', '/').TrimEnd('/') + '/' + $shortPath.Replace('\','/').TrimStart('/')

$absoluteUrl =        
    $remoteCommandUrl.TrimEnd("/") + $request['Url'].ToString().Substring(
        $request['Url'].ToString().LastIndexOf("/"))

#endregion Resolve the absolute URL

#region Unpack blog items
$unpackItem = 
    {
        $item = $_
        $item.psobject.properties |                         
            Where-Object { 
                ('Timestamp', 'RowKey', 'TableName', 'PartitionKey' -notcontains $_.Name) -and
                (-not "$($_.Value)".Contains(' ')) 
            }|                        
            ForEach-Object {
                try {
                    $expanded = Expand-Data -CompressedData $_.Value
                    $item | Add-Member NoteProperty $_.Name $expanded -Force
                } catch{
                    Write-Verbose $_
                
                }
            }
            
        $item.psobject.properties |                         
            Where-Object { 
                ('Timestamp', 'RowKey', 'TableName', 'PartitionKey' -notcontains $_.Name) -and
                (-not "$($_.Value)".Contains('<')) 
            }|                                   
            ForEach-Object {
                try {
                    $fromMarkdown = ConvertFrom-Markdown -Markdown $_.Value
                    $item | Add-Member NoteProperty $_.Name $fromMarkdown -Force
                } catch{
                    Write-Verbose $_
                
                }
            }

        $item                         
    }
#endregion Unpack blog items


#region Blog Metadata
$blogName = 
    if ($pipeworksManifest.Blog.Name) {
        $pipeworksManifest.Blog.Name
    } else {
        $module.Name
    }
    
$blogDescription = 
    if ($pipeworksManifest.Blog.Description) {
        $pipeworksManifest.Blog.Description
    } else {
        $module.Description
    }
$partitionKey = $blogName
#endregion

  
#region Blog Title Bar

$rssButton = Write-Link -Button -Style @{'font-size'='xx-small'} -Caption "<span class='ui-icon ui-icon-signal-diag'></span>" -Url "Module.ashx?rss=$BlogName"
$shareButton = 
    New-Region -AsPopdown -LayerID SharePopdown -Style @{
        'font-size' = 'xx-small'
    } -Layer @{
        "<span class='ui-icon ui-icon-mail-closed'></span>" = "
        $(Write-Link twitter:tweet)
        <br/>
        $(Write-Link google:plusone)
        "
    }
    
    
$searchButton = 
    New-Region -AsPopdown -LayerID SearchPopdown -Style @{
        'font-size' = 'xx-small'
    } -Layer @{
        "<span class='ui-icon ui-icon-search'></span>" = "
        <form>        
            <input name='term' value='$([Web.HttpUtility]::HtmlAttributeEncode($request['Term']))'type='text' style='width:80%' placeholder='Search $blogName' />
        </form>        
        "
    }

$titleBar = @"
<table style='margin-left:2%;margin-right:2%;width=70%'>
    <tr>
        <td style='width:20%'>
            $(Write-Link -Url '' -Button -Caption "<span style='font-size:large'>$blogName</span>")
        </td>
        <td style='width:50%;text-align:right'>
            $("<span style='font-size:medium;text-align:right'>$blogDescription</span>")
        </td>
        <td style='width:10%;text-align:right'>
        </td>
    </tr>
</table>

<br/>

<div style='text-align:right'>
    $rssButton 
    $shareButton
    $searchButton        
</div>

<br/>
<br/>
"@ | 
    New-Region -layerId Titlebar -AsWidget -CssClass clearfix, theme-group, corner-all -Style @{    
        "margin-top" = "1%"  
        "margin-left" = "12%"
        "margin-right" = "12%"    
    }
   
   
#region Generate output
$results = 
    if ($Request['Post']) { 
        #region Fetch a Specific Post
        $storageAccount = Get-WebConfigurationSetting -Setting $pipeworksManifest.Table.StorageAccountSetting
        $storageKey = Get-WebConfigurationSetting -Setting $pipeworksManifest.Table.StorageKeySetting
        $nameMatch  =([ScriptBLock]::Create("`$_.Name -eq '$($request['post'])'"))
        Search-AzureTable -Where $nameMatch -TableName $pipeworksManifest.Table.Name -StorageAccount $storageAccount -StorageKey $storageKey |
            ForEach-Object $unpackItem |
            ForEach-Object { 
                $_ | Out-HTML -ItemType http://schema.org/BlogPosting
            }           
        #endregion Fetch a Specific Post
    } elseif ($Request['Term']) {
        #region Look for a search term
        @"
<div id='OutputContainer' style='height:100%'>    
    Searching $($Module.Name) <progress max='100'> </progress>
</div>

<script>
    query = 'Module.ashx?Search=' + '$($Request['Term'])'
    `$(function() {
        `$.ajax({
            url: query,
            success: function(data){     
                `$('#OutputContainer').html(data);
            }, 
            error: function(data) {
                `$('#outputContainer').html("Post not found")
            }
        })
    })  
</script>
"@
        #endregion Look for a search term
    } else {
        #region Display the latest item

        $storageAccount = (Get-WebConfigurationSetting -Setting $pipeworksManifest.Table.StorageAccountSetting)
        $storageKey = (Get-WebConfigurationSetting -Setting $pipeworksManifest.Table.StorageKeySetting)                                                           

        Search-AzureTable -TableName $pipeworksManifest.Table.Name -Filter "PartitionKey eq '$partitionKey'" -Select Timestamp, DatePublished, PartitionKey, RowKey -StorageAccount $storageAccount -StorageKey $storageKey |
            Sort-Object -Descending {
                if ($_.DatePublished) {
                    [DateTime]$_.DatePublished
                } else {
                    [DateTime]$_.Timestamp
                }
            } |
            Select-Object -First 1 |
            Get-AzureTable -TableName $pipeworksManifest.Table.Name |
            ForEach-Object $UnpackItem |
            ForEach-Object { 
                $_ | Out-HTML -ItemType http://schema.org/BlogPosting
            }
        #endregion Display the latest item
    }             


$mainRegion ="
<div style='text-align:center'>
$($results |
    New-Region -layerId outputContent -Style @{
        "margin-left" = "2%"
        "margin-right" = "2%"
    })
</div> 
" | 
    New-Region -CssClass theme-group, ui-widget-content, clearfix -Style @{
        "margin-top" = "2%"  
        "margin-left" = "12%"
        "margin-right" = "12%"
        "min-height"='75%'    
    }



$adRegion = 
    if ($pipeworksManifest.AdSlot -and $pipeworksManifest.AdSenseId) {

        $adSenseId = $pipeworksManifest.AdSenseId
        $adslot = $pipeworksManifest.AdSlot
        @"
<br/>
<br/>
<script type='text/javascript'>
<!--
google_ad_client = 'ca-pub-$adSenseId';
/* AdSense Banner */
google_ad_slot = '$adslot';
google_ad_width = 728;
google_ad_height = 90;
//-->
</script>
<script type='text/javascript'
src='http://pagead2.googlesyndication.com/pagead/show_ads.js'>
</script>
"@     
    } else {
        ""
    }


$adRegion += 
    if ($pipeworksManifest.HidePipeworksBranding) {
""    
    } else {
@"
<br/>
<br/>
<div style='float:bottom'>
    <span style='font-size:xx-small'>Built with <a href='http://PowerShellPipeworks.com'>PowerShell Pipeworks</a>
</div>
"@    
    }

    

$advert = 
    $adRegion | 
        New-Region -Style @{
            "margin-top" = "1%"  
            "margin-left" = "12%"
            "margin-right" = "12%"
            "text-align" = "center" 
        }

$titleBar, $mainRegion, $advert |
        New-WebPage -Title $blogName -Rss @{
            $blogName = "Module.ashx?rss=$BlogName"
        } -UseJQueryUI

        }
        
        
        
$anyPage = {

    $storageAccount = (Get-WebConfigurationSetting -Setting $pipeworksManifest.Table.StorageAccountSetting)
    $storageKey = (Get-WebConfigurationSetting -Setting $pipeworksManifest.Table.StorageKeySetting)                                                           

    $originalUrl = $context.Request.ServerVariables["HTTP_X_ORIGINAL_URL"]

    $pathInfoUrl = $request.Url.ToString().Substring(0, $request.Url.ToString().LastIndexOf("/"))
            
        
        
    $pathInfoUrl = $pathInfoUrl.ToLower()
    $protocol = ($request['Server_Protocol'] -split '/')[0]  # Split out the protocol
    $serverName= $request['Server_Name']                     # And what it thinks it called the server

    $fullOriginalUrl = $protocol.ToLower() + "://" + $serverName + $request.Params["HTTP_X_ORIGINAL_URL"]
    
    $relativeUrl = $fullOriginalUrl.Replace("$pathInfoUrl", "")            
    
    
    
    if (-not $fullOriginalUrl) {
        "No Original URL"
        return    
    }
    $itemIdentifier = $relativeUrl -split "/" -ne ""
    $itemIdentifier = foreach ($i in $itemIdentifier) {
        [Web.httpUtility]::UrlDecode($i)
    }
    
    
    
    
    # If there's only one identifier, it's a post name
    # If there's two identifiers,
    # ... and the first ID is keyword, keywords, tag, tags, k, or t
    # ... and the first ID is posts, posts, names, name, p, or n
    # ... and the first ID is year or y
    # ... and the first ID is month or m
    # ... and the first ID is ID or i
    # ... or the posts are both numbers
    # ...... If one number has 4 digits, it's the year
    # If there's three identifiers
    # ... then treat them as year/month/day
    
    
    
        
    

    if ($itemIdentifier.Count) {
        $itemIdentifier
    } else {
        
        $selectItems = (@($itemSet.By) + "RowKey" + "Name") | Select-Object -Unique
        $tableItems = Search-AzureTable -TableName $pipeworksManifest.Table.Name -Filter "PartitionKey eq '$($itemSet.Partition)'" -StorageAccount $storageAccount -StorageKey $storageKey -Select $selectItems
        
        $depth = 0
        if ($request -and $request.Params["HTTP_X_ORIGINAL_URL"]) {
        
            $pathInfoUrl = $request.Url.ToString().Substring(0, $request.Url.ToString().LastIndexOf("/"))
            
            
            
            $pathInfoUrl = $pathInfoUrl.ToLower()
            $protocol = ($request['Server_Protocol'] -split '/')[0]  # Split out the protocol
            $serverName= $request['Server_Name']                     # And what it thinks it called the server

            $fullOriginalUrl = $protocol.ToLower() + "://" + $serverName + $request.Params["HTTP_X_ORIGINAL_URL"]
            
            $relativeUrl = $fullOriginalUrl.Replace("$pathInfoUrl", "")            
            
            if ($relativeUrl -like "*/*") {
                $depth = @($relativeUrl -split "/" -ne "").Count - 1
            } else {
                $depth  = 0
            }
            
        }
        
        
        
        foreach ($byTerm in $itemSet.By) {
            $tableItems |
                Sort-Object {
                    if ($_.DatePublished) {
                        [DateTime]$_.DatePublished 
                    } elseif ($_.Timestamp) {
                        [DateTime]$_.Timestamp
                    } 
                } -Descending | 
                Where-Object {
                    $_.$byTerm -like "*${itemIdentifier}*"
                } |
                ForEach-Object -Begin {
                    $popouts = @{}
                    $popoutUrls = @{}
                    
                    $order = @()
                } -Process {
                    $name = if ($_.Name) {
                        $_.Name
                    } else {
                        " " + ($order.Count + 1)
                    }
                    $popoutUrls[$name] = ("../" * $depth) + "Module.ashx?id=$($itemSet.Partition):$($_.RowKey)"
                    $popouts[$name] = " "
                    $order += $name
                } -End {
                    New-Region -LayerID InventoryItems -Order $order -Layer $popouts -LayerUrl $popoutUrls -AsPopout |
                        New-WebPage -Title "$($itemsetName) | $($itemIdentifier)" -UseJQueryUI 
                }
                
        }
           
    }



}
               
        
        
               
        @{
            "default.pspage" = "<| $blogPage |>"                         
            "${BlogName}.pspage" = "<| $blogPage |>"
            
        }                                   
    }        
} 
