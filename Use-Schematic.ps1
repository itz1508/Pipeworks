 function Use-Schematic
{
    <#
    .Synopsis
        Uses a schematic to put things together
    .Description
        Uses a schematic to automate the deployment
    .Link
        ConvertTo-ModuleService
    #>
    param(
    # The name of the schematic
    [Parameter(Mandatory=$true,Position=0)]
    [string]
    $SchematicName,
    
    # The name of the module that the schematic will be used on.  
    # This will also determine the default input and output directories
    [Parameter(Position=1,ValueFromPipelineByPropertyName=$true)]
    [Alias('Name')]
    [string]
    $ModuleName,

    # Parameters to the schematic.  
    # These will be merged with any parameters provided from the module.
    [Parameter(Position=2,ValueFromPipelineByPropertyName=$true)]
    [Hashtable]
    $Parameter,

    # A complete pipeworks manifest.
    # This will be merged with the pipeworks manifest from the module, if a module is provided
    [Parameter(Position=3,ValueFromPipelineByPropertyName=$true)]
    [Hashtable]
    $Manifest,

    # A custom output directory.  
    # This will override the default module output directory (the module path).
    # If no module is provided, the current directory will be used as the input directory.
    [Parameter(Position=4,ValueFromPipelineByPropertyName=$true)]
    [string]
    $InputDirectory,

    # A custom output directory.  
    # This will override the default module output directory (\inetpub\wwwroot\ModuleName)
    # If no module is provided, the output directory will default to \inetpub\wwwroot 
    [Parameter(Position=5,ValueFromPipelineByPropertyName=$true)]
    [string]
    $OutputDirectory        
    )


    process {
        
        $MypipeworksManifest  = @{}

        if ($ModuleName) {
            $module = $realModule = Get-Module $moduleName
            if (-not $realModule) { return } 

            # Import pipeworks manifest
            $moduleRoot = Split-Path $realModule.Path                     
            #region Initialize Pipeworks Manifest
            $pipeworksManifestPath = Join-Path $moduleRoot "$($realmodule.Name).Pipeworks.psd1"
            $MypipeworksManifest  = if (Test-Path $pipeworksManifestPath) {
                try {                     
                    & ([ScriptBlock]::Create(
                        "data -SupportedCommand Add-Member, New-WebPage, New-Region, Write-CSS, Write-Ajax, Out-Html, Write-Link { $(
                            [ScriptBlock]::Create([IO.File]::ReadAllText($pipeworksManifestPath))                    
                        )}"))            
                } catch {
                    Write-Error "Could not read pipeworks manifest" 
                    return
                }                                                
            }



            if (-not $PSBoundParameters.InputDirectory) {
                $inputDirectory = $moduleRoot
            }

            if (-not $PSBoundParameters.OutputDirectory) {
                $OutputDirectory = "$Env:SystemDrive\inetpub\wwwroot\$($realModule.Name)"
            }
            
        }

        if ($manifest) {
            foreach ($kv in $Manifest.GetEnumerator()) {
                $MypipeworksManifest[$kv.Key] = $kv.Value
            }
        }

        if ($parameter) {
            if (-not $MyPipewokrsManifest["$parameter"]) {
                $MyPipeworksManifest["$Parameter"]
            }
        }

        if (-not $inputDirectory) {
            $inputDirectory = "$pwd"
        }

        if (-not $OutputDirectory) {
            $outputDirectory = "$Env:SystemDrive\inetpub\wwwroot"
        }

        $schematic = $SchematicName
        $moduleList =  
            if ($realModule ) {
                (@($realModule) + @($Realmodule.RequiredModules) + @(Get-Module Pipeworks))
            } else {
                @(Get-Module Pipeworks)
            }

        $moduleList  =  $moduleList  | Select-Object -Unique
        foreach ($moduleInfo in $moduleList  ) {
            $thisModuleDir = $moduleInfo | Split-Path
            $schematics = "$thisModuleDir\Schematics\$Schematic\" | Get-ChildItem -Filter "Use-*Schematic.ps1" -ErrorAction SilentlyContinue
            foreach ($s in $schematics) {
                if (-not $s) { continue } 
                if (-not $mypipeworksManifest.$schematic) {
                    Write-Error "Missing $schematic schematic parameters for $($realmodule.Name)"
                    continue
                }
                $pagesToMerge = & {                            
                    . $s.Fullname
                    $schematicCmd = 
                        Get-Command -Verb Use -Noun *Schematic | 
                        Where-Object {$_.Name -ne 'Use-Schematic'} | 
                        Select-Object -First 1 
                        
                    $schematicParameters = @{
                        Parameter = $mypipeworksManifest.$schematic
                        Manifest = $myPipeworksManifest 
                        DeploymentDirectory = $outputDirectory 
                        inputDirectory = $inputDirectory
                    }
                    if ($schematicCmd.Name) {
                        & $schematicCmd @schematicParameters
                        Remove-Item "function:\$($schematicCmd.Name)"
                    }
                }
                    
                if ($pagesToMerge) {
                    foreach ($kv in $pagesToMerge.GetEnumerator()) {
                        $MypipeworksManifest.pages[$kv.Key] = $kv.Value
                    }                   
                }
            }                    
        }
                        
        #region Pages
        $IsolateRunspace = $true
        $PoolSize = 1
        #If the manifest declares additional web pages, create a page for each item
        if ($MyPipeworksManifest.Pages -and 
            $MyPipeworksManifest.Pages.GetType() -eq [Hashtable] ) {
            $codeBehind = @"
using System;
using System.Web.UI;
using System.Management.Automation;
using System.Management.Automation.Runspaces;
using System.Collections;
using System.Collections.ObjectModel;
public partial class PowerShellPage : Page {
    public InitialSessionState InitializeRunspace() {
        InitialSessionState iss = InitialSessionState.CreateDefault();
        $embedSection
        string[] commandsToRemove = new String[] { "$($functionBlacklist -join '","')"};
        foreach (string cmdName in commandsToRemove) {
            iss.Commands.Remove(cmdName, null);
        }
        return iss;
    }
    public void RunScript(string script) {
        bool shareRunspace = $((-not $IsolateRunspace).ToString().ToLower());
        UInt16 poolSize = $PoolSize;
        PowerShell powerShellCommand = PowerShell.Create();
        bool justLoaded = false;
        PSInvocationSettings invokeNoHistory = new PSInvocationSettings();
        invokeNoHistory.AddToHistory = false;
        Collection<PSObject> results;
        if (shareRunspace) {
            if (Application["RunspacePool"] == null) {                        
                justLoaded = true;
                
                RunspacePool rsPool = RunspaceFactory.CreateRunspacePool(InitializeRunspace());
                rsPool.SetMaxRunspaces($PoolSize);
                
                rsPool.ApartmentState = System.Threading.ApartmentState.STA;            
                rsPool.ThreadOptions = PSThreadOptions.ReuseThread;
                rsPool.Open();                                
                powerShellCommand.RunspacePool = rsPool;
                Application.Add("RunspacePool",rsPool);
                
                // Initialize the pool
                Collection<IAsyncResult> resultCollection = new Collection<IAsyncResult>();
                for (int i =0; i < $poolSize; i++) {
                    PowerShell execPolicySet = PowerShell.Create().
                        AddScript(@"
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force 
`$pulseTimer = New-Object Timers.Timer -Property @{
    #Interval = ([Timespan]'$pulseInterval').TotalMilliseconds
}


Register-ObjectEvent -InputObject `$pulseTimer -EventName Elapsed -SourceIdentifier PipeworksPulse -Action {        
    `$global:LastPulse = Get-Date        
    
}
`$pulseTimer.Start()



", false);
                    execPolicySet.RunspacePool = rsPool;
                    resultCollection.Add(execPolicySet.BeginInvoke());
                }
                
                foreach (IAsyncResult lastResult in resultCollection) {
                    if (lastResult != null) {
                        lastResult.AsyncWaitHandle.WaitOne();
                    }
                }
                
                powerShellCommand.Commands.Clear();
            }
            
            
                        
            
            powerShellCommand.RunspacePool = Application["RunspacePool"] as RunspacePool;
            
            
            
            string newScript = @"param(`$Request, `$Response, `$Server, `$session, `$Cache, `$Context, `$Application, `$JustLoaded, `$IsSharedRunspace, [Parameter(ValueFromRemainingArguments=`$true)]`$args)
            if (`$request -and `$request.Params -and `$request.Params['PATH_TRANSLATED']) {
                Split-Path `$request.Params['PATH_TRANSLATED'] |
                    Set-Location
            }
            
            " + script;            
            powerShellCommand.AddScript(newScript, false);
                       
            
            powerShellCommand.AddParameter("Request", Request);
            powerShellCommand.AddParameter("Response", Response);
            powerShellCommand.AddParameter("Session", Session);
            powerShellCommand.AddParameter("Server", Server);
            powerShellCommand.AddParameter("Cache", Cache);
            powerShellCommand.AddParameter("Context", Context);
            powerShellCommand.AddParameter("Application", Application);
            powerShellCommand.AddParameter("JustLoaded", justLoaded);
            powerShellCommand.AddParameter("IsSharedRunspace", true);
            results = powerShellCommand.Invoke();        
        
        } else {
            Runspace runspace;
            if (Session["UserRunspace"] == null) {
                
                Runspace rs = RunspaceFactory.CreateRunspace(InitializeRunspace());
                rs.ApartmentState = System.Threading.ApartmentState.STA;            
                rs.ThreadOptions = PSThreadOptions.ReuseThread;
                rs.Open();
                powerShellCommand.Runspace = rs;
                powerShellCommand.
                    AddCommand("Set-ExecutionPolicy", false).
                    AddParameter("Scope", "Process").
                    AddParameter("ExecutionPolicy", "Bypass").
                    AddParameter("Force", true).
                    Invoke(null, invokeNoHistory);
                powerShellCommand.Commands.Clear();

                Session.Add("UserRunspace",rs);
                justLoaded = true;
            }

            runspace = Session["UserRunspace"] as Runspace;

            if (Application["Runspaces"] == null) {
                Application["Runspaces"] = new Hashtable();
            }
            if (Application["RunspaceAccessTimes"] == null) {
                Application["RunspaceAccessTimes"] = new Hashtable();
            }
            if (Application["RunspaceAccessCount"] == null) {
                Application["RunspaceAccessCount"] = new Hashtable();
            }

            Hashtable runspaceTable = Application["Runspaces"] as Hashtable;
            Hashtable runspaceAccesses = Application["RunspaceAccessTimes"] as Hashtable;
            Hashtable runspaceAccessCounter = Application["RunspaceAccessCount"] as Hashtable;
            
            
            if (! runspaceTable.Contains(runspace.InstanceId.ToString())) {
                runspaceTable[runspace.InstanceId.ToString()] = runspace;
            }

            if (! runspaceAccessCounter.Contains(runspace.InstanceId.ToString())) {
                runspaceAccessCounter[runspace.InstanceId.ToString()] = 0;
            }
            runspaceAccessCounter[runspace.InstanceId.ToString()] = ((int)runspaceAccessCounter[runspace.InstanceId.ToString()]) + 1;
            runspaceAccesses[runspace.InstanceId.ToString()] = DateTime.Now;


            runspace.SessionStateProxy.SetVariable("Request", Request);
            runspace.SessionStateProxy.SetVariable("Response", Response);
            runspace.SessionStateProxy.SetVariable("Session", Session);
            runspace.SessionStateProxy.SetVariable("Server", Server);
            runspace.SessionStateProxy.SetVariable("Cache", Cache);
            runspace.SessionStateProxy.SetVariable("Context", Context);
            runspace.SessionStateProxy.SetVariable("Application", Application);
            runspace.SessionStateProxy.SetVariable("JustLoaded", justLoaded);
            runspace.SessionStateProxy.SetVariable("IsSharedRunspace", false);
            powerShellCommand.Runspace = runspace;


        
            powerShellCommand.AddScript(@"
`$timeout = (Get-Date).AddMinutes(-20)
`$oneTimeTimeout = (Get-Date).AddMinutes(-1)
foreach (`$key in @(`$application['Runspaces'].Keys)) {
    if ('Closed', 'Broken' -contains `$application['Runspaces'][`$key].RunspaceStateInfo.State) {
        `$application['Runspaces'][`$key].Dispose()
        `$application['Runspaces'].Remove(`$key)
        continue
    }
    
    if (`$application['RunspaceAccessTimes'][`$key] -lt `$Timeout) {
        
        `$application['Runspaces'][`$key].CloseAsync()
        continue
    }    
}
            ").Invoke(null, invokeNoHistory);
            powerShellCommand.Commands.Clear();        

            powerShellCommand.AddCommand("Split-Path", false).AddParameter("Path", Request.ServerVariables["PATH_TRANSLATED"]).AddCommand("Set-Location").Invoke(null, invokeNoHistory);
            powerShellCommand.Commands.Clear();        

            results = powerShellCommand.AddScript(script, false).Invoke();        

        }
            
        
        foreach (Object obj in results) {
            if (obj != null) {
                if (obj is IEnumerable) {
                    if (obj is String) {
                        Response.Write(obj);
                    } else {
                        IEnumerable enumerableObj = (obj as IEnumerable);
                        foreach (Object innerObject in enumerableObj) {
                            if (innerObject != null) {
                                Response.Write(innerObject);
                            }
                        }
                    }
                    
                } else {
                    Response.Write(obj);
                }
                    
            }
        }
        
        foreach (ErrorRecord err in powerShellCommand.Streams.Error) {
            Response.Write("<span class='ErrorStyle' style='color:red'>" + err + "<br/>" + err.InvocationInfo.PositionMessage + "</span>");
        }

        powerShellCommand.Dispose();
    
    }
}
"@ | 
            Set-Content "$outputDirectory\PowerShellPageBase.cs"
            $null = $codeBehind
            foreach ($pageAndContent in $MyPipeworksManifest.Pages.GetEnumerator()) {
                
                $pageName = $pageAndContent.Key 
                Write-Progress "Creating Pages" "$pageName"
                $safePageName = $pageName.Replace("|", " ").Replace("/", "-").Replace(":","-").Replace("!", "-").Replace(";", "-").Replace(" ", "_").Replace("@","at")
                $pageContent = $pageAndContent.Value
                $realPageContent = 
                    if ($pageContent -is [Hashtable]) {                    
                        if (-not $pageContent.Css -and $MypipeworksManifest.Style) {
                            $pageContent.Css = $MypipeworksManifest.Style
                        }
                        if ($pageContent.PageContent) {
                            $pageContent.PageContent = try { [ScriptBlock]::Create($pageContent.PageContent) } catch {}                                                         
                        }
                        if ($hasPosts) {
                            # If there are posts, add a link to the feed to all pages
                            $pageContent.Rss = @{
                                "$($Module.Name) Blog" = "$($module.Name).xml"
                            }
                        }
                        
                        # Pass down the analytics ID to the page if one is not explicitly set
                        if (-not $pageContent.AnalyticsId -and $analyticsId) {
                            $pageContent.AnalyticsId = $analyticsId
                        }
                        New-WebPage @pageContent
                    } elseif ($pageContent -like ".\*.pspg" -or $pageName -like "*.pspg" -or $pageName -like "*.pspage"){
                        # .PSPages.  These are mixed syntax HTML and Powershell inlined in markup <| |>  
                        # Because they are loaded within the moudule, a PSPAge will contain $embedCommand, which imports the module
                        if ($pageContent -notlike ".\*.pspg" -and $pageContent -notlike ".\*.pspage") {
                            # the content isn't a filepath, so treat it as inline code 
                            $wholePageContent = "<| $embedCommand |>" + $pageContent                           
                            ConvertFrom-InlinePowerShell -PowerShellAndHtml $wholePageContent -RunScriptMethod this.RunScript -CodeFile PowerShellPageBase.cs -Inherit PowerShellPage | 
                                Add-Member NoteProperty IsPsPage $true -PassThru
                        } else {
                            # The content is a path, treat it like one
                            $pagePath = Join-Path $moduleRoot $pageContent.TrimStart(".\")
                            if (Test-Path $pagePath) {
                                $pageContent = [IO.File]::ReadAllText($pagePath)
                                $wholePageContent = "<| $embedCommand |>" + $pageContent 
                                ConvertFrom-InlinePowerShell -PowerShellAndHtml $wholePageContent -CodeFile PowerShellPageBase.cs -Inherit PowerShellPage   | 
                                    Add-Member NoteProperty IsPsPage $true -PassThru
                            }         
                        }
                    } elseif ($pageName -like "*.*" -and $pageContent -as [Byte[]]) {
                        # Path to item
                        $itemPath = Join-Path $outputDirectory $pageName.TrimStart(".\")
                        $parentPath = $itemPath | Split-Path
                        if (-not (Test-Path "$parentPath")) {
                            $null = New-Item -ItemType Directory -Path "$parentPath"
                        }
                        [IO.File]::WriteAllBytes("$itemPath", $pageContent)
                    } elseif ($pageContent -like ".\*.htm*"){
                        # .HTML files
                        $pagePath = Join-Path $moduleRoot $pageContent.TrimStart(".\")
                        if (Test-Path $pagePath) {
                            try {
                                $potentialPagecontent = [IO.File]::ReadAllText($pagePath)                                
                                $pageContent = $potentialPagecontent 
                            } catch {
                                $_ | Write-Error
                            }
                        }
                    } else {
                        $pageContentAsScriptBlock = try { [ScriptBlock]::Create($pageContent) } catch { } 
                        if ($pageContentAsScriptBlock) {
                            & $pageContentAsScriptBlock
                        } else {
                            $pageContent
                        }
                    }
                
              
                
                if ($realPageContent.IsPsPage) {
                    $safePageName = $safePageName.Replace(".pspage", "").Replace(".pspg", "")
                    $parentPath = $safePageName | Split-Path
                    if (-not (Test-Path "$outputDirectory\$parentPath")) {
                        $null = New-Item -ItemType Directory -Path "$outputDirectory\$parentPath"
                    }
                    $realPageContent | 
                        Set-Content "$outputDirectory\${safepageName}.aspx"
                } else {
                    # Output the bytes
                    $parentPath = $safePageName | Split-Path
                    if (-not (Test-Path "$outputDirectory\$parentPath")) {
                        $null = New-Item -ItemType Directory -Path "$outputDirectory\$parentPath"
                    }
                    if ($pageContent -as [Byte[]]) {
                        [IO.File]::WriteAllBytes("$outputDirectory\$($pageName)", $pageContent)
                    } else {
                        [IO.File]::WriteAllText("$outputDirectory\$($pageName)", $pageContent)
                    }
                    <#                    
                    $safePageName = $safePageName.Replace(".html", "").Replace(".htm", "")
                    $parentPath = $safePageName | Split-Path
                    if (-not (Test-Path "$outputDirectory\$parentPath")) {
                        $null = New-Item -ItemType Directory -Path "$outputDirectory\$parentPath"
                    }
                    $realPageContent | 
                        Set-Content "$outputDirectory\${safepageName}.html"
                    #>
                }
            }            
        }
        #endregion Pages                        
    }       
}
