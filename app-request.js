let twitterHandle
if (args[2].charAt(0) == "@") {
  twitterHandle = args[2].substring(1)
} else {
  twitterHandle = args[2]
}

const twitterKeywords = args[3].split(",")

// To make an HTTP request, use the Functions.makeHttpRequest function
// Functions.makeHttpRequest function parameters:
// - url
// - method (optional, defaults to 'GET')
// - headers: headers supplied as an object (optional)
// - params: URL query parameters supplied as an object (optional)
// - data: request body supplied as an object (optional)
// - timeout: maximum request duration in ms (optional, defaults to 10000ms)
// - responseType: expected response type (optional, defaults to 'json')

// call the Mainline API to retrieve a list of recent tweets of the KOL
const mainlineResponse = await Functions.makeHttpRequest({
  url: `https://app.getmainline.com/api/tweets/handle/${twitterHandle}`,
  headers: { "Api-Key": "c0620cb3-e210-4cae-8fdc-f2356f655174" },
})

console.log(mainlineResponse)

const tweets = []
if (!mainlineResponse.error) {
  for (let i = 0; i < mainlineResponse.data.length; i++) {
    tweets.push(mainlineResponse.data[i].tweet)
  }
} else {
  console.log("Mainline Error")
}

// check if tweets contain the keywords
let keywordsFound = false
for (let i = 0; i < twitterKeywords.length; i++) {
  const keywordIncludedTweets = tweets.filter((keyword) =>
    keyword.toLowerCase().includes(twitterKeywords[i].toLowerCase())
  )
  if (keywordIncludedTweets.length > 0) {
    keywordsFound = true
  }
}

return Functions.encodeUint256(keywordsFound ? 1 : 0)
