---
layout: post
title: "Baking a Cake with Rails"
---

In my [last post][hidden_costs], I cautioned against hastily reacting to the abundance of talks and blog posts describing migrations away from Rails monoliths.
A preliminary question I didn't address is: why are there so many of these stories in the first place?
Most authors and speakers explain that upon reaching a certain scale, their Rails monoliths became difficult to maintain, but why is that?
There are many potential explanations, but in this post I argue one major reason this is so common is that Rails strongly encourages organizing code into horizontal layers at the expense of vertical slices.


### Horizontal layers? Vertical slices? Tell me more about this delicious cake you must be describing.

Horizontal layers are the building blocks and general architectural components of your system.
They stretch across most, if not all, domain concepts.
The "tech stack" is a good place to start thinking about horizontal layers—a SQL database, backend JSON API, and JavaScript front-end could broadly be considered three distinct layers—but finer horizontal layers can be identified within application code.
For example, controllers constitute a horizontal layer that deals with HTTP.
Views are a layer responsible for HTML concerns.
Models are the data persistence layer.

Hmmm... Well, would you look at that! It's MVC!
Rails gives us these three horizontal layers out of the box, and as Rails's popularity attests, these are three very convenient starting layers.
Prior to Rails, many web applications lumped multiple concerns into single PHP files.
The strongly opinionated Ruby framework is a reaction to the difficulties of that architectural style, and indeed is a great alternative.

As a Rails application grows, the framework subtly encourages developers to create additional horizontal layers.
Mailers, presenters, asynchronous jobs, and more are added to new, dedicated subdirectories beneath the top level `app/` directory.
We can make all sorts of horizontal layers, but there is an orthogonal abstraction to consider.


### Cutting the cake

A vertical slice is a single path through the horizontal layers of the app.
For example, an HTTP request is routed to a controller, which looks up data via a repository;
the data is encapsulated in a model that gets passed to a presenter and rendered in an HTML view.
The common element in a vertical slice is an *action*, and in particular one with specific domain meaning.
In an e-commerce site, for example, vertical slices include creating accounts, finalizing orders, processing refunds, or activating promotions.

In most Rails apps, vertical slices are implicit—the paths exist in the code, but they are not immediately obvious from looking at the project directory like the horizontal layers under `app/`.
In his post ["Screaming Architecture"][screaming_architecture], Uncle Bob describes some benefits of organizing code such that vertical slices are made explicit.
Rather than glance at a codebase and exclaim, "Ah, a Rails app! I wonder what it does," one would rather say, "Ah, an e-commerce app! I wonder how it's implemented."
The former looks like this:

```
app/
  controllers/
  mailers/
  models/
  views/
```

The latter looks like this:

```
lib/
  order_processing/
  promotions/
  refunds/
  user_registration/
```


### Too tasty to be true?

Organizing a Rails app in the latter style is not impossible.
There are [several][hexagonal_architecture] [posts][onion_architecture] [describing][clean_architecture] patterns that can be used in pursuit of this goal.
I have seen a few codebases that use Rails while pursuing a vertically-focused project layout quite aggressively, and others that effectively implement a hybrid approach.
They are rare, though, because Rails does nothing to *actively encourage* the definition and organization of vertical slices.
There are a few possible reasons for this.

#### Inconsistency

A vertical approach goes against the grain of the established patterns that contributed so strongly to Rails's popularity in the first place.
"Convention over configuration" proved to be extremely attractive to developers, and deviating from those conventions could introduce inconsistency and confusion.

#### Domain-specificity

All web frameworks need to provide a way to get from the low-level details of an HTTP request to high-level domain logic and back down to an HTTP response.
The specific vertical paths from request to response, however, are defined by the business; they are what make your web app unique.
When starting a new project, `rails new` only knows that you'll need some tools that abstract away HTTP details.
Organizing these horizontally in separate directories is a good starting point, as it reinforces the fact that they have separate responsibilities.

There are a [few][django] [frameworks][ember] that provide ways to prepare your project for a vertical-first layout from the outset.
These concepts can be useful, but using them at the beginning of a project is also risky.
In his book "Building Microservices," Sam Newman [discusses][sam_newman] how getting vertical "cuts" wrong can end up being more costly than not attempting those cuts in the first place.
Newman writes in the context of migrating to microservices, but the same idea applies to long-term maintenance of a monolith.
Sometimes vertical slices need to evolve organically over time from a codebase, rather than being strictly defined up front.
As an extension of this idea, Newman recommends refactoring domain concepts vertically within a monolith before extracting them into separate services.

#### Autoloading

How often do you think about requiring files when working in Rails?
The autoloading Rails provides is convenient at first, but makes almost everything globally available.
Over time, this causes the [package principles][package_principles] to be forgotten and abandoned.
Disabling Rails's autoloading permanently probably isn't worth the inconvenience, but it could be interesting as a temporary exercise to assess package cohesion and coupling.
Ideally the added `require` statements would follow consistent patterns and effectively delineate vertical slices.
However, if autoloading has been abused, they may instead expose a tangled web of cross-cutting concerns.

#### Overemphasizing CRUD

Most Rails apps' routes files consist primarily of calls to the `resources` helper for almost every Active Record model in the project.
By [default][default_resources] this helper defines routes that map directly to CRUD database operations on a model via a controller sharing that model's name.
This works well for pure CRUD apps, but establishes a model-first routing pattern that may not fit other problem domains well.
Coupling HTTP requests to data persistence details can lead to unnecessary shoehorning of behavior into imprecise controllers and actions:
if upgrading a user account requires creating a `Payment` and updating a `User`, should the request be routed to `PaymentsController#create` or `UsersController#update`?
Using more vertical domain names avoids this problem altogether—it can be handled by `UserAccountController#upgrade`.

Rails does provide good support for defining [additional RESTful routes][more_rest_actions] beyond basic CRUD actions,
so the action above could use `resources` to define `POST /users/:user_id/upgrade_account`.
However, this still implies a data-model-first convention rather than a domain-behavior-first one and necessitates prioritizing one model over another.
Furthermore, DHH [recommends (00:50:19)][dhh_interview] sticking to the default actions and building controllers around those actions over adding arbitrary actions to existing controllers.
This leads to needlessly overloading generic words like `update` instead of using words that more clearly describe the behavior.


### Adjust the recipe to taste

I mentioned above that Rails's commitment to "convention over configuration" is a big part of its success.
The layout provided by `rails new` is much more welcoming than an empty directory, and the strict naming conventions are reassuring.
The "Rails Way" often seems like an absolute, all-or-nothing approach to web application development, but you can choose to use whichever parts of it you prefer.
My personal preference is a hybrid approach featuring a traditional, horizontal Rails `app/` directory and a vertical, domain-driven `lib/` directory.
You may find other patterns that work better for your codebase.
However you proceed, staying disciplined and keeping a careful eye on how Rails (or any tool) affects the design of your code will help you make the right decisions for your codebase before it becomes unmanageable.



[hidden_costs]: https://blog.8thlight.com/mike-knepper/2016/01/20/hidden-costs-of-leaving-a-monolith.html
[screaming_architecture]: https://blog.8thlight.com/uncle-bob/2011/09/30/Screaming-Architecture.html
[clean_architecture]: https://blog.8thlight.com/uncle-bob/2012/08/13/the-clean-architecture.html
[hexagonal_architecture]: http://alistair.cockburn.us/Hexagonal+architecture
[onion_architecture]: http://jeffreypalermo.com/blog/the-onion-architecture-part-1/
[package_principles]: https://en.wikipedia.org/wiki/Package_principles
[dhh_interview]: http://www.fullstackradio.com/32
[sam_newman]: http://samnewman.io/blog/2015/04/07/microservices-for-greenfield/
[django]: https://docs.djangoproject.com/en/1.9/intro/reusable-apps/
[ember]: http://ember-cli.com/user-guide/#pod-structure
[default_resources]: http://guides.rubyonrails.org/routing.html#crud-verbs-and-actions
[more_rest_actions]: http://guides.rubyonrails.org/routing.html#adding-more-restful-actions
