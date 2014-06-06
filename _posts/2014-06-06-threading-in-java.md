---
layout: post
title: Threading in Java
---

A primer on working with threads in Java.

### Processes and Threads

To understand threads, it helps to first understand processes. A process is basically a "unit of execution". It is a self-contained execution environment, which means it has its own resources like memory space. In some cases, an application is just a single process running on a computer, but as I demonstrated in my last post, an application can launch additional processes to be run. My Java server uses a `ProcessBuilder` to create and run the external routing application as a separate process.

Threads are similar to processes, but "lighter weight," so to speak. The big difference is that threads exist within a process, which means they share the process's resources (like memory). It is important to know that every process contains at least one thread. A very simple demonstration of this is sleeping in Java via the method `Thread.sleep(100)`. This method tells the currently running thread to sleep for 100ms. You don't have to create a thread anywhere to run this method--the main thread of the process is there by default.

### Integration testing with threads

My first implementation of multi-threading came in my tests. Despite sufficient unit tests for the classes within my server, I felt a sliver of doubt that the whole server application actually ran properly when fired up on the command line. Obviously manually firing up the server and clicking around every time is no good; I needed an "integration level" test to run through the application at a high level and make sure everything was wired together properly. These are generally not too difficult to write for an application, but the server posed a unique problem. When the server is instantiated and executes its `run()` method, it sits patiently, infinitely, waiting for a connection. Even if I tried to make a connection on the very next line of the test, the code execution would never reach that line. The process or thread was effectively stuck. My mock client connection would have to be initialized somewhere else--from a separate thread.

Realizing I needed to use threading, my first thought was to make separate threads for the server and the client and tie them up together. However, I soon realized that this would be overkill, since (as I explained above) the test itself has/is a thread available to me. I decided to put the server in a separate thread and act as the client from the test's main/default thread. Here's the beginning of the test defining the server's thread:

{% highlight Java %}

@Test
public void itReceivesRequestAndSendsResponse() throws Exception {
	Thread serverThread = new Thread(new Runnable() {
		@Override
		public void run() {
			try {
				ServerSocket serverSocket = new ServerSocket(2468);
				Server server = new Server("public/", serverSocket, "public/mock.jar");
				server.run();
			} catch (Exception e) {}
		}
	});

	serverThread.start();
	// ...
}

{% endhighlight %}

A thread needs to be initialized with an instance of some class that implements Java's `Runnable` interface, which mostly just means it has a `run()` method. In my test, I instantiate my server thread with a neat Java trick called an "anonymous class". This is a one-off class--I won't need to use it anywhere else--that simply defines a `run()` method to implement Runnable. The `serverThread.start();` line calls that run method to fire up the server, but in its own separate thread, leaving me free to continue to write code in the original thread of the test:

{% highlight Java %}

// ...
serverThread.start();

Socket socket = new Socket("localhost", 2468);
PrintWriter writer = new PrintWriter(socket.getOutputStream(), true);
writer.println("GET / HTTP/1.1");
writer.println("");
writer.flush();

InputStreamReader sir = new InputStreamReader(socket.getInputStream());
BufferedReader bufferedReader = new BufferedReader(sir);
String firstLine = bufferedReader.readLine();
socket.close();

assertEquals("HTTP/1.1 200 OK", firstLine);

{% endhighlight %}

The test simply opens up a socket connection to the server, makes a basic request, and ensures that it receives a 200 response. With this test in place, I can feel more confident making larger-scale changes like completely gutting the routing logic, and I don't need to keep manually starting the server and clicking around to be sure it works.

### Multi-threading in the server

Implementing threads into the production code of the server is actually less complicated that in the test. As I demonstrated in the test, we need a class that implements Runnable (with a `run()` method) that we pass in to a thread instance for execution. Rather than using an anonymous class, however, the production code will use a fully defined class. I decided to call this class `Worker`. It essentially holds the high-level wiring that had been in my Server class being executed in the infinite `while (true)` loop. What's nice is that by isolating the logic of what happens for an individual test from the class listening for and accepting multiple requests, I can easily test the wiring of a single connection (my Worker test) without needing a server spinning in a separate thread. It also pushes the details down, so that the Server class's `run()` method now just looks like this:

{% highlight Java %}

public void run() throws Exception {
	while (true) {
		SocketConnection clientConnection = new SocketConnection(serverSocket);
		threadPool.execute(new Worker(clientConnection, rootDirectory, routingApplication));
	}
}

{% endhighlight %}

The intent and responsibility of this class and method is much better expressed: wait for a connection, and when you get one, execute a Worker to handle it in a thread. At the same time, the Worker class better expresses the high-level process of a single request/response exchange.

You might be wondering what that `threadPool` object is. It is an instance of Java's `ExecutorService` class, instantiated via `Executors.newFixedThreadPool(16);`. The `ExecutorService` is a semi-magical object that manages startup and termination of tasks. I instantiate an instance of this class, called threadPool, as a field on my Server upon the latter's instantiation, and it manages spinning off new threads appropriately.