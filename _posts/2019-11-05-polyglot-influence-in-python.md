---
layout: post
title: "Polyglot Influences in Python"
8thLightURL: https://8thlight.com/blog/mike-knepper/2019/11/05/polyglot-influence-in-python.html
---

One of my favorite aspects of working in different languages on various client projects is seeing how concepts learned in one paradigm bleed into others.
My latest professional work is written in Python, but I find myself using many strategies that I've picked up from working in other languages.
This post surveys some of the influences my past experience has had on the way I write Python today.
I should note that the other languages mentioned here are definitely not the _original sources_ of these concepts; rather, they're simply where I personally first or most often encountered them.


### Static Types (TypeScript, Scala)

I first used static typing during my apprenticeship on our classic Java HTTP server project, but I didn't really appreciate the full value of types until I used them on production client code.
Wrapping my mind around React for the first time was challenging, but I remember thinking it would've been exponentially more difficult were I not using TypeScript.
The compiler was invaluable, reminding me time and again what values were and weren't available in my components' props and states.

Later, a different client was all-in on Scala, and the benefits became even more obvious as we pushed more and more rules into the type system.
Compile-time checks eliminated an entire category of unit tests, allowing us to focus the tests we _did_ still need to write (types and tests aren't mutually exclusive!) on actual business logic.
Large refactorings were performed with confidence, at times seemingly driven by the compiler error messages (this phenomenon is especially common, and delightful, in Elm).

Python, of course, is a dynamic language, but it has a "gradual typing" library called [MyPy][mypy].
Gradual typing basically means you can add type annotations to parts of your codebase and type check those areas, without necessarily covering the entire codebase.
Unlike true static languages, Python does not have a compilation step; rather, the developer runs a `mypy` Python task against the codebase, and it reports typechecking results.
Configuring this to run immediately before your unit test suite simulates the "compile and run" process of other languages.

Leveraging MyPy doesn't require sacrificing the benefits of dynamic typing even in the areas where you do provide type annotations.
At the simplest level, MyPy includes an `Any` type that you can use as an escape hatch in a pinch.
A more sophisticated technique is to use a `Protocol`, which in some respects can be thought of as "formalized duck typing."
A tic-tac-toe game, for example, might have a function that takes one of any number of different kinds of "players," each of which can choose a spot to play on the board.
We can represent this with a protocol (the ellipses are exactly what you'd write in production for the protocol, but the `pass` calls would actually be returning some `Spot` object):

```py
class Player(Protocol):
    def pick_spot(self, board: Board) -> Spot:
        ...


class HumanPlayer:
    def pick_spot(self, board: Board) -> Spot:
        # implementation elided, maybe reads stdin from the terminal
        pass


class SimpleAIPlayer:
    def pick_spot(self, board: Board) -> Spot:
        # implementation elided, maybe just chooses a random open spot on the board
        pass
```

Note that I don't need to explicitly state that `HumanPlayer` and `SimpleAIPlayer` implement the `Player` protocol.
Just having the `pick_spot` method defined is enough for MyPy to understand that instances of these classes can be passed to something expecting the `Player` protocol.
I still get the essence of duck typing, but with an extra set of eyes checking for mistakes before runtime.
I'd much rather MyPy tell me I accidentally named a new player's method `choose_spot` instead of `pick_spot`, or required a different argument instead of a `Board`, before a user experiences an error.

Finally, because MyPy is a separate process and Python does not have a compilation step, you can always run your Python code even while MyPy is reporting type errors.
This can be really useful if your types are complicated and you're pretty sure everything should work as-is, but can't figure out why the compiler is complaining;
rather than being forced to resolve the type issues first, you can start up the application and explore what happens in different live scenarios.
Perhaps seeing an actual runtime error will help you identify what needs to change.
These situations in general can be fascinating: the compiler asserts some guarantee is not being met, but the developer "knows" the code should work given their knowledge of the domain.
Often times the resolution to these disagreements is a combination of adding more nuance to the type annotations (perhaps something is `Optional`, or needs to be made generic?) and rethinking how data flows through the system.


### Data Objects (Clojure, Scala)

The first new language I learned at 8th Light was Clojure.
Coming from Ruby, I initially found it very disorienting.
What do you mean I can't define a class or object?
_Everything_ is supposed to be an object!

Before long, however, something clicked.
Clojure was forcing me to separate **data** (e.g. lists, dictionaries, integers, etc.) from **behavior** (i.e. functions).
In Clojure this separation is particularly extreme, but I started seeing it in other places, too (and—swoon—with types!).
Scala's "case classes" and Rust's "structs" are two excellent tools for modeling immutable data.
In both of these cases, as with the Python equivalent below, methods can still be defined on the objects themselves, but their essence lies in defining the structure of data.

Python 3.7 introduced the `dataclasses` module.
At first glance, this just looks like syntax sugar for Plain Old Python Objects:

```py
from dataclasses import dataclass

@dataclass
class Car:
    make: str
    model: str


class Auto():
    def __init__(self, make: str, model: str):
        self.make = make
        self.model = model
```

However, dataclasses provide quite a bit more convenience.
Perhaps the greatest example is equality; 99% of the time, when I'm comparing data, I want to know if the _values_ are identical, not whether two variables are pointing to the same instance in memory:

```py
>>> car = Car("honda", "civic")
>>> car == Car("honda", "civic")
True

>>> auto = Auto("honda", "civic")
>>> auto == Auto("honda", "civic")
False
```

Also, it's common to need a copy of an existing data class instance with just a few modifications.
The `replace` function provides something akin to "immutable updates" like Scala's `copy` on case classes or Elm's update on records:

```py
>>> civic = Car("honda", "civic")
>>> accord = dataclasses.replace(civic, model="accord")
>>> print(civic)
Car(make='honda', model='civic')
>>> print(accord)
Car(make='honda', model='accord')
```

Python has long had first-class support for functions (by which I mean a function can stand alone and does not need to be defined within some arbitrary class).
Dataclasses now allow you to write Python in an even more functional and less object-oriented style.


### Injecting the Environment as a Dependency (Clojure)

My latest project leans heavily on AWS's "serverless" offerings, including Lambda and Fargate.
These tools use environment variables as the primary way to set runtime configuration for their tasks.
In most contexts, setting these values is straightfoward:
an `.env` file can be read when running locally;
Terraform configuration is pretty clear;
the AWS web console lets you type them in like a form before launching; etc.

Unfortunately, _unit testing_ code that depends on environment variables can be a tremendous pain.
Resetting them between tests is easy to mess up, and local `.env` files used for running the code locally can interfere with the test environment config.

While combatting this issue, I remembered a Clojure library called [Component](component).
This library's primary concern is the lifecycle management of stateful dependencies—one classic example is a database to which various functions in your codebase share a connection.
On one of my first client projects, we refactored our Clojure application away from a globally available database connection reference to explicitly pass that connection object to any function querying that database.
This had two neat benefits:
first, it became clear just by reading function signatures which parts of the code were doing something database-related and which were not (since the database could no longer "magically appear" at some very low level).
Second, it became easier to test, as a mock database could just as easily be passed to any function requiring it.

I realized that a similar technique could be used in my serverless Python code.
Rather than importing `os` at some low level of the code to call `os.environ.get("MY_VAR")`, I can import `os` at the very top-most level and pass the entire environment in and down to wherever it is needed.

```py
import os
from typing import Dict

def main(environment: Dict[str, str]):
    _uses_env_var(environment)
    _does_not_use_env_var()


def _uses_env_var(environment: Dict[str, str]):
    foo = environment.get("FOO")
    print(f"FOO was set to {foo}")


def _does_not_use_env_var():
    print("Hello world!")


if __name__ == "__main__":
    main(os.environ)
```

Notice the MyPy annotation for the environment: `Dict[str, str]`.
This technique makes it much easier to test code that depends on environment variables in production, because from the perspective of those functions, they aren't using _environment_ variables anymore at all—they're just using a regular dictionary!


### Hide Concrete Constructors and only Expose Protocols (Elm)

Rob Looby wrote a great [post][rob-elm-ocp] about Elm and the Open-Closed Principle.
In it, he describes how the specific variants of a union type can be kept private to clients of that type, allowing new variants to be added without affecting all the functions throughout the codebase consuming that union type.

There are some caveats to attempting something like Rob's approach in Python, none greater than the fact that Python has no concept of "public" vs. "private."
However, Python code often uses an underscore prefix to signal "this is intended to be private" to the reader.
I use that convention in the snippet below.

Recently I needed to support reading data from various files, but those files could be located either on my local machine or in an S3 bucket.
I created a `DataSource` protocol to define the functionality I needed, namely returning each line from the file, and the file's path (meaning its location or address):

```py
class DataSource(Protocol):
    def as_lines(self) -> Iterable[str]:
        ...

    def path(self) -> str:
        ...
```

Next, I defined my implementations.
Note the underscore prefixes in the class names.
My goal here is that nothing outside this module should know about or be able to distinguish between these two types.
Everything external should only need to know that it has "some" `DataSource`.

```py
class _LocalSource:
    def __init__(self, filepath):
        self.filepath = filepath

    def as_lines(self):
        return [line.rstrip(b"\n") for line in open(self.path, "rb")]

    def path(self):
        return self.filepath


class _S3Source:
    def __init__(self, bucket, key, s3_client):
        self.bucket = bucket
        self.key = key
        self.s3_client = s3_client

    def as_lines(self):
        body = self.s3_client.get_object(Bucket=self.bucket, Key=self.key)["Body"]
        return body.iter_lines()

    def path(self):
        return f"s3://{self.bucket}/{self.key}"
```

Lastly, since the concrete implementations' constructors are (intended to be) private, I need to define some way of getting a `DataSource`.
As described above, this will be configured with environment variables (some boilerplate error handling removed for clarity):

```py
def get_data_source(environment: Dict[str, str]) -> DataSource:
    location_type = environment.get("DATA_FILE_LOCATION_TYPE")

    if location_type == "s3":
        source = _build_s3_source(environment)
    elif location_type == "local":
        source = _build_local_source(environment)
    else:
        raise DataSourceConfigError("DATA_FILE_LOCATION_TYPE must be 's3' or 'local'")

    return source

def _build_s3_source(environment: Dict[str, str]) -> _S3Source:
    bucket = environment.get("DATA_FILE_S3_BUCKET")
    key = environment.get("DATA_FILE_S3_KEY")
    client = aws.build_s3_client(environment)

    return S3Source(bucket, key, client)


def _build_local_source(environment: Dict[str, str]) -> _LocalSource:
    filepath = environment.get("DATA_FILE_LOCAL_PATH")
    return LocalSource(filepath)
```

The end result is a single public function, `get_data_source`, that takes in environment configuration and returns some implementation of the `DataSource` protocol.
Every other part of the application can call this function and know that whatever it receives will have `as_lines` and `path` defined.
If later on we need to get data from some third location type—be it a database, Azure Blob storage, whatever—we only need to change this one file to parse the relevent configuration from the environment, and _nothing else_ needs to change.


### Polyglot Pragmatism

Python made the most sense for this client project given the team's skill set, some existing applications, and the problem domain.
However, coming into the engagement, I personally hadn't written a single line of Python.
I took time to learn some of Python's conventions and style, and asked many questions of my teammate with extensive Python experience.
However, my experience with many other languages in similar problem domains meant I wasn't going in to this project completely empty-handed;
to the contrary, I have an arsenal of techniques that can be applied in a variety of contexts.

Of course, there is a fine line to this stuff.
I still remember a conversation with one of my teams from several years ago.
We were working in a legacy Rails app and debating a few implementation options to some problem.
One teammate, a burgeoning ML enthusiast (now expert), suggested creating a `Result` class with `Error` and `Success` "variants" that we could use for error handling.
Another, well versed in JavaScript, demonstrated how we could define callbacks for success and failure cases, passing them in from a controller.
After some discussion, we ultimately landed on... a `succeeded?` method and an `if/else` statement.

Conventions, existing patterns, team experience levels, and business priorities all factor into how the code gets written.
The goal is not to turn dynamic languages into statically typed ones, nor needlessly reinvent wheels.
On the other hand, there might be a technique that isn't common in your current language but could work really well in your current context.
At the end of the day, pragmatism should always win out.
Developing enough experience to recognize what is and isn't pragmatic takes time, but that timeline can be shortened by exposing yourself to a wide variety of languages, paradigms, and problems, and paying attention to what works well and why.



[mypy]: https://mypy.readthedocs.io/en/latest/
[component]: https://github.com/stuartsierra/component
[rob-elm-ocp]: https://8thlight.com/blog/rob-looby/2017/08/08/elm-and-the-ocp.html
