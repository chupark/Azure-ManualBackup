function getValidator() {
    return [validator]::new()
}

Class validator {
    [Array]$parameters
    [Array]$inputParameters
    
    [bool]validation([PSCustomObject]$inputParam) {
        if(!$this.parameters) {
            return $false
        } elseif(!$inputParam) {
            return $false
        }
        foreach ($param in $inputParam) {
            if ($this.parameters | Where-Object {$_ -eq $param}) {
            } else {
                return $false
            }
        }
        return $true
    }

    setInputParameters([PSCustomObject]$inputObject) {
        $this.inputParameters = (($inputObject | Get-Member) | Where-Object {$_.MemberType -eq "NoteProperty"}).Name
    }

    setParameters([Array]$setParam) {
        $this.parameters = $setParam
    }

    [Array]getInputParameters() {
        return $this.inputParameters
    }

    [Array]getParameters() {
        return $this.parameters
    }
}