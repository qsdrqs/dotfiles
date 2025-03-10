if [ -n "$ZSH_VERSION" ]; then
  read -s "PASSWORD?Password: "
else
  read -s -p "Password: " PASSWORD
fi
echo ""
KEYS=$(echo "$PASSWORD" | keepassxc-cli ls -q -f $HOME/global/Passwords.kdbx secrets)
while IFS= read -r key; do
    formatted_key=$(echo "$key" | tr ' ' '_' | tr '[:lower:]' '[:upper:]')
    [[ ! "$formatted_key" =~ "API_KEY" ]] && continue
    echo "exporting $formatted_key"
    export $formatted_key=$(echo "$PASSWORD" | keepassxc-cli show -q -a Password $HOME/global/Passwords.kdbx "secrets/$key")
done <<< "$KEYS"
export KEY_ENV_LOADED=true
