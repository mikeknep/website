---
layout: post
title: Single Responsibility Principle
---
As my Ruby bank develops into a more mature application, Rylan and I continually discuss the Single Responsibility Principle. This design principle seems fairly self explanatory, but I've found it subtly tricky to follow while building my bank app, particularly with regards to defining what constitutes a "single" responsibility. That said, it has been worth the effort  and occasional headache.

## SRP in theory
Consider a simple Person class:

```ruby
class Person
  attr_reader :first_name, :last_name
  def initialize(first, last)
    @first_name = first
    @last_name = last
  end

  def full_name
    "#{@first_name} #{@last_name}"
  end

  def greet
    puts "Hello, #{full_name}."
  end
end

marty = Person.new("Marty", "McFly")
marty.full_name # => "Marty McFly"
marty.greet # => "Hello, Marty McFly."
```

Seems basic enough; there's hardly anything going on here. However, what if we want to change the way we greet a person--say, a more casual "Hi, Marty!"? In the setup above, we'd go into our Person class and change the `greet` method accordingly. In doing so, we'd demonstrate a violation of the Single Responsibility Principle.

The Person class above has two responsibilities--defining a Person object and interacting with a Person object. The greeting uses properties of the object, but it does not fundamentally affect how we define what a "person" is. Sure it's pretty basic now, but what if we want to define more attributes on Person objects (maybe an age or a gender), or we want to add different kinds of greetings? It's not too difficult to imagine this class collecting more and more methods and spiraling out of control.

The solution, according to the SRP, is to separate concerns out into different classes that have narrower, more focused responsibilities.

```ruby
class Person
  attr_reader :first_name, :last_name
  def initialize(first, last)
    @first_name = first
    @last_name = last
  end

  def full_name
    "#{@first_name} #{@last_name}"
  end
end

class PersonGreeter
  attr_reader :person
  def initialize(person)
    @person = person
  end

  def formal_greeting
    puts "Hello, #{person.full_name}."
  end

  def casual_greeting
    puts "Hi, #{person.first_name}!"
  end
end

marty = Person.new("Marty", "McFly")
greeter = PersonGreeter.new(marty)
marty.first_name # => "Marty"
PersonGreeter.formal_greeting # => "Hello, Marty McFly."
PersonGreeter.casual_greeting # => "Hi, Marty!"
```

The PersonGreeter class allows us to add all sorts of different ways to say hello to a person without changing anything about how a Person is defined (in the Person class).

## SRP in the wild
I was first introduced to the SRP with an example similar to the one above involving creating rectangles, calculating their areas, and displaying them in a console with ASCII characters. Can you imagine how it might get set up? Following the SRP, we ended up with two classes: a Rectangle class that could initialize a rectangle object with height and width properties and calculate its area, and a RectangleDisplay class that prints a given rectangle object out to the screen. It seemed straightforward enough, if not a bit overkill, but it was much harder to understand how to incorporate this design principle in a much more complex, real-world application (to the extent my bank fits that description...).

It turns out, deciding what constitutes a "single" responsibility is not always a cut and dried decision. As I noted in my last post, I've been trying to follow the Repository Design Pattern and make the method of data storage in my app configurable without affecting the rest of the code. My MemoryRepository classes and RiakRepository classes are responsible for handling the details of how to store various objects in the different kinds of repositories. In my mind, "storing an object" was the single responsibility of those classes. However, I ran into some difficulty when attempting to query those repositories to return an object or collection of objects. I set up new classes responsible for querying the repositories, but quickly realized that grabbing an object from an array (MemoryRepo) is a much different process than grabbing an object from a Riak bucket. Was I going to need unique classes for querying each kind of repository, and somehow know which query object to use each time?

The answer turned out to be changing the definition of the Repository classes' single responsibility. At first, it seemed like a violation of the SRP--aren't I now storing *and* retrieving objects, and aren't those two different things? Perhaps I could sneakily describe the single responsibility as "interacting with objects in the repository." It's a bit of a grey area, but this is a perfect example of how the SRP is not always an easy and straightforward decision. One advantage of this decision, however, is that the querying classes can remain focused on querying without needing to know the specific storage method:

```ruby
class People
  def self.all
    Repository.for(:person).all
  end

  def self.find(attribute, value)
    Repository.for(:person).find(attribute, value)
  end
end

module MemoryRepository
  class PersonRepository
    def self.all
      #details of how to retrieve all objects from memory
    end

    def self.find(attribute, value)
      #details of how to retrieve an object with a specific attribute value from memory
    end
  end
end

module RiakRepository
  class PersonRepository
    def self.all
      #details of how to retrieve all objects from Riak storage
    end

    def self.find(attribute, value)
      #details of how to retrieve an object with a specific attribute value from Riak storage
    end
  end
end
```

With this setup, if I add a third storage option, I just need to make sure that I define how to store and retrieve objects in that particular way. Both those details are specific to the particular method of data storage, so it's appropriate to define them in the data storage class. As a result, the People class can query all the different kinds of person repositories without needing any modification.
