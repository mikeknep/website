---
layout: post
title: "Framework Seams"
---

I recently created an open source plugin for [Jekyll][], the Ruby static site generator.
_Jekyll LilyPond Converter_ (henceforth JLC; [source][], [RubyGems][]) converts specified code snippets in Markdown blog posts to music images using [LilyPond][].
The project was just complex enough to warrant using a pattern I often use on larger projects, as well as bite me with a sneaky, related "gotcha", both of which are worth reviewing and sharing.
This pattern relates to a concept I call a "seam" that I find myself carefully considering more and more in all the software I write.


### Seams! What are they (good for)?

First and foremost, this concept is completely separate from Michael Feathers's idea of seams from [Working Effectively With Legacy Code][feathers].
Instead, I offer this definition:

> Seams are locations in a codebase where ownership transitions from a third-party library to the application developer.

For example, controllers form the primary seams within a Rails application.
Provided you follow its API and conventions, the framework takes care of accepting HTTP requests, representing them as Ruby objects, and routing them to specified classes and methods.
Once there, Rails hands control over to the application developer, who can execute whatever domain logic they please.
The developer eventually returns some value from that controller method, and upon doing so implicitly passes ownership back to Rails for it to transform the value into an HTTP response and send it back over the wire.

On my past several projects, I've worked harder and harder to keep my controller methods as minimal as possible—ideally they know nothing more than which "Handler" and "Presenter" to use:

```ruby
class WidgetsController < ApplicationController
  def index
    result = WidgCo::GetWidgetsHandler.new(params).execute
    presenter = WidgCo::GetWidgetsPresenter.new(result)
    render json: presenter.json, status: presenter.status
  end

  def create
    result = WidgCo::CreateWidgetHandler.new(params).execute
    presenter = WidgCo::CreateWidgetPresenter.new(result)
    render json: presenter.json, status: presenter.status
  end
end
```

The controller methods above are quite stark, featuring abrupt transitions from Rails to my own namespce (`WidgCo`) that has no external dependencies.
This pattern helps decouple business logic from the framework, which makes the application both easier to test and less prone to updates to the framework introducing bugs.

Switching context to JLC, Jekyll's [plugin documentation][] outlines the different classes from which the developer can inherit in order to hook into Jekyll's build process.
In the case of JLC, I needed to create a custom `Converter` in order to alter the content of individual posts.
The simplest example available of a custom `Converter` is one that capitalizes the entire blog post:

```ruby
class ScreamingConverter < Jekyll::Converter

  # given the extension (`ext`) of the file Jekyll is building,
  # return a boolean indicating whether the converter should operate on that file
  def matches(ext)
    /md|markdown/.match?(ext)
  end

  # return the output extension of the file
  def output_ext(ext)
    ".html"
  end

  def convert(content)
    content.upcase
  end
end
```

The `convert` method is where the magic happens—Jekyll provides the content of the current file being built as a `String`, and Ruby's wonderful standard library is at the developer's disposal.
But just as I don't want to couple Widget creation rules to Rails by defining those rules in a controller, I don't want to couple LilyPond snippet conversion logic to Jekyll by defining it in a converter.
Instead, JLC forms an explicit seam inside `convert` by [immediately delegating][] to a separate class with no direct dependencies on Jekyll.


### The Seam Test "Gotcha", and Some Alternatives

I mentioned above that making seams direct and abrupt can simplify testing.
This is because the code added within the framework context does nothing but map from the entrypoint that framework exposes to some custom object, class, or function.
Simply assert that the right thing is called and you're set.

However, these tests become more difficult as additional dependencies are introduced.
In JLC, the `Handler` domain object is [constructed][] with several other dependencies in addition to the content Jekyll provides.
I decided to use some of RSpec's stubbing functionality in my `Converter` test (simplified in this post for concision, but you can [view the source][converter-spec]):

```ruby
describe Converter do
  it "delegates to a Handler" do
    content = "abc"
    handler_spy = HandlerSpy.new

    allow(Handler).to receive(:new).with({
      content: content,
      naming_policy: instance_of(NamingPolicy),
      image_format: "svg",
      site_manager: SiteManager.instance,
      file_builder: StaticFileBuilder
    }).and_return(handler_spy)

    converter.convert(content)

    expect(handler_spy.execute_was_called).to eq(true)
  end
end
```

This test ensures that the `Converter` delegates to the specified class, with the specified dependencies, and calls the specified method.
If for some reason we change that in the `Converter`, our test will catch the error.
However, we've introduced something far more subtle and dangerous: the potential for a false-positive in our test suite.

During the course of development, I realized the `Handler` required different dependencies.
I was test-driving this code as much as possible, so I started by updating the `Handler` unit tests to pass different values to `Handler#initialize`.
These tests of course failed, requiring me to change `Handler#initialize` and some other private methods.
Once finished, my test suite was passing... but I had introduced a bug!
The `Converter` was still constructing the `Handler` with the old set of dependencies.
However, the `Converter` spec above didn't fail, because all it does is assert that the `Converter` instantiates a `Handler` a certain way (or at least attempts to).
Sure enough, of course, the `Converter` was still instantiating it that same, but now out-of-date way.
The unit tests for each of the two classes were in sync with their respective production code, but the _relationship between_ those two classes was not tested, and thus I had a green test suite with a runtime exception.

A statically typed language would catch this problem earlier, because the code wouldn't even compile.
Alas, we are not all so fortunate, and when working in a dynamic language like Ruby this is a trickier situation.
I don't have a perfect solution, but I have considered a few options.


#### The Registry Option

One idea is to have the `Converter` access the `Handler` through a `Registry`.
The `Registry` can be a static class that by default returns the regular `Handler` through a simple lookup, but in the test environment could be configured to return a subclass of `Handler`.
The subclassing spy overrides `#execute` to prevent running code we test elsewhere, but inherits the production `Handler`'s constructor so that they change in lockstep.
Meanwhile, passing through the `Registry` relieves the test of having to stub the `Handler#new` call.
The code could look like this (several details elided):

```ruby
class Registry
  def self.register(key, klass)
    registry[key] = klass
  end

  def self.for(key)
    registry[key]
  end

  def registry
    @registry ||= { lilypond_conversion: Handler }
  end
end


class MyConverter < Jekyll::Converter
  def convert(content)
    handler = Registry.for(:lilypond_conversion).new({
      content: content,
      naming_policy: NamingPolicy.new,
      image_format: "svg",
      site_manager: SiteManager.instance,
      file_builder: StaticFileBuilder
    }).execute
  end
end


class HandlerSpy < Handler
  def execute
    @@execute_was_called = true
  end

  def execute_was_called?
    @@execute_was_called
  end
end


describe MyConverter do
  before { Registry.register(:lilypond_conversion, HandlerSpy) }

  it "delegates to a Handler" do
    converter.convert("abc")
    expect(Registry.for(:conversion).execute_was_called?).to eq(true)
  end
end
```

I did not implement this in JLC, for a few reasons.
First, it felt like more boilerplate and indirection than was ultimately necessary or worthwhile given the size of the project.
Second, Jekyll doesn't expose a particularly useful place to configure the `Registry` in production,
so `Registry.register` is production code that exists solely for the tests, which is definitely a smell.
Finally, because the `Converter` calls `#new` on the handler class retrieved from the `Registry`, we can't use Ruby's `Singleton` module (which privatizes `#new`);
instead we're forced to use a class variable (`@@execute_was_called`), and in my experience once you start using class variables you're just asking for trouble.

Having said all that, in a Rails app, the `Registry` may make much more sense:
there are more handlers to register, better justifying the "added weight";
[initializers][] provide another seam at application start time where production classes can be registered;
and if the `Registry` were to hold pre-constructed instances (perhaps created in earlier initializers) instead of classes to be instantiated, the awkward and dangerous pseudo-singleton technique could be avoided.

Ultimately, this approach has pros and cons, and, like so many things in software development, needs to be evaluated on a case-by-case basis.


#### The KISS Option

The `Registry` concept seemed too heavyweight for JLC, so after evaluating it I considered an opposite approach—what if I made _fewer_ classes?
I mentioned above that aggressive seams simplify testing and help decouple business logic from a framework.
However, unlike some libraries I've seen in which objects require quite a bit of global state to set up properly, instantiating a `Jekyll::Converter` in a test is not particularly unwieldy.
Furthermore, it's pretty unlikely I'll want to port the core logic of JLC to integrate with other static site generators.
The simplest option, then, is to just lift the `Handler` tests up into the `Converter` and test the entire system through that outer third-party shell.

This analysis ultimately suggests I've over-engineered the project, which in a vacuum may be true.
However, the tool is primarily for my own personal use and has helped me continue to develop my thoughts and opinions about this concept and approach to integrating with third-party frameworks,
so some over-engineering here does not bother me.
There is definitely a takeaway for client work here, though.
Designing a system to be flexible and easy to change makes several implicit assumptions about what kinds of changes may happen.
A healthy dose of pragmatism must be kept in mind.


#### The Impossible-In-Ruby Option

The last and most interesting approach I considered is a theoretical one inspired by Elm.
In Elm, effectful (i.e. "having side effects") actions like HTTP requests are represented by value objects describing the _intent_ of what to do,
but the actual _execution_ of those values is handled entirely by the Elm Runtime.
If such a system existed in Ruby, theoretically I would not [shell out][] to LilyPond directly in the `Handler`, but instead create and return a value representing that action.
My unit tests could then simply make assertions about that value, and the Fantasy-Elmlike-Ruby Runtime would understand how to interpret that value as a command to execute certain instructions on the filesystem.
If you're curious about this idea and want to learn more, I highly recommend reading the [official guide][], and in particular the section on [Effects][].


### Liberate Your Code

Despite the lack of a perfect, one-size-fits-all testing strategy, I find it valuable to be conscious of the seams in a codebase.
Being aware of seams affords freedom to application developers.
Typically, READMEs and other example resources provide the absolute simplest demonstration of how to integrate with a framework without any comment on how that style of integration scales.
It is easy to start learning about a new tool or platform and believe that your code needs to live inside a foreign class of unknown complexity.
Of course there are certain rules to follow, but when a code example includes some trivial stand-in for your domain logic,
I recommend thinking carefully about whether you want your code to stay in that framework-defined location, or if you'd rather treat the seam as the entrypoint to an entirely separate world of your own.
The decision is yours!




[Jekyll]: https://jekyllrb.com/
[source]: https://github.com/mikeknep/jekyll-lilypond-converter
[RubyGems]: https://rubygems.org/gems/jekyll-lilypond-converter
[LilyPond]: http://lilypond.org/
[demo]: https://mikeknep.com/2017/08/19/demoing-jlc.html
[feathers]: http://www.informit.com/articles/article.aspx?p=359417&seqNum=3
[plugin documentation]: https://jekyllrb.com/docs/plugins/
[immediately delegating]: https://github.com/mikeknep/jekyll-lilypond-converter/blob/26543e9d59250156b70489cb57595a9eb6d9cf53/lib/jekyll_ext/converter.rb#L23-L31
[constructed]: https://github.com/mikeknep/jekyll-lilypond-converter/blob/26543e9d59250156b70489cb57595a9eb6d9cf53/lib/jekyll_lilypond_converter/handler.rb#L3
[converter-spec]: https://github.com/mikeknep/jekyll-lilypond-converter/blob/26543e9d59250156b70489cb57595a9eb6d9cf53/spec/jekyll_ext/converter_spec.rb
[initializers]: http://guides.rubyonrails.org/configuring.html#using-initializer-files
[shell out]: https://github.com/mikeknep/jekyll-lilypond-converter/blob/26543e9d59250156b70489cb57595a9eb6d9cf53/lib/jekyll_lilypond_converter/handler.rb#L39-L41
[official guide]: https://guide.elm-lang.org/architecture/effects/
[Effects]: https://guide.elm-lang.org/
