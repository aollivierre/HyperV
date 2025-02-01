
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-WebRequest -Uri "https://dl.teamviewer.com/download/version_15x/TeamViewer_Setup_x64.exe?ref=https%3A%2F%2Fwww.teamviewer.com%2Fen-us%2Fdownload%2Fwindows%2F" -OutFile "C:\users\Public\tv.exe"
& "C:\users\Public\tv.exe"


#one liner
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri "https://dl.teamviewer.com/download/version_15x/TeamViewer_Setup_x64.exe?ref=https%3A%2F%2Fwww.teamviewer.com%2Fen-us%2Fdownload%2Fwindows%2F" -OutFile "C:\users\Public\tv.exe"; & "C:\users\Public\tv.exe"



#latest (much faster than Invoke-WebRequest)
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Start-BitsTransfer -Source "https://dl.teamviewer.com/download/version_15x/TeamViewer_Setup_x64.exe?ref=https%3A%2F%2Fwww.teamviewer.com%2Fen-us%2Fdownload%2Fwindows%2F" -Destination "C:\users\Public\tv.exe" ; & "C:\users\Public\tv.exe"