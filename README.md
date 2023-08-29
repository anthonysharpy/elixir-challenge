# HTTPComparer

## Running The Program

To compare two files, do:

```
mix run -e HTTPComparer.Application.main -- ./test/test_files/13.3.7.json ./test/test_files/13.4.0.json false
```

To run in no-input mode (e.g. for automated runs), set the no-input flag to true:

```
mix run -e HTTPComparer.Application.main -- ./test/test_files/13.3.7.json ./test/test_files/13.4.0.json true
```

## Example Output

```
======================================
               Requests
======================================
Critical - URLs have changed between files: GET https://thebank.teller.engineering/api/apps/A3254414/configuration vs GET https://thebank.teller.engineering/api/apps/A3254415/configuration
Warning - file 2 made a request to POST https://thebank.teller.engineering/api/sectrace/verify but file 1 did not
Notice - the order of request GET https://status.thebank.teller.engineering/status.json has changed from 0 to 1
Notice - the order of request GET https://thebank.teller.engineering/api/apps/A3254414/configuration has changed from 1 to
Notice - the order of request POST https://thebank.teller.engineering/api/accesstokens/usernameandpassword has changed from 2 to 3
======================================
               Headers
======================================
Warning - file 2 - request GET https://thebank.teller.engineering/api/apps/A3254414/configuration had request header x-sectrace but file 1 did not
Notice - request header Content-Type moved from position 2 to 3 in request GET https://thebank.teller.engineering/api/apps/A3254414/configuration
Notice - request header Accept moved from position 3 to 4 in request GET https://thebank.teller.engineering/api/apps/A3254414/configuration
Notice - request header Connection moved from position 4 to 10 in request GET https://thebank.teller.engineering/api/apps/A3254414/configuration
Notice - request header Accept-Language moved from position 7 to 8 in request GET https://thebank.teller.engineering/api/apps/A3254414/configuration
Notice - request header Cache-Control moved from position 8 to 2 in request GET https://thebank.teller.engineering/api/apps/A3254414/configuration
Warning - file 1 - request POST https://thebank.teller.engineering/api/accesstokens/usernameandpassword had request header Cache-Control but file 2 did not
Warning - file 2 - request POST https://thebank.teller.engineering/api/accesstokens/usernameandpassword had request header x-sectrace but file 1 did not
Notice - request header Accept-Encoding moved from position 4 to 9 in request POST https://thebank.teller.engineering/api/accesstokens/usernameandpassword
Notice - request header Connection moved from position 5 to 4 in request POST https://thebank.teller.engineering/api/accesstokens/usernameandpassword
Notice - request header Cookie moved from position 6 to 5 in request POST https://thebank.teller.engineering/api/accesstokens/usernameandpassword
Notice - request header User-Agent moved from position 7 to 6 in request POST https://thebank.teller.engineering/api/accesstokens/usernameandpassword
======================================
               Response
======================================
Info - request GET https://thebank.teller.engineering/api/apps/A3254414/configuration in file 1 returned key properties.billingAndPaymentsEnablement in the response body, but in file 2 it didn't
Info - request GET https://thebank.teller.engineering/api/apps/A3254414/configuration in file 1 returned key properties.faceIdAuthEnablement in the response body, but in file 2 it didn't
Info - request GET https://thebank.teller.engineering/api/apps/A3254414/configuration in file 2 returned key properties.aiEnablement in the response body, but in file 1 it didn't
Info - request GET https://thebank.teller.engineering/api/apps/A3254414/configuration in file 2 returned key properties.paymentsEnablement in the response body, but in file 1 it didn't
======================================
```

## Project Setup

I used Mix since it seemed like a good way to manage a non-trivial project.

## Approach To Problem

At its core the problem involves comparing two JSON files. One approach would just be to find and print out the differences. However, when considered in the context that the tool would be used, this wouldn't be very helpful. The tool needs to inform a developer, in the simplest and most time-efficient way possible, whether there are any changes that they need to care about. Generating a big sprawling diff would make it very difficult for a developer to read (especially if the files have large differences or are out-of-order), and if a developer has to struggle to understand it then they risk missing something important.

In figuring out the best solution I made a couple of assumptions:

- The input data is a bank's API requests/responses that have been captured (so we can assume they're correct).
- The input data will always more or less be in the same format as the examples given.
- All the requests and responses use the HTTP protocol only (no websockets, etc).
- There is at most one response for every request, since that's generally how the HTTP protocol works.
- Any given request is made only once - i.e. the same request method with the same URL does not come up twice in the same file (although, see below).

Another assumption I made is that the program should mostly only care about comparing requests, not responses. This is because the content of a response is mostly immaterial (we just care that we get one, not what it says). It is true that data from a response might be used in a subsequent request, but this is aaccounted for just by looking at the captured requests. That being said, we do still output any changed response body keys for informational purposes, since it might be helpful for a developer to know, if a code change is required. 

When looking at differences in the JSON, we ignore any changes in the values. If something like a dynamically-generated access token changes between the two files, that's not something we need to be worrying about. It is possible there might be important changes in the values, but there is no surefire way we can distinguish between important and unimportant changes, and it would just lead to too many false positives.

## How It Works

Each input file contains a list of "pairs" (i.e. a request and a response).

The first difficult part is finding a way to match pairs across files. I didn't assume that all the pairs were going to be in the same order in both files, or that the number of requests were going to be the same. 

The program matches the pairs from the two files based on the request method plus the URL (excluding parameters, since these commonly change). 

This is not a perfect solution since even URLs can change (in the example data we see ".../A3254414/..." change to ".../A3254415/..."). I could have written an algorithm to compare the similarity of the URLs, but this would have been error-prone. For example, these obviously correspond to eachother:

https://mybank.com/api/4255/getbalance 
https://mybank.com/api/4260/getbalance

But do these?
https://mybank.com/api/account/configure 
https://mybank.com/api/app/configure

What it does then is where it can't find a URL that matches between both files (e.g. because it was renamed), it asks the user to choose the URL they think matches (or none, if it was added or removed in one of the files). This is basically exactly the way things like like Git manage merge conflicts.

It may be the case that this tool would be used for automated testing, in which case human input is not practical. So I added a flag that disables input and causes the program to always assume that an unmatched URL is a new/removed request.

Once we have matched the pairs, the program does a check to warn if there are duplicate requests on the same URL (the matching procedure assumes this is not possible). It **is** possible that there might be duplicate requests in the real world (e.g. some APIs might make all of their requests on the same URL), but the reasons I decided not to try and handle this were:

a) the solution for APIs that make different requests on the same URL would probably be API-specific and so it is a bit of an unnecessary rabbit hole to go down
b) it's maybe a bit beyond the scope of this hypothetical example since that doesn't happen in the examples given
c) the program will probably still be producing somewhat useful output anyway
d) we could always add that on later, this is probably fine for 95% of use cases

The program runs the matched pairs through a number of separate procedures to identify any differences. 

Each procedure looks for a specific thing and is targeted to maximise the usefulness to the developer in terms of its output. Output is demarcated into separate request/header/response sections. Output comes in different types:

Critical: there is a significant difference or parsing issue that warrants immediate attention from a developer (e.g. a removed endpoint).
Warning: something has changed that may or may not be important (e.g. new headers).
Notice: something has changed but it is unlikely to be important (e.g. changed header order).
Info: something has changed but there's no way it could affect anything (e.g. new response body keys), this is just for informational purposes.

It is difficult to knwo how useful this program would be or what practical limitations it might come up against when used in the real world. As with most software it would probably need further iteration as and when problems arise.

## Error Handling

As this is not a production-critical application, I didn't see the need for careful error handling; if there is an error then a hopefully helpful exception is raised, and the program is allowed to crash.

# Test

To run the tests:

```
mix test
```
