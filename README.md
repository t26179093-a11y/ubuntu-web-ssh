# 🖥️ Ubuntu Web SSH (Render.com)

Dieses Projekt erstellt eine Ubuntu 24.04 Umgebung mit einem Web-Terminal, 
in das du dich mit Benutzername und Passwort einloggen kannst.

## 🔧 Login-Daten
- **User:** `admin`
- **Passwort:** `test123`

## 🚀 Anleitung
1. Lade dieses Repo auf GitHub hoch
2. Gehe zu [https://render.com](https://render.com)
3. Klicke **“New +” → “Web Service”**
4. Verbinde dein Repo (`ubuntu-web-ssh`)
5. Stelle sicher, dass der **Free Plan** aktiv ist
6. Klicke **Deploy**

Nach ein paar Minuten bekommst du eine URL wie  
👉 `https://ubuntu-web-ssh.onrender.com`

Wenn du sie öffnest, erscheint:

`chmod +x vm.sh | ./vm.sh`

`sudo apt update && sudo apt install -y qemu-kvm qemu-utils cloud-image-utils`
