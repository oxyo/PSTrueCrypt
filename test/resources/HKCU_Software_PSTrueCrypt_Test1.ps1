Import-Module .\RegistryModule

New-SubKey "00000001" 'MarcsTaxDocs'    'D:\Google Drive\1pw'                           'Y' 'TrueCrypt' 'Y' -Timestamp
New-SubKey "00000002" 'BobsTaxDocs'     'C:\Users\Bob\Documents\BobsContainer'          'T' 'TrueCrypt' 'T'
New-SubKey "00000003" 'AlicesTaxDocs'   'C:\Users\Alice\Documents\AlicesContainer'      'V' 'VeraCrypt' 'V' -Timestamp -IsMounted
New-SubKey "00000004" 'Krytos'          'D:\Google Drive\krytos.tc'                     'K' 'TrueCrypt' 'K'