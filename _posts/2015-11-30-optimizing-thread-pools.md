---
layout: post
title: "Optimizing Ruby Thread Pools"
excerpt: More threads are not always better.
---

I'm working on improving the performance of an API that interfaces to numerous internal services. A single request to this API can make dozens of outbound HTTP calls. My team is using the [Concurrent Ruby](https://github.com/ruby-concurrency/concurrent-ruby) gem to execute as much of the work concurrently as we can. Many methods will spin up a thread to make a remote call and handle the response:

```ruby
def update_widget_price_future(widget)
  Concurrent.future do
    response = RemoteClient::PricingService.update_price(widget)
    map_pricing_details(widget, response)
  end
end
```

Executing several methods like the one above concurrently beats making all the calls serially, but we can further improve performance by being more deliberate about the thread pool(s) being used in each method. The snippet above grabs a thread from Concurrent's default, boundless thread pool. Boundless sounds great—you can spin up as many threads as you want!—but there is a tipping point past which spawning more threads becomes detrimental to performance.

Under the hood, Ruby is context-switching between threads, doing a little work on one thread, then jumping to another to do some work there. The boundless thread pool is great for blocking IO—such as network calls—because the scheduler is smart enough to switch to other threads that can do computational work while waiting for a response. However, too many simultaneous threads executing Ruby code are hard for the scheduler to optimize. With this in mind, we've refactored the code to continue to use the boundless thread pool for remote calls, but to use a different, bounded thread pool for Ruby work:

```ruby
def update_widget_price_future(widget)
  Concurrent.future(:io) do
    RemoteClient::PricingService.update_price(widget)
  end.then(:cpu) do |response|
    map_pricing_details(widget, response)
  end
end
```

Concurrent Ruby's `#then` method allows us to chain a callback on the initial future. Unlike the default `:io` executor, the `:cpu` executor is capped at a finite number of threads to limit the overhead of context-switching. Finding the optimal number of threads for this pool is dependent on a number of factors and will require further analysis, but our initial measurements with this pattern prove: more threads are not always better!