---
layout: post
title: Refactoring Legacy Code
---

The past couple weeks, I've spent a lot of my free time refactoring a Rails application I wrote prior to joining 8th Light. Much of that time has been spent shaking my head and asking myself what in the world I was thinking at the time.

As a consultant, I will constantly be jumping into legacy code in dire need of improvement. Therefore in addition to being simply a good thing to do for my previous client (and my own sanity while maintaining the app in the future), this exercise is good preparatory experience for my career as a craftsman at 8th Light. Here are two major issues and takeaways from refactoring my legacy code that will be invaluable going forward.


### Addition and Subtraction

The amount of duplication throughout the app was, and still is, staggering. To provide an extreme example, at least eight view templates were exactly the same, and the only difference between the controller actions rendering them (a 1:1 relationship) was which (hardcoded) record was being loaded from the database. This was the "wettest" code I had seen in a long time. At first glance it would appear I simply hadn't yet learned any general reusability techniques. However, I knew about "DRY" from the very beginning of my coding experience, and I used several partials throughout this app. The underlying problem was not simply lacking awareness of how to reuse code.

As I continued working and ran into large blocks of commented-out code and even a few files that were not being used at all, I realized the root cause of the problem: addition without subtraction. Despite using git for version control (and therefore having a full history of the app available), I was afraid to delete any code that at some point had been working. Additionally, as I think back on the months spent building the project, I cannot recall a single period of time dedicated to refactoring. I progressed through the development of the app feature by feature in relative isolation, barely ever considering how they related to one another, let alone searching for common abstractions. Each new task meant *adding* something to the code.

Though I am more experienced now and less likely to make such grotesque mistakes as creating eight identical files, I know that it will still occasionally be difficult to keep a thousand-mile view of the application in mind during the daily grind of churning out stories. This is especially true for clients on a tight schedule, where there is pressure to just get some feature working by any means necessary in time for a deadline. However, whether time spent refactoring counts as billable or not, it is absolutely essential to the long-term health of software. Removing old code from an app is sometimes just as productive as adding new code, as it will prevent numerous questions and headaches in the future.


### The Test Suite

I started learning how to test with RSpec towards the very end of this project, so very little of the application is under test (and frankly, the tests that I did write months ago were not especially valuable). Combined with the general violation of SOLID principles throughout the app, making any change is quite nerve-wracking because I can't quickly determine what, if anything, has been affected or broken by the change.

A thorough test suite is essential to refactoring with confidence. This app is in live use, so I cannot afford to push changes that introduce bugs or crash the system. However, without automated tests, my only option for ensuring stability is manually clicking through the app on the front end in a staging environment. I've [written before](http://mikeknep.com/2014/04/23/response-to-dhh.html) about the difficulty in predicting user behavior and thoroughly testing edge cases manually. I have therefore been especially dogmatic about practicing TDD while refactoring this legacy code in order to effectively build up clean, tested code while tearing down the cruft.


### Closing thoughts

The most recent commits on my legacy codebase demonstrate how much I've learned and grown during my apprenticeship at 8th Light. Rather than be disappointed or embarrassed by my old code, I am aware that I may look back on code I'm writing today and see many areas that could still be improved. This is part of craftsmanship and the pursuit of mastery--an insatiable desire to improve. Fortunately, improving old code is *fun*! Like the Gilded Rose Kata on a larger scale, refactoring legacy code is very satisfying--it provides a great example of how code is organic and either wilts when neglected or thrives when maintained.