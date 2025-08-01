#!/bin/sh

if [ "$(stat -Lc %U /root)" != "root" ]; then
  WATCH="/root/.ssh"
  REAL_OWNER=$(stat -Lc %U /root)
  REAL_GROUP=$(stat -Lc %G /root)
  REAL_UID=$(stat -Lc %u /root)
  REAL_GID=$(stat -Lc %g /root)
  echo "Watching $WATCH for changes in ownership: $REAL_UID:$REAL_GID ($REAL_OWNER:$REAL_GROUP)"
  chown -R --no-dereference "$REAL_OWNER":"$REAL_GROUP" $WATCH # Run this once to ensure the initial ownership is correct
  inotifywait -mrq -e create,move,attrib --format '%w%f' "$WATCH" |
  while read -r f; do
      [[ -e "$f" ]] || continue
      read CUR_UID CUR_GID < <(stat -c '%u %g' "$f" 2>/dev/null)
      if [[ $CUR_UID -ne $REAL_UID || $CUR_GID -ne $REAL_GID ]]; then
          echo "Changing ownership of $f to $REAL_OWNER:$REAL_GROUP"
          chown --no-dereference "$REAL_OWNER":"$REAL_GROUP" "$f"
      fi
  done
fi
