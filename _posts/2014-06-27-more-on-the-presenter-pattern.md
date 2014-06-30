---
layout: post
title: More on the Presenter Pattern
---

Here I describe a nice adjustment to the Presenter Pattern as I explained it in a [recent post](http://mikeknep.com/2014/06/25/presenter-pattern-in-rails.html). This update makes the views even more readable.

The problem with my previous implementation of the Presenter is that it leads to the view template using two instance variables that are really representing the same thing--`@book` and `@presenter` are both presenting information about a book record from the database. Yes, one is handling more complicated data than the other, but I wouldn't blame someone for assuming at first glance that the two instance variables `@book` and `@presenter` are representing totally unique objects. It'd be much clearer if there was one object to use throughout the view.

We know we need a BookPresenter class to hide things like formatting logic, so we'll keep that, but we'll refer to that object as `@book` in the view and not pass the actual book object:

{% highlight ruby %}

class BookController < ApplicationController
	def show
		book = Book.find(params[:id])
		@book = BookPresenter.new(book)
	end
end

{% endhighlight %}

The question is how to handle any fields that we originally were calling directly on the instance of Book (in other words, methods that don't need formatting logic, like `title` or `page_count`). We could define those methods on the BookPresenter and in those method definitions just call the field on the book object we passed in upon initialization:

{% highlight ruby %}

class BookPresenter
	def initialize(book)
		@book = book
	end

	def title
		@book.title
	end

	def page_count
		@book.page_count
	end
end

{% endhighlight %}

This will give us our desired functionality, but it will clutter up the BookPresenter class with methods that are barely doing anything. Fortunately, Ruby's "Forwardable" module provides a way to cleanly and concisely effect this behavior.

{% highlight ruby %}
require 'forwardable'

class BookPresenter
	extend Forwardable
	def_delegators :@book, :title, :page_count

	def initialize(book)
		@book = book
	end

	def pub_date
		@book.publication_date.strftime("%B %d, %Y")
	end
end

{% endhighlight %}

With Forwardable and `def_delegators`, we are essentially saying "if `title` or `page_count` is called on an instance of BookPresenter, call that method on `@book` instead of the instance of this class." Lovely! We can now pass just one variable, `@book`, to the show view template. This one object is solely responsible for all the presentational logic regarding the data about that book.
