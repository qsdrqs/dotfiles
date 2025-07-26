uiuc_pwd=$(secret-tool lookup Title "uiuc")

echo "$uiuc_pwd
push" | sudo openconnect vpn.illinois.edu -u tz64 --authgroup="OpenConnect1 (Split)" --passwd-on-stdin
