---
layout: post
title: "Types of Types in Elm"
8thLightURL: https://8thlight.com/blog/mike-knepper/2019/02/26/types-of-types-in-elm.html
---

I've recently been working on a project in Elm, and it has been a _blast_.

I have already learned a lot from studying the language and its [excellent guide](https://guide.elm-lang.org/), and have far deeper to explore.
As someone with a long-standing interest in statically typed functional programming, and coming off of several Scala projects, I've been interested in discovering how many details I can push into the type system in order to let the compiler do the heaviest lifting.

In this post, I'll survey the different "types of types" available in Elm and draw some parallels to other languages along the way.


### Record Types

One of the first things one comes across in Elm is record types.
These are named, labeled data structures, somewhat similar to objects in JavaScript or structs in Ruby, though with quite a bit more type safety.

```elm
type alias User =
    { id : String
    , firstName : String
    , lastName : String
    , age : Int
    }
```

<span id="source-1"><a href="#footnote-1"><sup>[1]</sup></a></span>
One thing I immediately liked about records in Elm is how lightweight they are.
You cannot attach behavior or logic to them, they strictly represent _immutable data_ without any of the ceremony, superfluousness, or complexity of objects in other languages.

Record types represent one of the first steps towards type signature expressivity.
Given the `User` record type defined above, the following function signatures are effectively the same:

```elm
formatUserName : {id: String, firstName: String, lastName: String, age: Int} -> String
-- vs.
formatUserName : User -> String
```
The second definition clearly operates at a higher level of abstraction—it describes doing something with a specific, logical "noun" in our domain.
Interestingly, it is also less brittle than the first definition because we don't have to change it if and when the fields on the `User` record change.
Any alteration to the `User` record definition, even just adding a totally unrelated field, would cause the first definition of `formatUserName` to no longer compile at sites passing a `User` to it.
Under the first definition the compiler requires _exactly those fields_, no less and no more, even if they are not used in the function definition.
This can be contrasted with [interfaces in TypeScript](https://www.typescriptlang.org/docs/handbook/interfaces.html) or [traits in Scala](https://docs.scala-lang.org/tour/traits.html), which only demand that the passed argument has _at least_ the defined properties.
<span id="source-2"><a href="#footnote-2"><sup>[2]</sup></a></span>

As we strive to make our function signatures more expressive, we might next ask, what about data that are just single values rather than a collection of fields?
For example, in our `User` record type above, we defined the `id` field as of type `String` (presumably so that we could use UUID values rather than just integers).
We might want to specify that a function to look up users doesn't take any old `String`, but specifically a `UserId`:

```elm
findUser : String -> Maybe User
-- vs.
findUser : UserId -> Maybe User
```
Using what we know so far, we could define...

```elm
type alias UserId = String
```
...and use the second `findUser` signature, as well as change the `id` field in the `User` record type above from `String` to `UserId`.

However, while the function signature reads nicer to humans, we haven't actually given the _compiler_ more information to prevent nonsensical code.
The following expressions all still compile, despite not making any sense in our domain:

```elm
createUser : String -> String -> Int -> User
createUser first last age =
    { id = last  -- unless someone has a very unusual last name, this probably isn't a valid UserId
    , firstName = first
    , lastName = last
    , age = age
    }


capitalizeUser : User -> User
capitalizeUser user =
    { user
        | id = String.Extra.toSentenceCase user.id  -- it'd be weird to have a UUID with one capital letter like Af5a9ec2-703b-...
        , firstName = String.Extra.toSentenceCase user.firstName
        , lastName = String.Extra.toSentenceCase user.lastName
    }
```
The fundamental problem here lies in that keyword `alias`.
We've essentially told the compiler that `UserId` and `String` are "synonyms" that can be used interchangeably, and consequently they share the same "API".
(In Elm, types don't have "methods" defined on them, so for example the `String` type doesn't have a set of public methods defined on it the way a Ruby or JavaScript string does.
Rather, given the type alias above, any function that accepts a `String` argument can take a value we've tried to explicily define as a `UserId` in its place, and vice versa.)

The following (somewhat contrived) example demonstrates how this applies not just to primitives or single values, but also to larger record types:

```elm
type alias Book =
    { title : String
    , length : Int
    }


type alias Movie =
    { title : String
    , length : Int
    }


formatRunTime : Movie -> String
formatRunTime movie =
    let
        hours =
            (movie.length // 60)
            |> String.fromInt

        minutes =
            (modBy 60 movie.length)
            |> String.fromInt
            |> String.padLeft 2 '0'

    in
    hours ++ ":" ++ minutes


uhOh : Book -> String
uhOh book =
    formatRunTime book  -- this compiles, but doesn't make any sense!
```
`Book` and `Movie` are separate kinds of data in our domain, but because they happen to have the same shape (and perhaps there's nothing we can do about that), defining them as record types via `type alias` makes them functionally identical to the compiler.
Fortunately, there is another option available in Elm.


### Custom Types

The [official guide](https://guide.elm-lang.org/types/custom_types.html) presents custom types as Elm's way of implementing tagged unions or algebraic data types.
However, custom types can be used to define non-enum-like types, too.
Here's how we could define the types above using custom types:

```elm
type UserId = UserId String

type User = User { id : UserId, firstName : String, lastName : String, age : Int }

type alias TitleAndLength =
    { title : String
    , length : Int
    }

type Book = Book TitleAndLength
type Movie = Movie TitleAndLength
```
This may look a little strange at first, as if these definitions are recursive somehow.
However, the two identical words on opposite sides of the equals sign perform different roles.
On the left, `type UserId` establishes a new type in the codebase.
On the right, `UserId String` defines a constructor function named `UserId` that takes a single `String` argument.
This is somewhat equivalent to the following Java code:

```java
public class UserId {
    public UserId(String s) {
        // ...
    }
}
```
Defining a custom type like this provides a sort of "wrapper" around the internal data structure that must be unwrapped when used.
This provides quite a bit of extra type safety; let's look at `UserId` first:

```elm
-- type UserId = UserId String (reminder from above)

userId : UserId
userId = UserId "d948d0af-90a2-4483-8e8d-00596a3eeed1"
```
The raw UUID string value is passed to the `UserId` constructor function, returning a value `userId` that is explicitly of type `UserId`.
We can no longer pass `userId` to functions expecting a `String`:

```elm
String.reverse userId  -- compiler error: String.reverse expected a String but got a UserId
```
If we need to access the raw value, one option is to use a `case` statement:

```elm
case userId of
    UserId rawStringValue ->
        String.reverse rawStringValue
```
Unlike the union types in the Elm guide examples, our `UserId` type has just a single variant, so there is only one branch to the `case` statement.
What's important and helpful here is that the developer is forced to acknowledge that they are working with a `UserId` value;
the `String` value "inside" is still accessible, but not without explicit consideration of its context.

Here's another example with the no-longer-identical types `Book` and `Movie`, using destructuring in the function definition to access the inner record:

```elm
formatRunTime : Movie -> String
formatRunTime (Movie movieDetails) =
    let
        hours =
            (movieDetails.length // 60)
            |> String.fromInt

        minutes =
            (modBy 60 movieDetails.length)
            |> String.fromInt
            |> String.padLeft 2 '0'

    in
    hours ++ ":" ++ minutes


uhOh : Book -> String
uhOh book =
    formatRunTime book  -- compiler error: formatRunTime expected a Movie but got a Book
```
Now, not only are our function signatures expressing our domain nicely, but the compiler provides significantly more assurance about the values and what we can do with them, too.


### Opaque Types

Let's take another look at the "Java equivalent" code, filling in a few more details from what we learned about accessing the "internal" values in Elm:

```java
public class UserId {
    public String rawStringValue;

    public UserId(String s) {
        rawStringValue = s;
    }
}

// userId is of type UserId and cannot be passed to methods expecting String
UserId userId = new UserId("d948d0af-90a2-4483-8e8d-00596a3eeed1");

// access to the String value "via" the UserId "wrapper"
String rawStringValue = userId.rawStringValue
```
Readers with object-oriented programming experience might object to this implementation, as it ignores one of OOP's core tenants: encapsulation.
The idiomatic Java implementation would keep the `rawStringValue` private, and only allow access to it via a public function, the classic Java "getter" method:

```java
public class UserId {
    private String rawStringValue;

    public UserId(String s) {
        this.rawStringValue = s;
    }

    public getStringValue() {
        return rawStringValue;
    }
}
```
As long as the public methods stay the same (or, "the object's API remains stable"), the private details of the class can change without clients of the class knowing or caring.
This can be especially useful in more complex objects like a repository; as long as the method signatures for saving and retrieving objects remain the same, the underlying implementation could change from an in-memory dictionary to an external database or whatever else.

We can have these same encapsulation benefits in Elm by making our custom types "opaque".
To do this, we simply do not export the constructor functions for the types from their modules.
This means that the `case` statement and function definition destructuring techniques we used above can now only be performed in the same module as the type definition:

```elm
-- File: User.elm

-- By including User and UserId in the exposing list, we make the *types* public, but not the *constructors*
-- If we wanted to also make the constructors public, the syntax is to expose User(..) and UserId(..)
module User exposing (User, UserId, createUser, getUserFormattedName)

type UserId = UserId String

type User = User {id: UserId, firstName: String, lastName: String, age: Int}


createUser : String -> String -> Int -> User
createUser first last age =
    let
        userIdString =
            getSomeUuid  -- details elided
    in
    { id = UserId userIdString
    , firstName = first
    , lastName = last
    , age = age
    }
        |> User


getUserFormattedName : User -> String
getUserFormattedName (User {firstName, lastName}) =
    lastName ++ ", " ++ firstName
```

```elm
-- File: Main.elm
import User exposing (User, createUser, getUserFormattedName)

demo : (String, User)
demo =
    let
        user =
            createUser "Mike" "Knepper" 31

        formattedName =
            getUserFormattedName user
    in
    (formattedName, user)
```
Since nothing outside of the `User` module can `case` or destructure into the internal details of these types, we are free to refactor those details however we like without affecting clients.

In addition to facilitating private refactors, opaque types can add validation code to the constructors to prevent invalid data from ever existing in the system.
Consider this modified `createUser` definition (note: the return type has changed!):

```elm
createUser : String -> String -> Int -> Maybe User
createUser first last age =
    let
        userIdString =
            getSomeUuid  -- details elided

        validName =
            String.length firstName > 0 && String.length lastName > 0

        validAge =
            age > 17
    in
    if validName && validAge then
        { id = UserId userIdString
        , firstName = first
        , lastName = last
        , age = age
        }
            |> User
            |> Just
    else
        Nothing
```
With this implementation, we can't just create a new `User` with whatever `String`s and `Int`s we want;
instead, we can _attempt_ to create a `User`, and if the values are valid (in this case: both names are required, and users must be at least 18 years old) we will get a `Just User` back, but if those requirements are not met, we get `Nothing` back.
This means that users determined to be invalid by our business rules _cannot ever exist in the system_!
Consequently, every function using `User` can focus exclusively on its business logic purpose without having to mix in extra logic ensuring data validity.
This strong separation of concerns ultimately yields more expressive and readable functions that in many cases have no way to fail.

(Note: beginning in Java 8, a similar pattern can be implemented in Java using `Optional` and private constructors.
Several functional programming languages, not just Elm, have had a powerful effect on the way I write in object-oriented languages, and vice-versa!
There is plenty to learn from and apply to each style.)


### Wrapping up

While opaque types are the most complicated Elm type discussed here, and have been presented with some of my favorite benefits they offer, this post should not be taken as a recommendation to use opaque types _exclusively_.
Rather, deciding between custom (possibly opaque) types and record types depends on a number of factors.

In most codebases, record types are going to be more complex than just two fields and are pretty unlikely to overlap exactly with one another.
It can be annoying to sacrifice the conveniences record types afford—it's nice to be able to call any field on the record "for free" instead of defining getter functions for each and every field.
Furthermore, one can always write functions that return record types wrapped in `Maybe` and rely on their own discipline, rather than the compiler, to construct records using that function for benefits like validation.

Perhaps in the early prototyping phase of your project, relatively open record types offer more flexibility, while later on, as data structures mature and solidify, extracting some to dedicated modules and turning them into opaque types becomes useful.
I encourage you to try out Elm and find out what works best for you, or explore mapping and applying these types and techniques to your favorite language!

<br />
##### Footnotes
<span id="footnote-1"><a href="#source-1">[1]</a></span> Please forgive the [biased naming issues](https://www.kalzumeus.com/2010/06/17/falsehoods-programmers-believe-about-names/) in this data model.

<span id="footnote-2"><a href="#source-2">[2]</a></span> Such behavior can be emulated in Elm via "extensible records," but these are beyond the scope of this post.
