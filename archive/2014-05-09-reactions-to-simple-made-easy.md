---
layout: post
title: Reactions to "Simple Made Easy"
---

Rich Hickey is the creator of Clojure. In 2011, he gave a talk entitled "Simple Made Easy," which you can watch [here](http://www.infoq.com/presentations/Simple-Made-Easy). I strongly recommend this talk to any programmer, but especially those interested in Clojure specifically. I found myself agreeing with a lot of what Rich says, but also questioning a few points as well.


### Simple ain't Easy
In both this talk and another I watched yesterday, Rich spends a lot of time defining words we often take for granted, like "simple," "easy," "values," and "facts." As a former World Literature major in college, I appreciate Rich focusing in on these words and making sure his audience understands the way he uses certain words in his talks. In "Simple Made Easy", Rich explains the difference between "simple" and "easy," two words we often erroneously conflate.

"Simple" refers to a lack of interleaving. Rich presents an image of four strings hanging next to one another, and another of the four strings braided together. The first diagram is simple--there are no twists and turns--while the second diagram is complex. Rich goes on to explain that in the context of software, simple means focused on one role, task, concept, or dimension. It seemed to me that without overtly stating it, Rich is talking about the Single Responsibility Principle.

On the other hand, "easy" refers to the idea of nearness. If something is easy it is nearby, adjacent, not difficult to obtain. It is *familiar*, or close to our understanding and skill set.

One of the best arguments Rich makes in this section of his talk is that given these definitions, simple is *objective*, while easy is *subjective* or *relative*. To determine if something is simple, we can look at it and assess whether or not there is any interleaving or braiding together of multiple things. To determine if something is easy, on the other hand, we need to ask, "Easy for who?"


### Sprinting a Marathon
Rich takes the time to explain the differences between simple and easy because despite people often using them synonymously, building something simply and building something easily often oppose each other. For example, a certain feature might be accomplishable via a single method that is easy and quick to implement, but is definitely not simple. (Let's say, a method that manipulates object A based on the states of objects B and C.) When facing deadlines, the easy solution can look far more tempting than the simple solution (which Rich notes often involves *more* code). Rich offers a funny quip about agile development teams running a marathon by simply firing the starting gun over and over every 100 meters to turn it into a series of springs. While I don't think it's entirely fair to suggest that agile development by definition suffers from this problem, he is definitely correct in saying that simplicity needs to be a priority from the very beginning of the project, and all too often is not.

We can't sacrifice simplicity early and assume we'll just refactor it later; simplifying things only gets more and more difficult as the code grows. Take the time up front to plan and design. Pace the team appropriately. Let the client know you're invested for the long haul and aren't just interested in getting something, *anything*, up and running ASAP that becomes impossible to maintain or extend.


### Crashing into Guardrails
Rich takes a few minor jabs at testing--specifically (it seems to me, though he doesn't say it outright) test-driven development. He provides an admittedly amusing comparison of a car driving to a destination by crashing into the guardrails alongside the road the whole way. It's a funny image, but I don't think it makes a whole lot of sense or accurately captures what a developer actually does when TDD-ing. When I add a new feature to a well-tested code base, I don't add it by slamming into my tests again and again--I don't even know what that would mean or accomplish. It sounds like it would involve writing code that deliberately breaks tests, and then hoping that the more tests you turn from green to red, the closer you get to your goal. This, of course, is not why or how we practice TDD. 

Consider the task of constructing a windy road along steep cliffs (this would have to be somewhere not remotely near Chicago, obviously). The first step might be to build guardrails alongside the edges of the cliffs. These generally direct the path of the road. Once we start building the road, we have a general direction in mind; we know the shape of the road and know that it can't get any closer to the cliffs than the guardrails we set up. When the construction of the road is complete, the guardrails take on a different responsibility. They are no longer shaping the road--the road is built. Now, the guardrails are in place to prevent cards from flying off the cliff!

I think this is a better way of thinking about tests and test-driven development. Initially, tests direct the design of the code, but after that code is in place, the tests adopt a new role: catastrophe prevention. Once code has been written to get a test to pass, that test's continued presence in the code base / test suite is not to necessarily guide new features, but simply to advise you when something in a new feature breaks something old. I think Rich misses a great benefit of TDD, which is that writing tests before and immediately alongside the production code helps keep objects, classes, and namespaces simple. Writing tests should not be difficult, and should not require setting up tons of other objects, recreating specific states, or mocking and stubbing an excessive amount of methods/functions. In fact, these are signs that what's being tested is probably too coupled to some other thing in system and should be simplified.


### Wrapping up
Simplicity doesn't come into existence via choosing a particular text editor, language, or framework. There isn't a quick and *easy* way to write simple code. It takes practice and experience with both ends of the spectrum and everything in between to develop sensibility for what is simple vs. complex.