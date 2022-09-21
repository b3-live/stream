#!/bin/bash

# scripts/generate_dart_defines.sh

if [ -z "$1" ] || [ -z "$2" ]; then
  echo -e "Missing arguments: [dev|staging|prod] [macos|linux|windows]"
  # invalid arguments
  exit 128
fi

case "$1" in
"dev") INPUT="env/dev.env"
;;
"staging") INPUT="env/staging.env"
;;
"prod") INPUT="env/prod.env"
;;
*)
  echo "Missing arguments [dev|staging|prod]"
  exit 1
;;
esac

while IFS= read -r line
do
  DART_DEFINES="$DART_DEFINES--dart-define=$line "
done < "$INPUT"
echo "$DART_DEFINES"

flutter run --no-sound-null-safety -d $2 $DART_DEFINES
