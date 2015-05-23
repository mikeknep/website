---
layout: post
title: The Dangers of Ruby Gems
excerpt: When you use a gem, you are choosing to rely on someone else's code rather than your own. You are trading control for convenience. Sometimes this trade works out splendidly, but other times it leads to far more trouble than it's worth.
---

(Also posted on the [8th Light blog][8lblog].)

Since I first began learning Ruby a little over a year ago at The Starter League, I've been wary of using gems. I remember a friend at TSL discovering the famous authentication gem [Devise](https://github.com/plataformatec/devise) just a few weeks into the class and talking about how simple it made authentication. A few months later I was working on a Rails app for a freelance client and thought, "Hey, I'll try using Devise in this app." Within a week I had gutted the gem and completely started over rolling my own custom authentication system.

When you use a gem, you are choosing to rely on someone else's code rather than your own. You are trading control for convenience. Sometimes this trade works out splendidly, but other times it leads to far more trouble than it's worth.


### Scope

Much like the larger software applications in which they are used, the best gems follow the Unix philosophy of doing one thing well. One gem I like quite a bit is [HTTParty](https://github.com/jnunemaker/httparty), which simplifies the process of making HTTP requests and parsing their responses. This is a specific, focused task that likely is the responsibility of just one class in an application's lib directory. HTTParty's scope and influence within an app is therefore quite small. On the other hand, "authentication" is a broad concept that requires interaction between several parts of an application. Devise creates its own routes, model, controller, view templates, and more in an effort to thoroughly implement authentication in a Rails app.

The real problem with Devise commandeering all these components is that it makes the system extremely rigid. If the business logic changes (and yes, it *will* change) in a way that affects user sign-in or account creation, the developer is limited to modifying the app within the constrains of Devise. The developers behind Devise may not have anticipated a situation quite like yours, so getting Devise to work with the new process might be extremely difficult. Specifically, it will require clunky overrides and awkward workarounds, because the code itself is of course hidden, packed in the gem. Thus what can be a blessing (not having to worry about the gritty details involved in making an HTTP POST request) becomes a curse (not having access to the Users Controller to modify the login action).


### Magic

As an aspiring software craftsman, one of my primary goals is to achieve mastery over the tools--programming languages--I use to build products. This means understanding at a deep level how the various components in the software I create actually work. Relying too heavily on functionality packed into others' gems is essentially relying on magic. In the best case scenario of using Devise, it should Just Work--damned if I know how, though. Throughout my apprenticeship, more and more curtains have been pulled away, and I am now at the points where lines of code that I'm just supposed to trust to work make me anxious.


### Quality

Of course, nearly all gems' source code is available to browse on GitHub, as well as their READMEs and wikis. However, it turns out a lot of gems are written surprisingly poorly. It is not uncommon to find violations of SOLID principles, n+1 queries, monkey patches, and other gruesome sights when perusing gems' source code. Quality documentation is also a rarity. Technical writing is a difficult skill that too few developers practice, and it shows. Of course, once again, the whole point of the gem is to Just Work, so presumably I shouldn't have to pour through documentation and source code to get some feature working. And yet.


### Readability

At 8th Light, we strive to make our code readable and expressive. A gem may give you a slick public-facing method named with a single word that summarizes what it's doing, but if a new developer on the team is curious about what that method does, or is debugging a process that involves that method, she or he won't be able to easily find the details. It is not uncommon to hear people ask, "What is that method? Is that something [gem X] gives us? Is that a [gem Y] method?" The prosody of your method quickly loses its allure when it forces you to hunt through the kind of documentation and source code I just described.


### Dependencies

If a gem you're using releases a new version with some features you want, you can't always just upgrade the gem and be set. Gems frequently rely on other gems, and those dependencies can occasionally clash. Much like a single gem reaching across too many parts of a system, too many gems (even smaller ones) interacting with each other leads to significant rigidity when it comes time to upgrade.

[8lblog]: http://blog.8thlight.com/mike-knepper/2014/08/05/the-dangers-of-ruby-gems.html
