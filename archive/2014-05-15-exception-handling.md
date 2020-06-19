---
layout: post
title: Exception Handling
---

Yesterday I built an ExceptionHandler object to, well, handle exceptions in my Java server. In this post I will explore the purpose of the ExceptionHandler, how it works, and the benefits of custom exceptions.


### Phantom Requests
I noticed a strange error occurring in my server yesterday. I could make multiple requests and the server responded appropriately with either "200 OK" or "404 Not Found" responses. However, if I made a request and then left everything alone, after about 15 seconds the server would suddenly crash with an "ArrayIndexOutOfBoundsException." What the heck?! This exception was occurring in the RequestBuilder, which parses raw incoming requests by splitting them into the Request Line (ex. "GET /index.html HTTP/1.1") and the headers (everything else, ex. "Content-Type: text/html"). This was my first clue towards the source of the problem: my server was behaving as if a request had come in when there wasn't one, and as a result was throwing the ArrayIndexOutOfBoundsException when it couldn't find the pieces of the split raw request string.

Lacking a better way of recreating the problem, I added `println()` commands all over the code in an attempt to see what was going on. When I reran the server and waited for the delayed exception, I noticed something very odd: the server appeared to be accepting an empty string request, despite me leaving the browser completely alone! As is nearly always the case, I was not the first to experience this strange phenomenon. Some of the other apprentices had run into these "phantom requests" as well. I found surprisingly little information about them through Googling--the most plausible explanation actually came from another apprentice's blog post describing a conversation with Micah. Micah hypothesized that the browser prepares a second request immediately after the first, perhaps in an effort to conserve overhead or increase perceived speed should another request be made, but when no request is made by the user, the browser's preparation times out and returns an empty string request.

It was pretty frustrating that some stupid thing the browser did and over which I had no control was crashing my server, but obviously I couldn't just complain about it--something had to be done.

### ExceptionHandler
I decided this was as good a time as any to start handling exceptions more professionally in my server. Many methods in my server were declared with `throws Exception`, but until recently none of them were actually *dealing with* those exceptions in any meaningful way. So, instead of just writing `public void run() throws Exception {}`, I wrapped the `run()` method in a try/catch block. This allows you to specify things to be done should an exception be thrown:

```java
public void run() {
  try {
    // do stuff here
  }
  catch (Exception e) {
    // if an exception occurs anywhere in the try block, do this stuff here
  }
}
```

You'll notice the argument in the catch block, `(Exception e)`. This allows me to use the actual exception object by referencing the variable `e`. I began building out an ExceptionHandler class responsible for analyzing the particular exception and reacting appropriately. Some exceptions, like the ArrayIndexOutOfBoundsException thrown as a result of phantom requests, should just be ignored. Others, however, might warrant a 500 response getting sent to the user. In the case of the former I can simply log the request for my own knowledge, close the socket, and go back to listening for requests. In latter cases, I tell my ResponseBuilder object to build a 500 response and send it to the user before closing the socket.

### Custom Exceptions
There's one small problem with the ExceptionHandler as I've described it above. The particular exception being thrown by the phantom requests, ArrayIndexOutOfBounds, was a result of *how* I was building request objects in my system. If I changed the way I listened for requests and built representations of them in my system, the phantom requests might throw a different kind of exception. In other words, my ExceptionHandler depended on implementation details of my RequestBuilder. Not good!

I therefore decided to build my own exception, called a PhantomRequestException. This is actually very easy to do--you simply make a class that extends Java's Exception class. I can then deliberately throw that exception when I receive an incoming phantom request. There are a few really nice benefits to this approach. First, as I described, it is not dependent on implementation details. Second, it's more descriptive to people reading my code--it probably wouldn't be immediately obvious to someone why I'm choosing to ignore ArrayIndexOutOfBounds exceptions, for example, but it makes sense to see that PhantomRequest exceptions are gracefully ignored. Third, it focuses on a specific problem--I don't necessarily want to catch **all** ArrayIndexOutOfBounds exceptions because if it happens somewhere else for some other reason I want to know about it. Finally, it allows me to "fail fast." I want to identify problems as soon as possible and deal with them immediately. The longer you let the results of a problem trickle into your system, the more dangerous it becomes. I can throw my custom PhantomRequestException as soon as I identify the incoming request as a phantom request, rather than waiting for it to get to the ResponseBuilder and dealing with it there.
