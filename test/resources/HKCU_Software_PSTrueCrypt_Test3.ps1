Import-Module $PSScriptRoot\RegistryModule.psm1

New-SubKey "00000001" 'MarcsTaxDocs'    'D:\Google Drive\1pw'                           'Y' 'TrueCrypt' 'Y' '11/11/2017 11:11:11' -Timestamp
New-SubKey "00000002" 'BobsTaxDocs'     'C:\Users\Bob\Documents\BobsContainer'          'T' 'TrueCrypt' 'T' '11/11/2017 11:11:11'
# New-SubKey "00000003" 'AlicesTaxDocs'   'C:\Users\Alice\Documents\AlicesContainer'      'V' 'VeraCrypt' 'V' '11/11/2017 11:11:11' -Timestamp -IsMounted
New-SubKey "00000004" 'Krytos'          'D:\Google Drive\krytos.tc'                     'K' 'TrueCrypt' 'K' '11/11/2017 11:11:11'