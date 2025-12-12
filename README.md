# seven11_builder
Debloat | Trim | windows image for speed

usage:
drag and drop .iso, extracted folder of windows 11/10 iso, .wim/.wsd to the seven11.exe

notes:
these four security vendors flagged this file (seven11.exe) as malicious because i included disabling windows defender.

* Bkav Pro -		W64.AIDetectMalware
* DeepInstinct -	MALICIOUS
* Microsoft -		PUA:Win32/Puwaders.C!ml
* SecureAge -		Malicious

these 6 security vendors flagged wimlib-imagex.exe as malicious. (wimlib is safe)

* Avast - Other:Malware-gen [Trj]
* AVG - Other:Malware-gen [Trj]
* Avira (no cloud) - ADWARE/AVI.AdwareX.nbtpt
* DeepInstinct - MALICIOUS
* MaxSecure - Trojan.Malware.328990141.susgen
* WithSecure - Adware.ADWARE/AVI.AdwareX.nbtpt
