---
layout: post
title: 
---

I recently switched from RVM to rbenv for managing Ruby versions. Here's why, and how.

Despite not often making itself known front and center, a Ruby version manager of some kind is essential when developing software in Ruby. When I first started developing Rails applications at the Starter League, I followed an ultra-simple setup guide that included installing RVM for Ruby management. After following the initial setup steps, I hardly ever had to do anything with RVM--I've probably run half a dozen RVM commands in the past year.

Recently some apprentices and I were talking about different Ruby versions. One apprentice likes using whatever the current bleeding edge version of Ruby is, another uses version 2.0.0, and a third stays on version 1.9.3. Around the same time, I discovered that the Footprints deployment process uses a tool called Travis CI to run the test suite in multiple versions of Ruby. My curiosity about switching between Ruby versions was piqued, but I realized I didn't have any idea what RVM actually did. I began to research the details of RVM, but quickly found several articles (and another apprentice at 8th Light) suggesting that I should use rbenv instead of RVM. Their main argument was simple and convincing, so I made the switch.

### Do one thing well

Unix philosophy dictates that software should do one thing well. I've found myself agreeing with this philosophy more and more as I grow as a software developer. I like my applications and tools to be focused and great at one thing, rather than just OK at several things.

It turns out RVM violates this principle--it handles installing Ruby versions, switching between them, and managing each version's set of gems. This feels very "heavy" to me--if I were going to dig into the details of RVM, it would probably be quite a large rabbit-hole full of "stuff", only some of which would actually be relevant and valuable to me. In contrast, rbenv's only responsibility is switching between Ruby versions at global, application, or local levels--it leaves the task of installing Ruby versions to a separate tool called ruby-build, and managing gemsets to Bundler. This focus makes rbenv much easier to understand and use.

As an extra bonus, it turns out Bundler is a better tool for managing gems than RVM anyways. Bundler provides a consistent environment for Ruby projects by tracking the gems used within a given project. If you've used a Gemfile, you've used Bundler--it defines the dependencies of a project, so when you clone down someone else's application, if they're using a Gemfile you can get started working on the project quite easily: just run `bundle install`. Rails uses Bundler by default, so I actually have quite a bit of experience using Bundler without even knowing it.

Finally, rbenv doesn't pollute my dotfiles as much as RVM did. The latter required being loaded into the shell as a function (what the heck does that mean, and why?), whereas the former simply requires adding a directory to the $PATH environment variable so that ruby commands know where to look for execution (much more straightforward). Ever since organizing my dotfiles and maintaining them through version control, I've wanted them to be as clean as possible; rbenv facilitates this much more than RVM did.

### Guides and notes for installation

I used [rbenv's README](https://github.com/sstephenson/rbenv#installation) and [a guide from Thoughtbot](http://robots.thoughtbot.com/using-rbenv-to-manage-rubies-and-gems) to uninstall RVM and install rbenv. I won't bother repeating their instructions here, as both are well written and straightforward.  The two differ very slightly--a couple "order of operations" things that don't make a difference one way or the other. The only major difference in my process was putting the requisite bash line in its own file that my bash profile sources, because as I mentioned my bash settings are tracked with git in their own repository.

Aside from having to re-install a bunch of gems with `bundle install` immediately after the switch, I haven't noticed any differences in my day-to-day workflow. Considering how infrequently RVM used to pop up, I take this as a good sign.