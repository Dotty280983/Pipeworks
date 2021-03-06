function Out-Zip
{
    <#
    .Synopsis
        Outputs files into a zip
    .Description
        Stores files in a zip archive
    .Example
        dir -recurse | Out-Zip -ZipFile ".\a.zip"
    .Example
        dir $home\Documents\WindowsPowerShell\Modules\Pipeworks -Recurse | 
            Out-Zip -ZipFile $home\Pipeworks.zip        
        Expand-Zip $home\Pipeworks.zip -OutputPath $psHome\Modules\Pipeworks
    .Link
        Expand-Zip
    #>
    
    [OutputType([IO.Fileinfo])]
    param(
    # The path to a file.
    [Parameter(Mandatory=$true,
        ParameterSetName='FileList',
        Position=0,
        ValueFromPipelineByPropertyName=$true)]
    [Alias('Fullname')]
    [string[]]$FilePath,
    
    # The output zip file
    [Parameter(Mandatory=$true,Position=1,ValueFromPipelineByPropertyName=$true)]
    [string]$ZipFile,
    
    # If set, will not show progress.  This improves performance and is good to include when calling this within another command.
    [Switch]$HideProgress,
    
    # The common root
    [string]$CommonRoot
    )
    
    begin {
    
        $zipFiles = New-Object Collections.ArrayList
        $fileList = New-Object Collections.ArrayList
        
        if (-not $script:cachedContentTypes) {
            $script:cachedContentTypes = @{}
            $ctKey = [Microsoft.Win32.Registry]::ClassesRoot.OpenSubKey("MIME\Database\Content Type")
            $ctKey.GetSubKeyNames() |
                ForEach-Object {
                    $extension= $ctKey.OpenSubKey($_).GetValue("Extension") 
                    if ($extension) {
                        $script:cachedContentTypes["${extension}"] = $_
                    }
                }

        }

        Add-Type -AssemblyName WindowsBase        
       
    }
    
    process {
        # Cool trick:  Skip piped in directories by looking @ $_, which will contain the full bound object
        if ($_.PSIsContainer) { return } 
        foreach ($f in $filePath) {
            if ($f) {
                $null = $fileList.Add($f)
            }
        }       
        
        
        if ($zipFile) {
            $null  = $zipFiles.Add($zipFile) 
        }
    }
    
    end {                
        if (-not $commonRoot) {
            $commonRoot = ""
        }
        
        foreach ($f in $fileList) {
            if (-not $commonRoot) {
                $commonRoot = $f.Substring(0, $f.LastIndexOf("\"))
                continue
            }
            
            if ($f -like "${commonRoot}*") {
                continue
            } else {
                while ($commonRoot -and $f -notlike "${CommonRoot}*") {
                    $commonRoot = try { $commonRoot.Substring(0, $commonRoot.LastIndexOf("\")) } catch { ""}
                }
            }                             
        }
       
        $bufferSize = 1kb
        $zipFiles = $zipFiles | Select-Object -Unique
        $progressId = Get-Random
        foreach ($zf in $zipFiles) {
            $fullzf = "$($ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($zf))"
            
            if (-not $fullZf) { return } 
            if (-not $HideProgress) {
                Write-Progress "Creating Zip: $fullZf" " " -PercentComplete 1 -Id $progressId
            }
            
            $package = [IO.Packaging.ZipPackage]::Open($fullzf, "Create", "ReadWrite")
            
            # $fileList = $fileList | Select-Object -First 1 
            $count = @($fileList).Count
            $n = 0
            foreach ($f in $fileList) {
                
                $rp = try { "$($ExecutionContext.SessionState.Path.GetResolvedPSPathFromPSPath($f))" } catch { }
                
                if ($rp) {
                    # Put the file in the package 
                    $extension = [IO.Path]::GetExtension($rp)
                    
                    $mimeType = $script:CachedContentTypes[$extension]
                    if (-not $mimeType) {
                        $mimetype = "unknown/unknown"
                    }
                    $uri = $rp.Replace($commonRoot, "").Replace("\", "/")
                    $uri = [Web.HttpUtility]::UrlEncode($uri) -replace 
                        "%2f", "/" -replace "%27", "'"
                    $packagePart = try {
                        $package.CreatePart($uri, $mimetype, "Maximum")
                    } catch {
                        Write-Error -Message "Could Not Pack up $uri" -TargetObject $_ -Exception $_.Exception 
                    }
                    $streamPart = New-Object IO.StreamWriter $packagePart.GetStream("Create","Write")
                    $perc = $n * 100 / $count
                    if (-not $HideProgress) {
                        Write-Progress "Creating Zip: $fullZf" "Reading $rp" -PercentComplete $perc -Id $progressId
                    }
                    
                    $fileBytes= [IO.File]::ReadAllBytes($rp)                    

                    if (-not $HideProgress) {                    
                        Write-Progress "Creating Zip: $fullZf" "Compressing $rp" -PercentComplete $perc -Id $progressId
                    }
                    $write=  $streamPart.basestream.Write($fileBytes, 0, $fileBytes.Count)
                    
                    $streamPart.Close()
                    $package.Flush()

                }
                $n++
                
            }
            
            $package.Close()        
            if (-not $HideProgress) {
                Write-Progress "Creating Zip" "Completed" -Completed -Id $progressId
            }
            
         
            
        }
        
        
        
        
    }
}