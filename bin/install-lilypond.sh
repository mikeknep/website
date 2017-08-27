if ! command -v lily > /dev/null 2>&1; then
  apt-get update && apt-get install -y lilypond
fi
