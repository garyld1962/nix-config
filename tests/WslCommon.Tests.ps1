BeforeAll {
    . (Join-Path $PSScriptRoot '..\scripts\wsl-common.ps1')
    $script:Mirrored = @(
        '# Settings apply across all Linux distros running on WSL 2', '[wsl2]', '',
        '# Limits VM memory to use no more than 4 GB, this can be set as whole numbers using GB or MB',
        'memory=48GB', '', '# Sets the VM to use two virtual processors', 'processors=24', '', '',
        '# Sets amount of swap storage space to 8GB, default is 25% of available RAM', 'swap=16GB', '',
        '# Sets swapfile path location, default is %UserProfile%\AppData\Local\Temp\swap.vhdx', '', '',
        '# Turn on default connection to bind WSL 2 localhost to Windows localhost. Setting is ignored when networkingMode=mirrored',
        '#localhostforwarding=true', '', '# Disables nested virtualization', 'nestedVirtualization=false', '',
        '# Turns on output console showing contents of dmesg when opening a WSL 2 distro for debugging', 'debugConsole=false', '',
        '# Sets the maximum number of crash dump files to retain (default is 5)', 'maxCrashDumpCount=10', 'networkingMode=Mirrored', '',
        '# Enable experimental features', '[experimental]', 'sparseVhd=true', 'autoMemoryReclaim=gradual'
    ) -join "`r`n"
}

Describe 'Test-UbuntuUsername' {
    It 'accepts <Name>' -TestCases @(@{ Name = 'gary' }, @{ Name = 'dev_user' }, @{ Name = 'a1' }) {
        Test-UbuntuUsername $Name | Should -BeTrue
    }
    It 'rejects <Name>' -TestCases @(
        @{ Name = 'Root' }, @{ Name = '1abc' }, @{ Name = 'with space' }, @{ Name = 'root' }, @{ Name = ('a' * 33) }, @{ Name = '' }
    ) {
        Test-UbuntuUsername $Name | Should -BeFalse
    }
}

Describe 'Merge-WslConfigMirrored' {
    BeforeEach { $path = Join-Path $TestDrive "$([guid]::NewGuid())\.wslconfig"; New-Item -ItemType Directory -Path (Split-Path $path) | Out-Null }

    It 'creates the file when absent' {
        Merge-WslConfigMirrored $path | Should -BeTrue
        [IO.File]::ReadAllLines($path) | Should -Be @('[wsl2]', 'networkingMode=mirrored')
    }
    It 'leaves this machine''s file unchanged' {
        [IO.File]::WriteAllText($path, $script:Mirrored)
        Merge-WslConfigMirrored $path | Should -BeFalse
        [IO.File]::ReadAllText($path) | Should -BeExactly $script:Mirrored
    }
    It 'replaces another value in place keeping every other line' {
        [IO.File]::WriteAllText($path, "[wsl2]`r`nmemory=4GB`r`nnetworkingMode = NAT `r`n[experimental]`r`nsparseVhd=true")
        Merge-WslConfigMirrored $path | Should -BeTrue
        [IO.File]::ReadAllLines($path) | Should -Be @('[wsl2]', 'memory=4GB', 'networkingMode=mirrored', '[experimental]', 'sparseVhd=true')
    }
    It 'adds the key when [wsl2] has none' {
        [IO.File]::WriteAllText($path, "[wsl2]`nmemory=4GB`n[experimental]`nsparseVhd=true")
        Merge-WslConfigMirrored $path | Should -BeTrue
        [IO.File]::ReadAllLines($path) | Should -Be @('[wsl2]', 'networkingMode=mirrored', 'memory=4GB', '[experimental]', 'sparseVhd=true')
    }
    It 'appends the section when absent' {
        [IO.File]::WriteAllText($path, "[experimental]`nsparseVhd=true")
        Merge-WslConfigMirrored $path | Should -BeTrue
        [IO.File]::ReadAllLines($path) | Should -Be @('[experimental]', 'sparseVhd=true', '', '[wsl2]', 'networkingMode=mirrored')
    }
    It 'treats a commented key as absent' {
        [IO.File]::WriteAllText($path, "[wsl2]`n#networkingMode=nat")
        Merge-WslConfigMirrored $path | Should -BeTrue
        [IO.File]::ReadAllLines($path) | Should -Be @('[wsl2]', 'networkingMode=mirrored', '#networkingMode=nat')
    }
    It 'does not touch networkingMode outside [wsl2]' {
        [IO.File]::WriteAllText($path, "[experimental]`nnetworkingMode=nat")
        Merge-WslConfigMirrored $path | Should -BeTrue
        [IO.File]::ReadAllLines($path) | Should -Be @('[experimental]', 'networkingMode=nat', '', '[wsl2]', 'networkingMode=mirrored')
    }
}

Describe 'Get-WslConfigNetworkingMode' {
    It 'returns the value inside [wsl2] with surrounding whitespace removed' {
        Get-WslConfigNetworkingMode -Lines @('[wsl2]', 'networkingMode = NAT ', '[experimental]') | Should -BeExactly 'NAT'
    }
    It 'returns the value from this machine''s file' {
        Get-WslConfigNetworkingMode -Lines ($script:Mirrored -split "`r`n") | Should -BeExactly 'Mirrored'
    }
    It 'returns null when <Case>' -TestCases @(
        @{ Case = 'the key is outside [wsl2]'; Lines = @('[experimental]', 'networkingMode=mirrored') },
        @{ Case = 'the key is commented'; Lines = @('[wsl2]', '#networkingMode=mirrored') },
        @{ Case = 'there is no file content'; Lines = @() }
    ) {
        Get-WslConfigNetworkingMode -Lines $Lines | Should -BeNullOrEmpty
    }
}

Describe 'Get-Sha256SumsEntry' {
    BeforeAll {
        $script:Image = 'ubuntu-26.04.1-wsl-amd64.wsl'
        $script:Lines = @(
            "$('a' * 64) *$script:Image",
            "$('b' * 64) *$script:Image.zsync",
            "$('c' * 64) *ubuntu-26.04.1-wsl-arm64.wsl"
        )
    }
    It 'returns the single matching hash' {
        Get-Sha256SumsEntry -Lines $script:Lines -FileName $script:Image | Should -BeExactly ('a' * 64)
    }
    It 'throws on no match' {
        { Get-Sha256SumsEntry -Lines $script:Lines -FileName 'other.wsl' } | Should -Throw
    }
    It 'throws on two matches' {
        { Get-Sha256SumsEntry -Lines ($script:Lines + $script:Lines[0]) -FileName $script:Image } | Should -Throw
    }
}

Describe 'ConvertTo-WslVersion' {
    It 'parses NUL-laden output' {
        $raw = ('WSL version: 2.6.1.0'.ToCharArray() | ForEach-Object { "$_`0" }) -join ''
        ConvertTo-WslVersion -Lines @($raw, 'Kernel version: 6.6.87.2-1') | Should -Be ([version]'2.6.1.0')
    }
    It 'parses localized output by position' {
        ConvertTo-WslVersion -Lines @('', 'WSL-Version: 2.3.26.0', 'Kernelversion: 5.15.167.4-1') | Should -Be ([version]'2.3.26.0')
    }
    It 'returns null for help text' {
        ConvertTo-WslVersion -Lines @('Usage: wsl.exe [Argument]') | Should -BeNullOrEmpty
    }
}

Describe 'ConvertFrom-DevSetupMarker' {
    It 'returns the user' {
        ConvertFrom-DevSetupMarker -Content "dev-setup v1 gary`r`n" | Should -BeExactly 'gary'
    }
    It 'returns null for <C>' -TestCases @(
        @{ C = 'Ubuntu-Nix-Test blank baseline v2' }, @{ C = 'dev-setup v1 ' }, @{ C = '' }, @{ C = $null }
    ) {
        ConvertFrom-DevSetupMarker -Content $C | Should -BeNullOrEmpty
    }
}

Describe 'Format-WslStdinPayload' {
    It 'sends the secret as base64 after the read line and decodes it into SECRET' {
        Format-WslStdinPayload -Script "set -eu`necho hi" -SecretLine ' p\a$s ' |
            Should -BeExactly "IFS= read -r SECRET_B64`nIHBcYSRzIA==`nSECRET=`$(printf %s `"`$SECRET_B64`" | base64 -d); unset SECRET_B64`nset -eu`necho hi`nexit `$?`n"
    }
    It 'encodes non-ASCII secrets as UTF-8' {
        Format-WslStdinPayload -Script 'true' -SecretLine ([string][char]0xE9) | Should -Match "`nw6k=`n"
    }
    It 'omits the read line without a secret' {
        Format-WslStdinPayload -Script 'set -eu' | Should -BeExactly "set -eu`nexit `$?`n"
    }
}

Describe 'Get-FileSha256' {
    It 'hashes an empty file in Get-FileHash uppercase form' {
        $path = Join-Path $TestDrive 'empty.bin'
        [IO.File]::WriteAllBytes($path, [byte[]]@())
        Get-FileSha256 -Path $path | Should -Be 'E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855'
    }
    It 'hashes file contents' {
        $path = Join-Path $TestDrive 'abc.bin'
        [IO.File]::WriteAllBytes($path, [Text.Encoding]::ASCII.GetBytes('abc'))
        Get-FileSha256 -Path $path | Should -Be 'BA7816BF8F01CFEA414140DE5DAE2223B00361A396177A9CB410FF61F20015AD'
    }
}
