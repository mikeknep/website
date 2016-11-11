---
layout: post
title: "Moving Towards Continuous Delivery"
8thLightURL: https://8thlight.com/blog/mike-knepper/2016/11/10/moving-towards-continuous-delivery.html
---

Continuous Delivery is a hot concept in the software industry these days, but can often seem like an impossible goal.
"How could _our_ system ever do _that_?" ask the developers working on legacy systems.
While there are often several technical hurdles to overcome, practicing Continuous Delivery can also require significant cultural changes.
In this post I'll describe some of the key exercises and processes we used at one of our clients to begin moving towards a culture of Continuous Delivery.


### Understanding the Current Process

The thing about computers is, they never misbehave.
Until SkyNet or some other AI revolution arrives, computers will continue to always do exactly what they are programmed to do—no more and no less.
Consequently, programmers need to be explicit;
whether automating a sorting algorithm or global business, every step involved must be identified and programmed.

Therefore, in order to automate a deploy process, the steps of that process must be fully known.
Unfortunately it's fairly common for most developers to have a general understanding of the deploy process, while only a select few really understand all the details and edge cases.
Writing out each and every step of how code gets from a local branch on a developer's machine to running in production ensures that everyone shares a complete understanding of how they are shipping software today.

This exercise can expose surprising details and humbling inefficiencies about a process that many may take for granted.
This is a good thing!
Learning more about the complexities of others' work builds empathy, and identifying organizational weaknesses grounds teams in humility.
At 8th Light, we strongly [value][ben-voss-empathy] these [characteristics][paul-pagel-humility]—they are instrumental to our success as software crafters.

Furthermore, defining the existing deploy process is also the first test of patience.
The road to Continuous Delivery may be long and arduous, but establishing a baseline against which future improvements can be compared helps everyone maintain perspective on progress being made while incremental improvements are developed.


### Defining "Done"

Pinpointing when a story is complete can be surprisingly difficult.
Is it when a pull request has been opened? Reviewed by devs? QA'd? Merged? Deployed?
Five different people may provide those five different answers.
While it is reasonable that different teams have different requirements, often times people on the same team but with different roles will have discordant perspectives.

Like the deploy process above, the requirements for a story to be considered finished can be formalized explicitly.
At this particular client, my team's criteria for "done" consisted of three parts (in addition to passing tests, of course):

1. Two developers who did not work on the story have reviewed and approved the pull request.
2. A QA engineer has tested the feature on a staging server.
3. A product stakeholder has interacted with the feature on a staging server.

This is a pretty rigorous definition of "done", and asks a lot of several different people.
In some organizations, stakeholders' time is at a premium and they may be unwilling to be so heavily involved day to day.
However, as the [Software Craftsmanship Manifesto][sc-manifesto] states, we value productive partnerships with our customers.
Increasing the responsibility and accountability of people beyond just developers yields benefits to everyone involved.
QA, for example, can better manage their workload and can automate regression testing more iteratively given a steadier pace.
Meanwhile, product owners appreciate fewer surprises at demos, leading to fewer stories being held over to the next iteration due to late, unexpected feedback.

For developers, a clear, thorough definition of "done" provides valuable transparency to what may be an opaque step in the deploy process.
Rather than merges being blocked by colleagues choosing what and when to release, developers can freely merge their own pull requests independent of when deploys occur.
Not only does this increase productivity via fewer long-running branches causing merge conflicts, but general morale improves as well.
Perhaps I have just been lucky, but I haven't worked with any developer who didn't care about actually shipping software to production.
At our client, developers embraced the responsibility of merging their work, happy to no longer report at standups that their pull requests were "ready to go, just waiting for a release to get merged to master."
Furthermore, with increased accountability across the board, when QA or product owners are lagging on their responsibilities, developers are more comfortable citing those parties as responsible for specific delays.


### Establishing a Cadence

Human beings are creatures of habit; routines help us manage our time, prioritize our work, and stay productive.
By [only wearing gray or blue suits][obama-suits], President Obama reduces the number of daily decisions he has to make, helping him stay mentally sharp.
Similarly, following a consistent deploy schedule turns a Deploy-with-a-capital-D into just a [boring][colin-boring] part of a normal day.

Many people think Continuous Delivery means automated production deploys upon every push to the master branch, but in fact this is a false equivalence.
Martin Fowler [defines][fowler-cd] Continuous Delivery as "a software development discipline where you build software in such a way that the software can be released to production at any time";
Jez Humble [describes][humble-cd] it as "the ability to get changes of all types... into production, or into the hands of users, _safely_ and _quickly_ in a _sustainable_ way."
Neither of these definitions specify any implementation details like "upon every merge to master"—that is certainly one way, but not the only way.

An alternative sustainable approach to regularly releasing code to production is a deploy cadence.
Simply choose a regular schedule for deploys and stick to that schedule.
Our client decided there would be a deploy every morning at 10:30.
This decision removed all ambiguity about when the next deploy would occur;
combined with our criteria for "done" and close collaboration with the QA and product teams, our team could make much better predictions about when certain stories would be shipped.
Additionally, scheduling deploys frequently enough reduces the temptation to rush an implementation or review in order to make a deploy—if there's going to be another one tomorrow, everyone can take their time to do their jobs well.


### On to Automation

Of course, there are still many steps to get to an ultra-efficient deploy pipeline.
Nothing in this post actually automates any step in the process—everything from merging pull requests to flipping switches on load balancers is still performed manually at this point.
However, what remains are simply technical problems (with too many possible implementations for this post).
The steps outlined here begin establishing a culture that values empathy, humility, accountability, and routine, which will pay enormous dividends while solving those technical problems and others in the future.



[ben-voss-empathy]: https://8thlight.com/blog/ben-voss/2013/01/15/how-to-be-a-great-pair.html
[paul-pagel-humility]: https://8thlight.com/blog/paul-pagel/2013/03/12/3rd-edition.html
[sc-manifesto]: http://manifesto.softwarecraftsmanship.org/
[obama-suits]: https://www.fastcompany.com/3026265/work-smart/always-wear-the-same-suit-obamas-presidential-productivity-secrets
[colin-boring]: https://8thlight.com/blog/colin-jones/2016/10/06/clojure-is-boring.html
[fowler-cd]: http://martinfowler.com/bliki/ContinuousDelivery.html
[humble-cd]: https://continuousdelivery.com/
