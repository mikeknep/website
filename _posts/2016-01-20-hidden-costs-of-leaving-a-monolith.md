---
layout: post
title: "The Hidden Costs of Leaving a Monolith"
---

Have you read any blog posts about splitting a Rails monolith into microservices?
Or listened to a podcast or watched a talk?
Odds are you've come across at least one, because they're everywhere.

Microservices and Service Oriented Architecture (SOA) are all the rage these days, and for good reason—they can absolutely lead to more maintainable and scalable systems.
However, SOA is not a panacea, as I fear the abundance of articles about this topic may suggest.
My work over the past year has introduced me to new challenges specific to these kinds of systems.

Some of these challenges are technical in nature.
High performance becomes crucial in SOA, and your services are at the mercy of network issues.
Zero-downtime deployments move from a luxury to a requirement, and sometimes entire workflows need to be rewritten to operate asynchronously.
These problems can be tricky, but are all concretely solvable.
Even better, most developers I've worked with are excited about attacking these kinds of challenges, as they tend to require more creativity and expertise.
However, new cultural issues can be much more challenging.

Many of these cultural concerns stem from working on teams, which is common in SOA.
As more and more services are spun up in clean new repositories, it is intuitive and straightforward to organize developers into teams dedicated to one or a few of those repos.
Unfortunately, despite yielding technical benefits, these smaller, decoupled repositories can also exacerbate the issues below.

Since Stack Overflow is not especially helpful for these problems, I'll also provide some suggestions on how to manage them.

### Tunnel vision

The most immediate concern with splitting up into teams is it can be easy for individuals to lose track of what other teams are working on.
The frequent, focused iterations that microservices afford are great for teams' individual productivity, but can also lead to other services becoming black boxes of unknown functionality and purpose.
The risks of not understanding the system at large range from duplicating work (which is bad for business) to plateaued learning and growth (which is bad for developer happiness).

I've found this problem significantly mitigated in environments that value and invest time and resources into eduation and learning.
At 8th Light, we dedicate 10 percent of our time each week to non-client work to make sure we are continually learning and improving our craft.
My client sets aside one work week each year for a company-wide hackathon with groups made up of developers from different teams.
Both policies effectively institutionalize a learning culture, which in turn strengthens communication, interest, and understanding across teams.

### Compromising on testing

As services proliferate, it becomes more difficult to test at the integration level across them.
Many companies with a microservices ecosystem employ at least one QA engineer responsible for managing the staging environment and using it to test at as high a level as possible.
Unfortunately, with a dedicated QA team in place, developers on other teams may start compromising on the quality and thoroughness of their own testing practices.
It's easy to fall in love with a super-fast test suite that mocks out all external calls, but that quick feedback loop is misleading;
the true test duration now includes the time spent pushing a pull request and waiting for the overworked QA team to run their integration tests and report back the errors they find.

One solution here is to make sure all developers have access to the staging environment and are comfortable using the integration test suite.
QA can still have the final say with regards to merging pull requests, but their tools don't need to be kept private.
In addition to reducing the burden on QA, developers working in the staging environment will learn a lot more about the system at large, as well as the deployment process and debugging with logs.

Second, encourage developers to think more creatively about how to bolster their service's test suite.
I worked on an accounting app that made a few external calls to other systems.
Rather than just sticking to unit tests that stub all those calls, we wrote a small, completely separate testing app to stand in for every relevant external system and define integration-level tests using those mocks.
We didn't run the testing app's tests as often as our regular unit tests, but they were incorporated into the CI build so that they always run at least once on our end.
This ultimately provided a good middle ground between unit tests that mock out all external calls and full integration tests that hit live services in staging.

Not a single line of code in the testing application will ever be deployed to production, but my team was nevertheless allowed to spend the time developing it.
The long-term benefits of a more robust testing framework outweigh the short-term gains of completing some features a few weeks early.

### Mismatched priorities

This problem is best demonstrated with a story.
Team A is chugging along on a feature when they reach an unanticipated blocker:
their implementation requires data owned by Service B, but the existing API doesn't expose the data they need.
Team A reaches out to Team B requesting they provide a new endpoint with the requisite data.

The developers on Team B get together and discuss how they might implement the endpoint.
Unfortunately, they estimate it'll take at least a few weeks to develop, test, and deploy to production.
Team B is also already struggling since one developer just left the company, and it looks like they may not accomplish all their quarterly goals.

"Sorry," Team B replies, "but there's just no way we can get to this for at least a month."

Scenarios like these are inevitable in a service-oriented system—so plan ahead for them!
There should always be more actionable work to do if some feature gets blocked.
Try to divide stories up in such a way that they do not depend on one another too much.
If that simply can't work, consider offering to help another team with a service you don't officially own.

On Team B's side, be sure to leave room for "unknown unknowns" when planning out quarters at the very least, if not months or even weeks, and allow the team to give these situations an appropriate level of attention when they arise.
Rather than feeling like distracting chores, surprise requests from other teams can be welcome stories when expressly stated as part of the team's goals.

### Passing the buck

When responsibilities are distributed across services and teams, blame tends to shift about as well.
For example, when some client starts receiving several `500` responses from an internal API, the developers on the client team bristle at the API team.
In response, the API team points out that _really_ some third service downstream is to blame for being in some problematic state.

This attitude is especially prevalent with bug-ticket systems like JIRA.
A developer may check a ticket they've been assigned, skim through the content, decide he or she is not the right person to handle the issue, and re-assign it to someone else with no further comment.
This gets a single issue directed to the right person eventually, but inefficiently and without any improvement to streamline the process in the future.

The most important tool for countering this trend is empathy.
Conversations about whether or not a bug is in fact a bug, or "actually our problem," should instead focus on the experience of the person filing the bug.
Why was it assigned to the wrong person in the first place?
Could the service be easier to interact with?
Could the error messages be more descriptive?
Is the documentation clear (or, _gulp_, present at all)?
In the scenario above, the downstream service clearly needs to be fixed, but the API should also be providing more information to its clients about what is going on.
If the API responds more empathetically, client teams avoid the frustration of a seemingly inexplicably broken service and get in touch with the relevant party directly.


## Be Prepared

Microservices can offer many benefits and advantages over a monolithic architecture, but they introduce new problems, too.
Whether you're a CTO proposing a big redesign to stakeholders or a junior developer working on one of dozens of services, keeping these problems in mind will help ensure healthy systems and developers.
