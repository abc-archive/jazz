$baseFileName = "_Jazz_Tunes"
#$baseFileName = "test"


Write-Host "==========================================================="
Write-Host "  Processing '${baseFileName}'"
Write-Host "===========================================================`n`n"


Write-Host "-----------------------------------------------------------"
Write-Host "  1. Merging all tunes in folder into a single ABC tunebook"
Write-Host "-----------------------------------------------------------`n"

$outputFile = "${baseFileName}.abct"
Remove-Item $outputFile -ErrorAction Ignore


# Define the string to be added at the beginning of the output file
$metadata = @"
%@title: Jazz Tunes
%@initials: JT
%@iconcolor: #9e09c7
%@author: JazzFan
%@lastupdate: $(Get-Date -Format "yyyy-MM-dd")

"@

# Add the metadata to the output file
Add-Content -Path $outputFile -Value $metadata

$counter = 0
Get-ChildItem -Filter *.abc | Where-Object { $_.Extension -eq '.abc' } | ForEach-Object {
    if ($_.Name -ne $outputFile) {
        $counter++
        Write-Host "$counter $($_.Name)"
        $abcContent = Get-Content $_.FullName -Raw
        Add-Content -Path $outputFile -Value $abcContent
        Add-Content -Path $outputFile -Value "`n"
    }
}


Write-Host "`n$counter Tunes have been merged into $outputFile`n`n"

Write-Host "-----------------------------------------------------------"
Write-Host "  2. Shifting Characters"
Write-Host "-----------------------------------------------------------`n"

$shift = 100
$inputFile = "${baseFileName}.abct"
$outputFile = "${baseFileName}_shift.abct"
Remove-Item $outputFile -ErrorAction Ignore

# Read the input file as UTF-8 text
#$textContent = Get-Content -Path $inputFile -Raw
$textContent = Get-Content -Path $inputFile -Raw -Encoding UTF8

# Define a function to shift characters
function Shift-Character {
    param (
        [char]$character,
        [int]$shift
    )
    [char](([int]$character + $shift) % 65536)
}

# Initialize counter
$counter = 0
$totalCharacters = $textContent.Length
$updateInterval = [math]::floor($totalCharacters / 50)
#1234

# Apply the character shift to each character in the text
$shiftedText = $textContent.ToCharArray() | ForEach-Object { 
    Shift-Character $_ $shift 
    if ($_ -ne $shiftedChar) {
        $counter++
        if ($counter % $updateInterval -eq 0) {
            Write-Host "Characters shifted: $counter / $totalCharacters" -NoNewline
            Write-Host "`r" -NoNewline # Move cursor to the beginning of the line
        }
    }
}

# Convert the shifted characters back to a string
$shiftedText = [string]::new($shiftedText)

# Save the shifted text as plain UTF-8 (without BOM)
$Utf8NoBom = New-Object System.Text.UTF8Encoding $false
#[System.IO.File]::WriteAllText($outputFile, $shiftedText, $Utf8NoBom)
[System.IO.File]::WriteAllText($outputFile, $shiftedText, [System.Text.Encoding]::UTF8)


Write-Host "-----------------------------------------------------------"
Write-Host "  3. Zipping the tunebook"
Write-Host "-----------------------------------------------------------`n"

# Define the paths and file names
$inputFile = "${baseFileName}_shift.abct"
$outputFile = "${baseFileName}_zip.ctbf"
$zipExe = "C:\Program Files\7-Zip\7z.exe"

# Check if the output file exists and delete it if it does
if (Test-Path $outputFile) {
    Remove-Item $outputFile
}

# Switch to the directory of the source file
Set-Location -Path (Get-Item -Path $inputFile).DirectoryName

# Use 7-Zip to create the ZIP archive
Start-Process -FilePath $zipExe -ArgumentList "a", "-tzip", "-bb0", $outputFile, $inputFile -NoNewWindow -Wait

Write-Host "`nThe file '$inputFile' has been compressed into '$outputFile'.`n`n"


Write-Host "-----------------------------------------------------------"
Write-Host "  4. Encrypting the zip file with AES-CBC"
Write-Host "-----------------------------------------------------------`n"

# Define the file paths
$inputFile = "${baseFileName}_zip.ctbf"
$outputFile = "${baseFileName}.ctbf"

# Check if the output file exists and delete it if it does
if (Test-Path $outputFile) {
    Remove-Item $outputFile
}


$secretKeyBase64="JZdMCmZ6osHnmfm/mQdCew=="
Write-Host "Secret Key (Base64): $secretKeyBase64"
$secretKeyBytes = [Convert]::FromBase64String($secretKeyBase64)

# Fixed iv
# $ivBase64 ="LcYsdcXLvxv27F265i3hIA=="
# Write-Host "IV (Base64): $ivBase64"
# Convert to bytes
# $ivBytes = [Convert]::FromBase64String($ivBase64)

# Generate a random IV
$ivBytes = New-Object byte[] 16
$random = New-Object System.Security.Cryptography.RNGCryptoServiceProvider
$random.GetBytes($ivBytes)
Write-Host "IV (Base64):        " ([Convert]::ToBase64String($ivBytes))


# Read the input file as binary data
$zipData = [System.IO.File]::ReadAllBytes($inputFile)

# Create an AES encryption context with CBC mode
$encryptionContext = New-Object System.Security.Cryptography.AesCryptoServiceProvider
$encryptionContext.Mode = [System.Security.Cryptography.CipherMode]::CBC
$encryptionContext.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
$encryptionContext.Key = $secretKeyBytes
$encryptionContext.IV = $ivBytes

# Create a CryptoStream to perform the encryption
# $encryptionStream = New-Object System.Security.Cryptography.CryptoStream([System.IO.File]::Create($outputFile), $encryptionContext.CreateEncryptor(), [System.Security.Cryptography.CryptoStreamMode]::Write)
#$encryptionStream = New-Object System.Security.Cryptography.CryptoStream([System.IO.File]::OpenWrite($outputFile), $encryptionContext.CreateEncryptor(), [System.Security.Cryptography.CryptoStreamMode]::Write)

# Create a MemoryStream to hold the encrypted data
$encryptedDataStream = New-Object System.IO.MemoryStream

# Create a CryptoStream to perform the encryption
$encryptionStream = New-Object System.Security.Cryptography.CryptoStream($encryptedDataStream, $encryptionContext.CreateEncryptor(), [System.Security.Cryptography.CryptoStreamMode]::Write)

# Write the encrypted data
$encryptionStream.Write($zipData, 0, $zipData.Length)
$encryptionStream.Close()


# Concatenate the IV and the encrypted data
$combinedData = $ivBytes + $encryptedDataStream.ToArray()
# Write the combined data to the output file
[System.IO.File]::WriteAllBytes($outputFile, $combinedData)

Write-Host "`nThe file '$inputFile' has been AES-CBC encrypted into '$outputFile'.`n`n"

pause


