# PSTrueCrypt
PSTrueCrypt is a PowerShell module for mounting TrueCrypt and VeraCrypt containers.  

### Features:
* No configuration files are needed.  Registry is used to store non-sensitive data for the container.
* Option to update container's last write time for cloud storage services can sync it
* Uses SecureString and binary string (BSTR) to handle password securely
* Supports the use of keyfiles

### Limitations:
* No support for disk/partition or system encryption
* TrueCrypt or VeraCrypt must be installed

### Notes:
* Only tested on Windows 10 using .NET 4.6
* One love, one heart (One repository, one contributor).  So there are most likely unknown limitations and issues.
Please add any feedback, concerns, requests and/or bugs in the 'Issues' section of this project

## Instructions
* Download project to your PowerShell Module directory.  Or if PsGet is installed run the following command:
	```powershell
	Install-Module PSTrueCrypt
	```

	### Mount-TrueCrypt

	Mounts a TrueCrypt container with name of 'Kryptos', which must be in the registry.
	```powershell
	E:\> Mount-TrueCrypt -Name Kryptos
	Enter password: **********
	E:\>
	```
	
	Although not recommended, due to plain-text password variable, this demostrates passing a variable into the 
	Mount-TrueCrypt cmdlet. 
	```powershell
	E:\> $SecurePassword = "123abc" | ConvertTo-SecureString -AsPlainText -Force
	E:\> Mount-TrueCrypt -Name Kryptos -Password $SecurePassword
	E:\>
	```

	Mounts a TrueCrypt container with name of 'Kryptos' that requires a Keyfile.
	```powershell
	E:\> Mount-TrueCrypt -Name Kryptos -KeyfilePath C:/Music/Courage.mp3
	Enter password: **********
	E:\>
	```

	### Dismount-TrueCrypt

	```powershell
	E:\> Dismount-TrueCrypt -Name Kryptos
	E:\>
	```

	Dismounts all TrueCrypt and all VeraCrypt containers in sequential order.
	```powershell
	E:\> Dismount-TrueCrypt -ForceAll
	E:\>
	```

	### New-PSTrueCryptContainer

	Creates a container setting in the registry, specifying 'Kryptos' for the name which is referenced by PSTrueCrypt.
	And specifying the path to the container at 'D:\Kryptos' with 'M' being the letter of the drive.  And claiming the
	container having been created with VeraCrypt.
	```powershell
	E:\> New-PSTrueCryptContainer -Name Kryptos -Location D:\Kryptos -MountLetter M -Product VeraCrypt

	New-PSTrueCryptContainer will add a new subkey in the following of your registry: HKCU:\SOFTWARE\PSTrueCrypt
	Are you sure you want to proceed?
	[Y] Yes  [N] No  [?] Help (default is "N"): Y

	E:\>
	```
	
	Identical as the example directly above except the 'Timestamp' switch parameter is being used to indicate that
	the container's 'Last Write Time' should be updated when dismounted.  This is particularly useful if the container resides
	in a cloud storage service directory.
	```powershell
	E:\> New-PSTrueCryptContainer -Name Kryptos -Location D:\Kryptos -MountLetter M -Product VeraCrypt -Timestamp

	New-PSTrueCryptContainer will add a new subkey in the following of your registry: HKCU:\SOFTWARE\PSTrueCrypt
	Are you sure you want to proceed?
	[Y] Yes  [N] No  [?] Help (default is "N"): Y

	E:\>
	```

	### Remove-PSTrueCryptContainer

	```powershell
	E:\> Remove-PSTrueCryptContainer -Name Kryptos
	Container settings has been deleted from registry.
	
	E:\>
	```

	### Show-PSTrueCryptContainers
	
	```powershell
	E:\> Show-PSTrueCryptContainers

	Name  Location                      MountLetter Product
	----  --------                      ----------- -------
	brian C:\passwords                  X           VeraCrypt
	verac D:\veracrypt                  V           VeraCrypt
	lori  D:\Documents                  H           TrueCrypt
	1pw   F:\Google Drive\1pw           Z           TrueCrypt

	E:\>
	```
