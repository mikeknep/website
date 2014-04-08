---
layout: post
title: Handrolling Mocks in Java
---

In my last post, I briefly mentioned the Strategy Pattern, which makes switching between different implementations (or "strategies") trivial. In my Tic Tac Toe game, for example, the Strategy Pattern allows me to easy change a generic Player object from, say, a Human to an Unbeatable Computer. The Strategy Pattern is itself a demonstration of the Open/Closed Principle, which states that objects should be open for extension but closed for modification. Excellent! But, if an object is open for extension presumably indefinitely, how do we test it?

### Quick note on Java
My examples here are in Java, for a couple of reasons: first, I am working on learning the language so I need the practice, and second, I've found some of Java's characteristics better illuminate some of the concepts and vocabulary related to the design principles and patterns. In particular, the way Java handles _interfaces_ is important. In Java, an interface defines a sort of "contract" to which its _implementations_ must adhere. For example, if I create this interface:

{% highlight java %}
interface Television {
	public void channelUp();
	public void channelDown();
	public void volumeUp();
	public void volumeDown();
}
{% endhighlight %}

...then any class implementing that interface _must_ have `channelUp()`, `channelDown()`, `volumeUp()`, and `volumeDown()` methods. They can have additional methods of their own, but those four absolutely must be included. For example, an HDTV that implements the Television interface and can also record shows:

{% highlight java %}
public class HDTV implements Television {
	public void channelUp() {
		this.channel += 1;
	}

	public void channelDown() {
		this.channel -= 1;
	}

	public void volumeUp() {
		this.volumne += 1;
	}

	public void volumeDown() {
		this.volume -= 1;
	}

	public void record() {
		// start recording a show;
	}
}
{% endhighlight %}

I've found Java to be extremely helpful in understanding interfaces and implementations--far more so than Ruby, which is much more lenient.

### Setup
Imagine we have a Greeter class, which is simply responsible for saying hello to someone at the door. However, different people serve as the greeter each week, and each person has their own personality--one is very formal, while another is more casual. Using the Strategy Pattern, we can create a Personality interface with specific implementations, and swap those in and out of a particular Greeter:

{% highlight java %}
public class Greeter {
	private Personality personality

	public Greeter(Personality personality) {
		// this is a constructor method, similar to initialize in Ruby; a Greeter must be instantiated with a Personality object
		this.personality = personality;
	}

	public String greet() {
		// the Greeter's greet method simply calls its personality's greet
		return this.personality.greet();
	}
}


interface Personality {
	public String greet();
}

public class FormalPersonality implements Personality {
	public String greet() {
		return "Good evening, sir.";
	}
}

public class CasualPersonality implements Personality {
	public String greet() {
		return "What's up, bro?";
	}
}

//
FormalPersonality fp = new FormalPersonality();
CasualPersonality cp = new CasualPersonality();

Greeter formalGreeter = new Greeter(fp);
Greeter casualGreeter = new Greeter(cp);

formalGreeter.greet(); // => "Good evening, sir."
casualGreeter.greet(); // => "What's up, bro?"
{% endhighlight %}

With the above setup, we can easily swap in and out different personalities for our greeter. We can also easily add new personality types--perhaps a SouthernPersonality that says "Howdy, y'all!"--without changing any of the existing code. Great!

Each class implementing the Personality interface obviously has its own tests, in which we simply assert that the string returned by the `greet()` method is what we expect:

{% highlight java %}
public class CasualPersonalityTest() {
	@Test
	public void testGreetsSomeoneCasually() {
		CasualPersonality cp = new CasualPersonality();
		assertEquals("What's up, bro?", cp.greet());
	}
}
{% endhighlight %}

The question is, how do we test the _Greeter_ class's `greet()` method?

### A WRONG Way
My first thoughts went something like this: we know the Greeter class's `greet()` method will return a String, we just don't know what specific String it will be (that depends on the personality). So, I guess we can just test that the method returns a String, like this:

{% highlight java %}
public class GreeterTest() {
	@Test
	public void testGreetMethodReturnsString() {
		Greeter greeter = new Greeter();
		assertEquals("".getClass(), greeter.greet().getClass());
	}
}
{% endhighlight %}

Oops, wait a second--a greeter has to be instantiated with a personality. Which one should I choose? Well, what if we create both personalities, select one randomly, and make sure it works? Something like:

{% highlight java %}
@Before
public void setUpPersonalities() {
	ArrayList<Personality> personalities = new ArrayList<Personality>();

	FormalPersonality fp = new FormalPersonality();
  CasualPersonality cp = new CasualPersonality();
	SouthernPeronality sp = new SouthernPersonality();

  personalities.add(fp);
  personalities.add(cp);
  personalities.add(sp);

  Random generator = new Random();
  int index = generator.nextInt(personalities.size());

  Personality personality = personalities.get(index);
}
{% endhighlight %}

Then I can pass that personality into the Greeter object that I instantia-... **UGH!**

This is clearly out of control. Why create a bunch of objects when I'm only _barely_ using one of them to test a _different_ object?! Am I going to keep adding new personalities like my HawaiianPersonality (`.greet(); //=> "Aloha!"`) to this test as I add them to my code? If one or two personalities break, but not all of them, my Greeter test will only fail intermittently, which is a confusing situation to debug. There's got to be a better way!

### Mocks
We have an external dependency--we need a personality object for our test--but we want to keep our Greeter test focused on the Greeter class. We want _full control_ over what our test is testing, rather than a test that behaves differently on each run. We want to test the return value of the Greeter's `greet()` method, not the _class_ of that return value. This is a perfect situation for a mock. A mock is an object used just in the test that stands in for a real object. We can define the behavior we need from it for the mock, knowing that the true objects our mock is mocking have been tested in their own tests.

{% highlight java %}
class MockPersonality implements Personality {
	public String greet() {
  	return "foo";
	}
}

public class GreeterTest {
	@Test
	public void testGreetsSomeone() {
		MockPersonality mockPersonality = new MockPersonality();
    Greeter greeter = new Greeter(mockPersonality);

    assertEquals("foo", greeter.greet());
	}
}
{% endhighlight %}

This test is now cleaner, lighter, more readable, and more focused, thanks to mocking out the necessary personality object.