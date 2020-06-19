---
layout: post
title: Java Interfaces Are Awesome
---

My two favorite things about Java are interfaces and (on the good days) the certainty of static typing. This post provides an example of how interfaces are useful in testing.

In Java, an interface defines a "contract" to which implementations (classes) absolutely must adhere. For example, this `ResponseBuilder` interface stipulates that all classes implementing it must contain three methods:

```java
public interface ResponseBuilder() {
  public String getStatus();
  public HashMap<String, String> getHeaders();
  public byte[] getBody();
}
```

Combined with Java's statically-typed nature, I not only know that every class implementing this interface will have those three methods, but I have a pretty good idea of what they'll return (or at least what kinds of methods I'll be able to call on the return values). This kind of certainty/security is invaluable.

Among the many places interfaces are useful is in testing. My routing application has several classes that implement the above `ResponseBuilder` interface, but handle different kinds of requests (ex. directories, partial content, different request methods, etc.). I also have a `Responder` class that relays the data from a particular ResponseBuilder back to the server. To test the Responder, I need to give it some ResponseBuilder to work with, but which one should I use? OptionsResponseBuilder, FileResponseBuilder, MissingResourceResponseBuilder... The correct answer is a MockResponseBuilder. Interfaces make mocks extremely simple; by implementing the same interface as the other builders, I know the MockResponseBuilder will behave similarly enough to the others to be an effective stand-in for the Responder test.

```java
public class MockResponseBuilder implements ResponseBuilder {
  public String getStatus() {
    return "999 Mock Status";
  }

  public HashMap<String, String> getHeaders() {
    return new HashMap<String, String>();
  }

  public byte[] getBody() {
    return "Mock body".getBytes();
  }
}
```

Several of the other ResponseBuilder implementations have unique private methods in their constructors to handle their specific duties. If I used one of those ResponseBuilders in the Responder test, I'd need to make sure I also supply test data that accurately simulates what that ResponseBuilder would receive. This would be a whole lot of setup required for the Responder test. Instead, I'll call the Responder's `sendData()` method with an instance of MockResponseBuilder as the builder argument. The MockResponseBuilder behaves the same way as the other builders, but it doesn't require being instantiated with specific data (or any data, actually).

However, the `sendData()` method is also concerned with a destination--it's sending the data *somewhere*, after all. In production, the Responder sends the three fields from the ResponseBuilder to an ObjectOutputStream initialized with regular `System.out`. This allows the server to collect the raw objects by listening to the application process's output stream and not need to format/present/parse data as part of the exchange. Originally, my Responder just wrote directly to this output stream like this:

```java

public class Responder {
  public static void sendData(ResponseBuilder builder) throws Exception {
    ObjectOutputStream oos = new ObjectOutputStream(System.out);
    oos.writeObject(builder.getStatus());
    oos.writeObject(builder.getHeaders());
    oos.writeObject(builder.getBody());
    oos.close();
  }
}
```

This code works, but how do I test it? I'd need to access to the output stream of `System.out`, specifically as some kind of object stream, which sounds painful (capturing basic `System.out` is difficult enough as is). It would be nice if I could send the data to some other location for my tests...

Pause. This right here is an important moment in the thought process. I feel confident that this particular routing application will only be communicating with my server, hence the Responder class was written hardcoded to send to a System.out ObjectOutputStream. An experienced developer might look at the Responder class and feel it's too inflexible, since one can't substitute in a different destination. What if we wanted to write the data to a file or a display? To this question, a less experienced developer might respond that the work required to make it less rigid is needless complexity--is that functionality really necessary when it will never be used? However, the test case is *exactly that different destination and use case*. Just because the Responder won't use a different destination in *production* doesn't mean there isn't a use for flexibility in the class. The context of the test suite should be considered just as valid and important as the context of production. (PS: Open-Closed Principle!)

So, rather than hardcoding the destination inside `sendData()`, we'll pass in a destination as an argument somehow. Guess what? Another interface!

```java
public interface OutgoingStream {
  public void write(Object object) throws Exception;
  public void close() throws Exception;
}

public class ObjectOutgoingStream implements OutgoingStream {
  private ObjectOutputstream oos;

  public ObjectOutgoingStream() {
    this.oos = new ObjectOutputStream(System.out);
  }

  public void write(Object object) throws Exception {
    oos.writeObject(object);
  }

  public void close() throws Exception {
    oos.close();
  }
}

public class MockOutgoingStream implements OutgoingStream {
  private boolean isClosed = false;
  private Object writtenObject;

  public void write(Object object) throws Exception {
    this.writtenObject = object;
  }

  public void close() throws Exception {
    this.isClosed = true;
  }

  public boolean getIsClosed() {
    return this.isClosed;
  }

  public Object getWrittenObject() {
    return this.writtenObject;
  }
}
```

The ObjectOutputStream sets up the `new ObjectOutputStream(System.out)` like in the original code, and the `writeObject()` method is wrapped in the interface's more generic `write()` method. Meanwhile, the MockOutputStream just stores the written object as a field in memory for easy access.

The Responder class and its test now look like this:

```java
public class Responder {
  public static void sendData(OutgoingStream outStream, ResponseBuilder builder) throws Exception {
    outStream.write(builder.getStatus());
    outStream.write(builder.getHeaders());
    outStream.write(builder.getBody());
    outStream.close();
  }
}

public class ResponderTest {
  @Test
  public void itSendsDataToOutgoingStream() throws Exception {
    ResponseBuilder mockResponseBuilder = new MockResponseBuilder();
    MockOutgoingStream mockOutgoingStream = new MockOutgoingStream();
    Responder.sendData(mockOutgoingStream, mockResponseBuilder);

    assertTrue(mockOutgoingStream.getIsClosed());
    assertArrayEquals("Mock body".getBytes(), (byte[]) mockOutgoingStream.getWrittenObject());
  }
}
```

The Responder test now sufficiently proves that the appropriate methods are called in `sendData()` without needing to jump through the hoops of instantiating a live ResponseBuilder with production-quality data or accessing System.out as an ObjectInputStream. Instead, we know the mocks are effective stand-ins because they adhere to the same interface as the production classes they are mocking, and the test is focused exclusively on the behavior of the class under test, Responder.
