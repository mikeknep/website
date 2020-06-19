---
layout: post
title: Nixing the ExceptionHandler
---

A few posts ago, I described the `ExceptionHandler` class in my Java server, which I thought was pretty clever. Well, it has been removed. Here's why.

### Consistent Behavior

I've already described the high-level behavior of my server multiple times, but here it is once again: the server's job is to accept requests and send responses. Well, except for the so-called "phantom" requests, which I log and close without a response. And maybe also except for some other cases where I don't want to really do anything about a particular request for whatever reason besides log it for my own information. So yeah, except for a handful of weird cases, the server accepts requests and sends responses.

Gross.

The high-level behavior of any system should stay as simple and consistent as possible. I've been over the value of abstractions, pushing details down, SOLID, and so forth again and again, and yet here I am essentially `if/else`-ing in the top-most level of my code.

By removing the `ExceptionHandler` class, which had the sole responsibility of deciding whether to send a response or not, I have made the Server class more consistent. It will send a response for each and every request, even if it is a...


### Bad Request (400!)

Wouldn't you know it? I'm not the first person to have this problem! In fact, it is so common that there is a status code dedicated to this exact situation: 400 Bad Request. Web browsers handle responses with this status code perfectly--they don't do anything. Previously I was worried that any response would result in "something happening" (from the perspective of the web browser's user), such as a page load or a redirect. In fact, browsers can receive responses from servers completely behind the scenes, invisible to the ordinary browser user.

This discovery opened up my options tremendously. I'm now collecting all raw requests, including phantom requests, and attempting to form a Request object (my own wrapper for a client request) as best as possible. If the Request object doesn't have everything the server needs, not to worry--the `Dispatcher` will call upon an appropriate `ResponseBuilder` to build a 400 response once the `RequestValidator` determines that it's a bad request.


### Exception Ownership

One concern I had with removing the `ExceptionHandler` (and, by extension, the `PhantomRequestException` class) was that I felt I'd lost the ability to "fail fast." I had previously been raising the `PhantomRequestException` as soon as possible--my `Listener` would sound the alarm if the raw request string was blank, without even sending it to the next step in the chain (the `RequestBuilder`). I felt I was taking ownership of the situation; I was correctly diagnosing the problem, rather than reacting to just a symptom (`ArrayIndexOutOfBounds`). Conversely, I now let the phantom request trickle into the system as far as the `Dispatcher` before it is acknowledged as a bad request and routed appropriately. Isn't this letting it get too far into the system? Doesn't this force me to deal with too many possibilities along the way, rather than attacking the source and not needing to worry about those possibilities?

Well, yes and no. It's true that I'm now letting bad requests further into the system and I *could* recognize a few of them earlier on. However, bad requests are still requests being made to the server, which I have no control over. Throwing a custom exception based on a completely external thing is actually a little odd--if my database had dropped all its tables or a task in my system sucked all the computer's memory, sure, go ahead, take ownership over those problems and raise custom exceptions. But I don't want to take ownership of other people's problems--by that very definition they aren't mine to begin with, so why go out of my way apologizing for them? If you send me a bad request, fine, I'll send you a response letting you know you sent me a bad request. I'm not going to deliberately raise an exception and rewire the behavior of the entire system because of something someone else did.

### Conclusion

I still am very interested in the concepts of exception handling, taking ownership of errors, failing fast, and recovering gracefully. However, it turns out handling bad requests in a server is not the best place to be implementing those techniques. My entire mission with the Java server right now is to make it as simple as possible so I can ultimately leave the decision making and other heavy lifting to something else. I can't make it much simpler than "get request, send response".