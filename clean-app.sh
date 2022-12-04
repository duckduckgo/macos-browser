
if [ "$1" == "debug" ]; then
  echo "removing com.duckduckgo.macos.browser.$1"
  defaults delete com.duckduckgo.macos.browser.$1
  rm -rf ~/Library/Containers/com.duckduckgo.macos.browser.$1
elif [ "$1" == "review" ]; then
  echo "removing com.duckduckgo.macos.browser.$1"
  defaults delete com.duckduckgo.macos.browser.$1
  rm -rf ~/Library/Containers/com.duckduckgo.macos.browser.$1
elif [ "$1" == "debug-sandbox" ]; then
  echo "removing com.duckduckgo.mobile.ios.debug"
  defaults delete com.duckduckgo.mobile.ios.debug
  rm -rf ~/Library/Containers/com.duckduckgo.mobile.ios.debug
elif [ "$1" == "review-sandbox" ]; then
  echo "removing com.duckduckgo.mobile.ios.review"
  defaults delete com.duckduckgo.mobile.ios.review
  rm -rf ~/Library/Containers/com.duckduckgo.mobile.ios.review
else 
  echo "usage: clean-app debug|review"
  exit 1
fi 


