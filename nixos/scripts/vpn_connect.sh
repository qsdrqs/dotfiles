read -s -p "Password: " PASSWORD

uiuc_pwd=$(echo "$PASSWORD" | keepassxc-cli show -q -a Password $HOME/global/Passwords.kdbx "KeePassXC-Browser Passwords/uiuc")

echo "$uiuc_pwd
push" | sudo openconnect vpn.illinois.edu -u tz64 --authgroup="OpenConnect1 (Split)" --passwd-on-stdin
