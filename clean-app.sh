
if [ "$1" == "debug" ]; then
  echo "removing com.duckduckgo.macos.browser.$1"
elif [ "$1" == "review" ]; then
  echo "removing com.duckduckgo.macos.browser.$1"
else 
  echo "usage: clean-app debug|review"
  exit 1
fi 

defaults delete com.duckduckgo.macos.browser.$1
rm -rf ~/Library/Containers/com.duckduckgo.macos.browser.$1

