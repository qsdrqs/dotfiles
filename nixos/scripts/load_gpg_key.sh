if [ -n "$ZSH_VERSION" ]; then
  read -s "PASSWORD?Password: "
else
  read -s -p "Password: " PASSWORD
fi
echo ""
KEYS=$(echo "$PASSWORD" | keepassxc-cli ls -q -f $HOME/global/Passwords.kdbx secrets)
while IFS= read -r key; do
    if [[ "$key" == "GnuPG: n/"* ]]; then
        KEYGRIP="${key#GnuPG: n/}"
        echo "loading $KEYGRIP"
        secret=$(echo "$PASSWORD" | keepassxc-cli show -q -a Password $HOME/global/Passwords.kdbx "secrets/$key")
        /run/current-system/sw/libexec/gpg-preset-passphrase --preset $KEYGRIP <<< "$secret"
    fi
done <<< "$KEYS"
export KEY_ENV_LOADED=true
