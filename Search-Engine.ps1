function Search-Engine
{
    <#
    .Synopsis
        Searches the web, using various engines
    .Description
        Searches the web, using Bing or Google.        
    .Example
        Search-Engine "Start-Automating"
    .Example
        Search-Engine "Start-Automating" -Google

    .Notes
        Using Bing requires you to sign up for the Azure Data Market.  
        
        It is recommended that you use the default secure setting to store your data market key, AzureDataMarketAccountKey

        Using Google requires you sign up for the custom search api, and providing a custom search id
    .Link
        Get-Web

    #>
    [CmdletBinding(DefaultParameterSetName='Bing')]
    [OutputType([PSObject])]
    param(
    # The query
    [Parameter(Mandatory=$true,
        Position=0,
        ValueFromPipelineByPropertyName=$true,
        ValueFromPipeline=$true)]
    [string]
    $Query,


    # The query
    [Parameter(
        ParameterSetName='Bing',
        ValueFromPipelineByPropertyName=$true,
        ValueFromPipeline=$true)]
    [ValidateSet("Web", "Image", "Video", "News")]
    [string]
    $SearchService = "Web",

    
    # The Azure Data Market Key Or Setting
    [Parameter(ParameterSetName='Bing')]
    [string]
    $AzureDataMarketSetting = "AzureDataMarketAccountKey",


    # The Azure Data Market Key.  If this is not provided, then the AzureDataMarketSetting, or it's default value, will be used
    [Parameter(ParameterSetName='Bing')]
    [string]
    $AzureDataMarketAccountKey,

    # If set, will search using google
    [Parameter(Mandatory=$true,
        ParameterSetName='Google')]
    [Switch]
    $Google,

    # The Google Custom Search Api Key Setting.  This SecureSetting must contain the Google Search Api Key 
    [Parameter(ParameterSetName='Google')]
    [string]
    $GoogleCustomSearchSetting = "GoogleCustomSearchApiKey",


    # The Google Custom Search Api Key.  If this is not provided, then the AzureDataMarketSetting, or it's default value, will be used
    [Parameter(ParameterSetName='Google')]
    [string]
    $GoogleCustomSearchApiKey,


    # The Azure Data Market Key Or Setting
    [Parameter(ParameterSetName='Google')]
    [string]
    $GoogleCustomSearchIdSetting = "GoogleCustomSearchId",


    # The Azure Data Market Key.  If this is not provided, then the AzureDataMarketSetting, or it's default value, will be used
    [Parameter(ParameterSetName='Google')]
    [string]
    $GoogleCustomSearchId,


    # If set, will search using Wolfram|Alpha
    [Parameter(Mandatory=$true,
        ParameterSetName='WolframAlpha')]
    [Switch]
    $WolframAlpha,
    
    # The WolframAlpha pod state to return
    [Parameter(ParameterSetName='WolframAlpha')]
    [string]
    $PodState,
    
    # The PodID of interest
    [Parameter(ParameterSetName='WolframAlpha')]
    [string]
    $PodId,

    # The Wolfram|Alpha API Key
    [Parameter(ParameterSetName='WolframAlpha')]
    [string]
    $WolframAlphaAPiKey,

    # The Wolfram|Alpha API Key Setting
    [Parameter(ParameterSetName='WolframAlpha')]
    [string]
    $WolframAlphaAPiKeySetting,


    # If set, will run in the background
    [Switch]
    $AsJob,

    # If set, will always refetch the data
    [Switch]$Force         


    )

    begin {
        

        Set-StrictMode -Off
        Add-Type -AssemblyName System.Web
        if (-not ($script:CachedWolframAlphaSearchResults)) { 
            $script:CachedWolframAlphaSearchResults = @{}            
        }

        if (-not ($script:CachedGoogleSearchResults)) { 
            $script:CachedGoogleSearchResults = @{}            
        }


        if (-not ($script:CachedBingSearchResults)) { 
            $script:CachedBingSearchResults = @{}            
        }
    }

    process {
        if ($AsJob) {
            $myDefinition = [ScriptBLock]::Create("function Search-Engine {
$(Get-Command Search-Engine | Select-Object -ExpandProperty Definition)
}
")
            $null = $psBoundParameters.Remove('AsJob')            
            $myJob= [ScriptBLock]::Create("" + {
                param([Hashtable]$parameter) 
                
            } + $myDefinition + {
                
                Search-Engine @parameter
            }) 
            
            Start-Job -ScriptBlock $myJob -ArgumentList $psBoundParameters 
            return
        }

        if ($Google) {
            #region Google

            $gcsk = if ($GoogleCustomSearchApiKey) {
                $GoogleCustomSearchApiKey
            } else {
                if ($script:CachedGoogleCustomSearchKey) {
                    $script:CachedGoogleCustomSearchKey
                } else {
                    Get-SecureSetting -Name $GoogleCustomSearchSetting -ValueOnly
                }
                
            }

            $script:CachedGoogleCustomSearchKey = $gcsk

            $gcsi = if ($GoogleCustomSearchId) {
                $GoogleCustomSearchId
            } else {
                if ($script:CachedGoogleCustomSearchId) {
                    $script:CachedGoogleCustomSearchId
                } else {
                    Get-SecureSetting -Name $GoogleCustomSearchIdSetting -ValueOnly
                }
            }

            $script:CachedGoogleCustomSearchId = $gsci
            

            
            $result = if ($script:CachedGoogleSearchResults[$query] -and (-not $Force)) {
                $script:CachedGoogleSearchResults[$query]
            } else {                
                $script:CachedGoogleSearchResults[$query] = Get-Web -Url "https://www.googleapis.com/customsearch/v1?key=$gcsk&cx=$gcsi&q=$([Web.HttpUtility]::UrlEncode("$Query"))&alt=atom" -UseWebRequest
                $script:CachedGoogleSearchResults[$query]
            }                        

            if ($result) {
                $rx = [xml]$result
                foreach ($e in $rx.feed.entry) { 
                    $webPage = 
                        New-Object PSObject -Property @{
                            Url = $e.link.href;
                            Id=$e.cacheId;
                            Name=$e.title.'#text';
                            Description=$e.summary.'#text'                            
                        }

                    $webPage.pstypenames.clear()
                    $webPage.pstypenames.add('http://schema.org/WebPage')
                    $webPage
                } 
            }
            #endregion Google
        } elseif ($WolframAlpha) {
            #region Wolfram|Alpha
            $script:WolframAlphaWebClient = New-Object Net.WebClient
            $queryBase = "http://api.wolframalpha.com/v2/query?"
            $queryTerm = "input=$([Web.HttpUtility]::UrlEncode(($Query)).Replace('+', '%20'))" 
            if (-not $WolframAlphaAPIKey) {
                if ($script:CachedWolframAlphaApiKey) {
                    $WolframAlphaAPIKey = $script:CachedWolframAlphaApiKey
                } elseif ($WolframAlphaAPIKeySetting) {
                    $WolframAlphaAPIKey = Get-SecureSetting -Name $WolframAlphaAPIKeySetting  -ValueOnly
                }                                
            }

            if ($WolframAlphaAPIKey) {
                $script:CachedWolframAlphaApiKey = $WolframAlphaAPIKey
            }
                   
            $queryAPIKey = "appid=$script:CachedWolframAlphaApiKey"
            if ($psboundParameters.PodState) {
                $queryTerm+="&podstate=$podstate"
            }
            if ($psboundParameters.PodId) {
                $queryTerm+="&includepodid=$PodId"
            }

            $queryString = "${QueryBase}${QueryTerm}&${QueryAPIKey}"

            
            
            if ($location) {
                $queryString += "&location=$location"
            }
            
            
            if ($fromIP) {                
                $queryString += "&ip=$fromIP"
            }
            $result = if ($script:CachedWolframAlphaSearchResults[$queryString] -and (-not $Force)) {
                $script:CachedWolframAlphaSearchResults[$queryString]
            } else {                
                $script:CachedWolframAlphaSearchResults[$queryString] = $script:WolframAlphaWebClient.DownloadString($queryString)
                $script:CachedWolframAlphaSearchResults[$queryString]
            }
            $resultError = ([xml]$result).SelectSingleNode("//error")            
            if ($resultError) {            
                Write-Error -Message $resultError.msg -ErrorId "WolframAlphaWebServiceError$($resultError.Code)"    
                return
            }
            $pods = @{}
            
            Write-Verbose "$result"
                        

            $result | 
                Select-Xml //pod | 
                ForEach-Object  -Begin {
                    $psObject = New-Object PSObject
                } {        
                    $pod = $_.Node            
                    if ($pod.Id -eq 'Input') {
                        $psObject.psobject.Properties.Add(
                            (New-Object Management.Automation.PSNoteProperty "InputInterpretation","$($pod.subpod.plaintext)"
                        ))
                    }
                    
                    if ($pod.Id -ne 'Input') {
                        # Try and try and try
                        $textInPods = $pod.SubPod  |Select-Object -ExpandProperty plaintext
                        $textInPods = $textInPods -join ([Environment]::NewLine)
                        $lines = $textInPods.Split([Environment]::NewLine, [StringSplitOptions]'RemoveEmptyEntries')

                        $averageItemsPerLine = $lines | 
                            ForEach-Object {
                                $_.ToCharArray() |
                                    Where-Object {$_ -eq '|' } |
                                    Measure-Object
                            } | Measure-Object -Average -Property Count |
                            Select-Object -ExpandProperty Average
                            
                        if ($averageItemsPerLine -lt 1) {
                            if (-not $lines) {
                                $psNoteProperty = New-Object Management.Automation.PSNoteProperty $pod.Title, $pod.Subpod.img.src
                                $null = $psObject.psobject.Properties.Add($psNoteProperty)                            
                            } else {
                                $psNoteProperty = New-Object Management.Automation.PSNoteProperty $pod.Title, $lines
                                $null = $psObject.psobject.Properties.Add($psNoteProperty)                            
                            }
                            
                        } elseif ($averageItemsPerLine -ge 1 -and $averageItemsPerLine -lt 2) {
                            # It's probably a table of properties, but it could also be a result list
                            $outputObject = New-Object PSObject
                            $lastProperty = $null
                            foreach ($line in $lines) {
                                $chunks = @($line.Split('|', [StringSplitOptions]'RemoveEmptyEntries'))
                                # If it's greater than 1, treat it as a pair of values
                                
                                if ($chunks.Count -gt 1) {
                                    # Heading and value.                                    
                                    $lastProperty = $chunks[0]
                                    if ("$lastProperty".Trim()) {
                                        $value = $chunks[1] | 
                                            Where-Object {"$_".Trim() -notlike "(*)"}
                                        $outputObject | Add-Member NoteProperty $chunks[0] "$value".Trim() -Force
                                    }
                                } elseif ($chunks.Count -eq 1) {
                                    # Additional value
                                    $newValue = @($outputObject.$lastProperty) +  "$($chunks[0])".Trim()
                                    if ("$lastProperty".Trim()) {
                                        $outputObject | Add-Member NoteProperty $lastProperty $newValue -Force
                                    }
                                }
                            }
                            $psNoteProperty = New-Object Management.Automation.PSNoteProperty $pod.Title, $outputObject
                            $null = $psObject.psobject.Properties.Add($psNoteProperty)                            
                        } else {
                            # It's probably a table
                            
                            if ($lines.Count -eq 1) {
                                $itemValue, $itemSource = $lines[0] -split "[\(\)]"
                                
                                $outputObject =New-Object PSOBject |
                                    Add-Member NoteProperty Value $itemValue -PassThru | 
                                    Add-Member NoteProperty Source $itemSource -PassThru
                                $psNoteProperty = New-Object Management.Automation.PSNoteProperty $pod.Title, $outputObject    
                                $null = $psObject.psobject.Properties.Add($psNoteProperty)                            
                            } else {
                                $columns = $lines[0] -split "\|" | ForEach-Object {$_.Trim() } 
                                $rows = foreach ($l in $lines[1..($lines.Count -1)]) {    
                                    $l -split "\|" | ForEach-Object { $_.Trim() } 
                                }

                                $outputObject = 
                                    for ($i =0;$i -lt $rows.Count; $i+=$columns.Count) {
                                        $outputObject = New-Object PSObject 
                                        foreach ($n in 1..$columns.Count) {
                                            $columnName =
                                                if (-not $columns[$n -1]) {
                                                    "Name"
                                                } else {
                                                    $columns[$n -1]
                                                }
                                            $outputObject | 
                                                Add-Member NoteProperty $columnName ($rows[$i + $n - 1]) -Force
                                             
                                        }
                                        $outputObject 
                                    }
                                $psNoteProperty = New-Object Management.Automation.PSNoteProperty $pod.Title, $outputObject    
                                $null = $psObject.psobject.Properties.Add($psNoteProperty)                            
                            }
                        } 
                    }
                    
                    $pods[$pod.Id] = New-Object PSObject -Property @{
                        PodText = $pod.subpod | Select-Object -ExpandProperty plaintext -ErrorAction SilentlyContinue
                        PodImage = $pod.subpod | 
                            Select-Object -ExpandProperty img -ErrorAction SilentlyContinue |
                            Select-Object -ExpandProperty src
                        PodXml = $pod
                    }                    
                } -End {
                    $psObject.psobject.Properties.Add(
                        (New-Object Management.Automation.PSNoteProperty "OutputXml",([xml]$result)
                    ))
                    try {
                    $psObject.psObject.Properties.Add(
                        (New-Object Management.Automation.PSNoteProperty "Pods",(New-Object PSObject -Property $pods)
                    ))
                    } catch {
                    $psObject.psObject.Properties.Add(
                        (New-Object Management.Automation.PSNoteProperty "Pods", $null
                    ))    
                    }
                    $psObject.pstypenames.Clear()
                    $psObject.pstypenames.add('WolframAlphaResult')
                    $psObject
                    
                    
                }
            #endregion Wolfram|Alpha
        } else {
            #region Bing

            $admk = if ($AzureDataMarketAccountKey) {
                $AzureDataMarketAccountKey
            } else {
                if ($script:CachedAzureDataMarketAccountKey) {
                    $script:CachedAzureDataMarketAccountKey
                } elseif ($AzureDataMarketSetting) {
                    Get-SecureSetting -Name $AzureDataMarketSetting -ValueOnly
                } else {
                    ""
                }
            }

            $script:CachedAzureDataMarketAccountKey = $admk


            if ($admk) {
                $cred = New-Object Management.Automation.PSCredential $admk, (ConvertTo-SecureString -AsPlainText -Force "$admk")
            

                $result = 
                    if ($script:CachedBingSearchResults["${query}_${SearchService}"] -and (-not $Force)) {
                        $script:CachedBingSearchResults["${query}_${SearchService}"]
                    } else {                
                    

                        $script:CachedBingSearchResults["${query}_${SearchService}"] = Get-Web -Url "https://api.datamarket.azure.com/Bing/Search/${SearchService}?Query=%27$([Web.HttpUtility]::UrlEncode("$Query").Replace('+', '%20'))%27&Options=%27DisableLocationDetection%27" -WebCredential $cred -UseWebRequest 
                        $script:CachedBingSearchResults["${query}_${SearchService}"]
                    }
            
            } elseif ($SearchService -eq 'Web') {
                $result = 
                    if ($script:CachedBingSearchResults["${query}_${SearchService}"] -and (-not $Force)) {
                        $script:CachedBingSearchResults["${query}_${SearchService}"]
                    } else {                                    
                        $script:CachedBingSearchResults["${query}_${SearchService}"] = Get-Web -Url "http://www.bing.com/search?q=$([Web.HttpUtility]::UrlEncode("$Query").Replace('+', '%20'))&format=rss" -UseWebRequest 
                        $script:CachedBingSearchResults["${query}_${SearchService}"]
                    }
            }

             

            if ($result) {
                $rx = [xml]$result
                $feed=  $rx.feed
                $entries = if ($feed.Entry) {
                    foreach($e in $feed.entry) { $e } 
                } elseif ($rx.rss) {
                    foreach ($e in $rx.rss.channel.item) { $e }                     
                }

                foreach ($e in $entries) {
                    

                    if ($SearchService -eq 'Web') {
                        if ($admk) {
                            $webPage = New-Object PSObject -Property @{
                                Url = $e.content.properties.Url.'#text';
                                Id=$e.content.properties.ID.'#text';
                                Name=$e.content.properties.Title.'#text';
                                Description=$e.content.properties.Description.'#text'
                            }
                        } else {
                            $webPage = New-Object PSObject -Property @{
                                Url = $e.Link
                                Name=$e.Title
                                Description=$e.Description
                            }
                        }
                         

                        $webPage.pstypenames.clear()
                        $webPage.pstypenames.add('http://schema.org/WebPage')
                        $webPage
                    } elseif ($SearchService -eq 'Image') {
                        $image = New-Object PSObject -Property @{
                            Url = $e.content.properties.SourceUrl.'#text'
                            Image = $e.content.properties.MediaUrl.'#text';
                            Id=$e.content.properties.ID.'#text';
                            Name=$e.content.properties.Title.'#text';                            
                            Width =$e.content.properties.Width.'#text' -as [Double]                           
                            Height =$e.content.properties.Height.'#text' -as [Double]
                        }
                        
                        $image.pstypenames.clear()
                        $image.pstypenames.add('http://schema.org/ImageObject')
                        $image
                    } elseif ($SearchService -eq 'Video') {
                        $image = New-Object PSObject -Property @{
                            Url = $e.content.properties.MediaUrl.'#text'
                            Image = $e.content.properties.Thumbnail.MediaUrl.'#text';
                            Id=$e.content.properties.ID.'#text';
                            Name=$e.content.properties.Title.'#text';                            
                            
                        }
                        
                        $image.pstypenames.clear()
                        $image.pstypenames.add('http://schema.org/VideoObject')
                        $image
                    } elseif ($SearchService -eq 'News') {
                        $image = New-Object PSObject -Property @{
                            Url = $e.content.properties.MediaUrl.'#text'                            
                            Id=$e.content.properties.ID.'#text';
                            Name=$e.content.properties.Title.'#text';                            
                            Date=$e.content.properties.Date.'#text';                            
                            Publisher=$e.content.properties.Source.'#text';
                            Description=$e.content.properties.Description.'#text'                            
                        }
                        
                        $image.pstypenames.clear()
                        $image.pstypenames.add('http://schema.org/Article')
                        $image
                    } 
                }

            }
            

            #endregion Bing
        }
    }
}
