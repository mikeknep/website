---
layout: post
title: Server Boundaries
---

As the development of my Java server continues, I wonder: what exactly should it be doing?

Currently my server can:

- return a requested HTML or Image file

- return a requested directory as a list of links to the files in that directory

- return a 404 HTML page or plain text 404 (depending on whether or not a "404.html" file has been supplied) when a requested resource cannot be located

- return a 500 HTML page or plain text 500 (as with 404) when an exception occurs

This is pretty nice basic functionality, and it passes half of "Cob Spec", an internal testing suite at 8th Light that delineates basic server requirements. Yesterday I looked at the currently-failing Cob Spec tests (which include things like 302 redirects, POST and PUT requests, etc.) and started brainstorming how I might add these features to my server. Something felt a little off, though, and after chatting with Rylan, reading more about the Apache architecture, and thinking about everything going on, I've reached a somewhat bizarre conclusion, or at least question:

Is my server already doing too *much*? Should I actually start *removing* some things from my server?

On the surface, this seems counterintuitive; if half of Cob Spec is passing, then what I have so far must be doing something right, and given the other half is failing, there must be more to implement. However, I am increasingly feeling that the server should do less and less. Accepting input (requests) and sending output (responses) definitely fall under the server's list of responsibilities, but *generating* that output? That might be the responsibility of something else.

What if I want to return directories as static, non-linked lists of files? What if I want to redirect any exception-causing action to the home page with some flash message instead of serving up a 500 page? What if every time someone adds `mike_is_awesome=true` as a query string parameter I want to shower the page with confetti to reward their awareness and honesty? ;)

These are all decisions that should be made by some other thing--to be honest I'm not exactly sure *what* thing, but not the server itself. The server can collect an incoming byte stream, format it as a request in some standard format, and pass that request object off to an application or module or whatever. That external service can decide how to handle the request and build an appropriate response object following its own rules and logic. It hands the response back to the server which sends it to the original client.

I should note that my server is already doing this sort of thing on a small scale internally. By following the Single Responsibility Principle this architecture emerged quite naturally. A `Listener` object collects an incoming byte stream and translates it into a raw string. This raw string is passed to a `RequestBuilder`, which (obviously) builds a Request object. The Request object is passed to a `Dispatcher`, which performs a high-level interpretation of the Request to determine which type of `ResponseBuilder` (an interface) it should send the Request to--`DirectoryResponseBuilder`, `FileResponseBuilder`, or `ErrorResponseBuilder`. These builders all have a `buildResponse()` method per the `ResponseBuilder` interface they implement, but have different private methods dictating how exactly that response is built. The resulting Response object is passed to a `Responder` that sends it back to the client.

This current architecture and design would probably be fine if this was the final stopping point, but it isn't for two reasons. First, obviously, Cob Spec demands additional functionality. Second, and more importantly as a lesson to be learned, software development never has a "final stopping point." There will always be new features to add or existing features to modify. For this reason, I feel a leaner and more configurable server core is a more appropriate direction to head towards. I don't have a fully fleshed out vision for it yet (ex. should there be defaults/fallbacks, or should it absolutely require initialization with some external module or application specified? Let alone how does it communicate with the external service...) but the general idea feels clean and inherently beneficial for future development.
