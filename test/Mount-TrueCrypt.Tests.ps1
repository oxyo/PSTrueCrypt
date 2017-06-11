Get-Module -Name PSTrueCryptMockModule | Remove-Module
New-Module -Name PSTrueCryptMockModule  -ScriptBlock {
    function Test-IsAdmin{} 
    function Edit-HistoryFile{}
    function Get-Confirmation{}

    Export-ModuleMember -Function Test-IsAdmin, Edit-HistoryFile, Get-Confirmation
} | Import-Module -Force

Describe "Test Mount-TrueCrypt when called..." {
    
    BeforeEach {
        $OutTestPath = Split-Path -Path $PSScriptRoot -Parent | Join-Path -ChildPath "out/test/resources"
        
        Remove-Item -Path $OutTestPath -Recurse -ErrorAction Silently 
        
        Copy-Item "$PSScriptRoot/resources" -Destination $OutTestPath -Recurse
    }

    AfterEach {
        Split-Path -Path $PSScriptRoot -Parent | Join-Path -ChildPath "out" | Remove-Item -Recurse
    }
    
    Context "with no KeyfilePath..." {
        InModuleScope PSTrueCrypt {
            Mock Get-PSTrueCryptContainer { 
            @{
                TrueCryptContainerPath = "$PSScriptRoot/test/resources/truecrypt"
                PreferredMountDrive = "T";
                Product = "TrueCrypt";
                Timestamp = 0x00000000
            }} -Verifiable

            Mock Test-IsAdmin { return $True } -Verifiable

            Mock Read-Host { return  ConvertTo-SecureString "123abc" -AsPlainText -Force } -Verifiable

            Mock Set-ItemProperty {} -Verifiable

            Mock Invoke-Expression {}
            
            Mock Edit-HistoryFile {}

            Mount-TrueCrypt -Name 'true'

            It "Should of called internal functions..." {
                Assert-VerifiableMocks
            }

            It "Should of called Invoke-Expression with the value being used in this comparison operator..." {
                Assert-MockCalled Invoke-Expression -ModuleName PSTrueCrypt -Times 1 -ParameterFilter {
                    $Command -eq "& TrueCrypt /explore /password '123abc' /volume '/test/resources/truecrypt' /quit /auto /letter 'T'"
                }
            }
        }
    }
    
    Context "with KeyfilePath..." {
        InModuleScope PSTrueCrypt {
            Mock Get-PSTrueCryptContainer { 
            @{
                TrueCryptContainerPath = "$PSScriptRoot/test/resources/truecrypt"
                PreferredMountDrive = "T";
                Product = "TrueCrypt";
                Timestamp = 0x00000000
            }} -Verifiable

            Mock Test-IsAdmin { return $True } -Verifiable

            Mock Read-Host { return  ConvertTo-SecureString "123abc" -AsPlainText -Force } -Verifiable

            Mock Set-ItemProperty {} -Verifiable

            Mock Invoke-Expression {}
            
            Mock Edit-HistoryFile {}

            Mount-TrueCrypt -Name 'true' -KeyfilePath "$OutTestPath/.AlicesTrueCryptKeyfile"

            It "Should of called internal functions..." {
                Assert-VerifiableMocks
            }

            It "Should of called Invoke-Expression with the value being used in this comparison operator..." {
                Assert-MockCalled Invoke-Expression -ModuleName PSTrueCrypt -Times 1 -ParameterFilter {
                    $Command -eq "& TrueCrypt /keyfile '/.AlicesTrueCryptKeyfile' /explore /password '123abc' /volume '/test/resources/truecrypt' /quit /auto /letter 'T'"
                }
            }
        }
    }
    
    Context "with SecureString..." {
        InModuleScope PSTrueCrypt {
            Mock Get-PSTrueCryptContainer { 
            @{
                TrueCryptContainerPath = "$PSScriptRoot/test/resources/truecrypt"
                PreferredMountDrive = "T";
                Product = "TrueCrypt";
                Timestamp = 0x00000000
            }} -Verifiable

            Mock Invoke-Expression {}
            
            Mock Edit-HistoryFile {} -Verifiable

            $SecureString = ConvertTo-SecureString '123abc' -AsPlainText -Force

            Mount-TrueCrypt -Name 'true' -KeyfilePath "$OutTestPath/.AlicesTrueCryptKeyfile" -Password $SecureString

            It "Should of called internal functions..." {
                Assert-VerifiableMocks
            }

            It "Should of called Invoke-Expression with the value being used in this comparison operator..." {
                Assert-MockCalled Invoke-Expression -ModuleName PSTrueCrypt -Times 1 -ParameterFilter {
                    $Command -eq "& TrueCrypt /keyfile '/.AlicesTrueCryptKeyfile' /explore /password '123abc' /volume '/test/resources/truecrypt' /quit /auto /letter 'T'"
                }
            }
        }
    }
}