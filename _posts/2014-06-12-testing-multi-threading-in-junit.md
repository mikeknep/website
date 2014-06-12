---
layout: post
title: Testing Multi-threading in Junit
---

My last post was about implementing threading and concurrent processing in my Java server. This post demonstrates how I'm testing that functionality with Junit.

8th Light's internal server test suite, [Cob Spec](https://github.com/8thlight/cob_spec), performs a stress test on the server by blasting 4,096 simultaneous requests at the server and expecting them all to return 200 status codes. This approach is effective at testing multithreading, but not very efficient--I don't want to have to load up Cob Spec every time I want to make sure my implementation of threading still works. Instead, I'd prefer having a test in my application's own Junit test suite that proves the threading technique is working.

My [previous post](http://mikeknep.com/2014/06/06/threading-in-java.html) demonstrates how to start a separate thread in Junit in which the server can sit and wait for requests. I'll need to do that again in this test, but instead of using the remainder of the main test thread to simulate a request to the server and asserting a 200 response, this multithreading test needs to make *two* requests. Obviously I don't want to just make one request and another right afterwards--that's hardly any different than running my test that makes one request twice in a row. Rather, I want to simulate these requests coming in as close to the same time as possible and being handled by the server independently of one another.

Making a request to the server in a separate thread is not particularly difficult, but we have to get a little creative with the assertions the test makes. Unfortunately, Junit cannot properly execute assertions made in separate threads--only assert statements made in the main thread of the test will affect the test's result. For example:

{% highlight java %}

@Test
public void itDoesntAssertInSeparateThreads() {
	Thread otherThread = new Thread(new Runnable() {
		@Override
		public void run() {
			assertTrue(false);
		}
	});

	otherThread.start();
	assertTrue(true);
}

{% endhighlight %}

Despite the obviously false Junit assertion `assertTrue(false)` in `otherThread`, this test will pass. Therefore, we can't assert that the socket connection in a separate thread receives a 200 response, as that assertion will never actually get checked.

I considered adding some sort of counter in my thread pool and asserting something like "the count of the number of threads that have been generated is two." However, there are two general problems with this approach. First, it requires writing production code that does not add any functionality and is only used for tests, which feels wrong to me. Second, this test would ultimately be testing an implementation detail and may not actually accurately test the *behavior* of the application.

This latter point is especially important. At a high level, the goal of tests is to make sure the application behaves correctly. With that in mind, what is the ideal behavior of the server with regards to multi-threading? Basically we want to make sure that the server can accept multiple requests and handle them independently of one another. In other words, the requests should *not* queue up and be dealt with first come first serve. Without threading, the server would be effectively inaccessible from the time one socket connection is made to the time that socket is closed.

That actually doesn't sound too difficult to simulate! We can have one "client" thread connect to the server, sleep for a while, and then print a request to the server. In the meantime, a second client connects to the server and immediately sends its request. We can then verify two things: first, that the second client receives a 200 response, and second, that the second client receives a response before the first, slow client receives a response. Check it out (note, I've refactored some functionality out into separate methods for readability in the test):

{% highlight java %}

@Test
public void itHandlesMultipleRequestsIndependently() throws Exception {
	Thread slowClient = new Thread(new Runnable() {
		@Override
		public void run() {
			try {
				Socket socket = new Socket("localhost", 9110);
				Thread.sleep(3000);
				makeGETrequest(socket);
				socket.close();
			} catch (Exception e) {}
		}
	});

	runServer(9110);
	Thread.sleep(100);

	slowClient.start();
	Thread.sleep(100);

	Socket socket = new Socket("localhost", 9110);
	makeGETrequest(socket);
	String firstLine = readFirstLine(socket);
	socket.close();
	Date secondRequestCloseTime = new Date();

	assertEquals("HTTP/1.1 200 OK", firstLine);

	slowClient.join();
	Date firstRequestCloseTime = new Date();
	
	assertTrue(secondRequestCloseTime.before(firstRequestCloseTime));
}

{% endhighlight %}

The `join()` method on the `Thread` class waits for the process executing in the thread to finish, so `Date firstRequestCloseTime` will represent the moment the slow client's socket closes and `run()` terminates.

The slow client sleeps for 3 full seconds (3000 ms) between connecting and sending its GET request. Determining how long to sleep was somewhat arbitrary--I wanted it to be long enough to definitely end after the second client's request, but not so long that my tests became frustrating to run. Three seconds works well, and is a vast improvement over waiting for Cob Spec. More importantly, though, this test provides more complete coverage of my production code within the app itself, rather than relying on external tests that may or may not be available.