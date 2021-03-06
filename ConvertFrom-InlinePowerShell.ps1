function ConvertFrom-InlinePowerShell
{
    #
    #.Synopsis
    #    Converts PowerShell inlined within HTML to ASP.NET
    #.Description
    #    Converts PowerShell inlined within HTML to ASP.NET.
    #    
    #    PowerShell can be embedded with <| |> or <psh></psh> or <?psh  ?>
    #.Example
    #    ConvertFrom-InlinePowerShell -PowerShellAndHTML "<h1><| 'hello world' |></h1>"
    #.Link
    #    ConvertTo-ModuleService
    #.Link
    #    ConvertTo-CommandService
    [CmdletBinding(DefaultParameterSetName='PowerShellAndHTML')]
    [OutputType([string])]
    param(
    # The filename 
    [Parameter(Mandatory=$true,
        ParameterSetName='FileName',
        ValueFromPipelineByPropertyName=$true)]
    [Alias('Fullname')]
    [ValidateScript({$ExecutionContext.SessionState.Path.GetResolvedPSPathFromPSPath($_)})]
    [string]$FileName,    
    # A mix of HTML and PowerShell.  PowerShell can be embedded with <| |> or <psh></psh> or <?psh  ?>
    #|LinesForInput 20
    [Parameter(Mandatory=$true,
        Position=0,
        ParameterSetName='PowerShellAndHtml',
        ValueFromPipelineByPropertyName=$true)]
    [string]$PowerShellAndHtml,
    
    # If set, the page generated will include this page as the ASP.NET master page
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [string]$MasterPage,

    # If set, will use a code file for the generated ASP.NET page.
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [string]$CodeFile,

    # If set, will inherit the page from a class name
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [string]$Inherit,

    # The method that will be used to run scripts in ASP.NET.  If nothing is specified, runScript    
    [string]$RunScriptMethod = 'runScript'
    )        
    
    process {
        if ($psCmdlet.ParameterSetName -eq 'FileName') {            
            if ($fileName -like "*.ps1") {
                $PowerShellAndHtml = [IO.File]::ReadAllText($ExecutionContext.SessionState.Path.GetResolvedPSPathFromPSPath($FileName))            
                $PowerShellAndHtml = $PowerShellAndHtml -ireplace "<|", "&lt;|" -ireplace "|>", "|&gt;"
                $powerShellAndHtml = "<| $PowerShellAndHtml |>"
            } else {
                $PowerShellAndHtml = [IO.File]::ReadAllText($ExecutionContext.SessionState.Path.GetResolvedPSPathFromPSPath($FileName))            
            }                        
        }
        
        # First, try treating it as data language.  If it's data language, then use the parser to pick out the comments
        $dataLanguageResult = try {
            $asScriptBlock = [ScriptBlock]::Create($PowerShellAndHtml)
            $asDataLanguage = & ([ScriptBlock]::Create("data { $asScriptBlock }"))            
        } catch {
            Write-Verbose "Could not convert into script block: $($_ | Out-string)"            
        }
        
        
        if ($dataLanguageResult) {
            # Use the tokenizer!
        } else {
            # Change the tags
            $powerShellAndHtml  = $powerShellAndHtml -ireplace 
                "\<psh\>", "<|" -ireplace
                "\</psh\>", "|>" -ireplace
                "\<\?posh\>", "<|" -ireplace
                "\<\?psh", "<|" -ireplace
                "\?>", "|>" 
                
            
            $start = 0
            

            $loopCount = 0

            $powerShellAndHtmlList = do {             
                if ($loopCount -ge 3) { break }    
                $found = $powerShellAndHtml.IndexOf("<|", $start)
                if ($found -eq -1) { $loopCount++; continue }                                
                # emite the chunk before the found section
                $powershellAndHtml.Substring($start, $found - $start)
                $endFound = $powerShellAndHtml.IndexOf("|>", $found)                
                if ($endFound -eq -1) { $loopCount++; continue }                
                $scriptToBe = $powerShellAndHtml.Substring($found + 2, $endFound - $found - 2)                
                $scriptToBe = $scriptToBe.Replace("&lt;|", "<|").Replace("|&gt;", "|>")
                $scriptToBe = [ScriptBLock]::Create($scriptToBe)
                if (-not $?) { 
                    break 
                }                
                $embed = "`$lastCommand = { $scriptToBe }
                if (`$module) { . `$module `$LastCommand | Out-Html} else {
                    . `$lastCommand | Out-HTML
                } ".Replace('"','""')
                

                "$(if ($MasterPage) { '<asp:Content runat="server">' } else {'<%' }) ${RunScriptMethod}(@`"$embed`"); $(if ($MasterPage) { '</asp:Content>' } else {'%>'})"                
                $start = $endFound + 2
            } while ($powerShellAndHtml.IndexOf("<|", $start) -ne -1)
            
            $powerShellAndHtml = ($powerShellAndHtmlList -join '') + $powerShellAndHtml.Substring($start)
            
            $Params = @{Text=$powerShellAndHtml }
            if ($masterPage) {
                $Params.masterPage = $masterPage                
                $params.NoBootstrapper = $true
            }

            if ($CodeFile) {
                $Params.CodeFile = $CodeFile                
                $params.NoBootstrapper = $true
            }

            if ($inherit) {
                $Params.Inherit = $Inherit
                $params.NoBootstrapper = $true
            }
            Write-AspDotNetScriptPage @params 
        }        
    }
} 
