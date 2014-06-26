---
layout: post
title: The Presenter Pattern in Rails
---

Before joining 8th Light, I built several web applications in Rails. This experience proved invaluable when joining the Footprints team, as I'm already familiar with things like the directory layout/structure and flow of events in the framework. However, 8th Light values several design patterns that break Rails convention, and consequently my experience on the Footprints team has been quite eye-opening and is leading me towards a different approach to building web apps with Rails. One such pattern that is quite simple but very valuable is the use of "presenter" objects in view templates.

In the traditional Route-Controller-Action-View ("RCAV") flow of Rails, the controller action grabs necessary objects from a database and assigns them to instance variables that get passed to the view template. For example, a book club app might grab a record from the books table in a SQL database and assign it to `@book` in the BookController's "show" action. This `@book` variable is then passed to the book's "show" view--a page displaying the details about that book, named "views/show.html.erb".

One such detail we want to display might be the book's publication date. This data would likely be stored in a Date field in the SQL database, so calling `@book.publication_date` in the view might render something like "2014-06-25 00:00:00". This is the correct data, but it sure is pretty ugly--we'd rather present the date in a more readable format, like "June 25, 2014". There are a couple ways of doing this.

We'll definitely want to use Ruby's `strftime` method: `@book.publication_date.strftime("%B %d, %Y")` will return the date in the format we want. The question is where to call this method. We could just call it directly in the view using embedded Ruby tags:

{% highlight html %}

<h1><%= @book.title %></h1>
<p>Publication date: <%= @book.publication_date.strftime("%B %d, %Y") %></p>

{% endhighlight %}

However, the convenience of embedded Ruby tags is very easy to abuse, and the tags can quickly spiral out of control. For example, if the publication date is in the future, we may want to display how many days until the book is available:

{% highlight html %}

<p>Available in <%= (@book.publication_date - Date.today).to_i %> days!</p>

{% endhighlight %}

The view template gets harder and harder to read the more embedded Ruby tags are used, particularly for front-end designers who may not know Ruby but need to work on redesigning of the page. Also, in terms of SOLID principles, the responsibility of the view template is to render information in HTML; it should not be doing too much Ruby processing/calculation. But we still need to call methods like `strftime` *somewhere*, otherwise our data will look ugly no matter how nice our designers style the page visually.

In Footprints, we employ the "Presenter" pattern to keep our views clean. The presenter class is a "plain old Ruby object" that defines methods for formatting things like the book's publication date. It is instantiated with the object whose data we are formatting. For example, a presenter for books in our book club app might look like this:

{% highlight ruby %}

class BookPresenter
	def initialize(book)
		@book = book
	end

	def pub_date
		@book.strftime("%B %d, %Y")
	end
end

{% endhighlight %}

To access these methods, we simply instantiate a `BookPresenter`  object in the controller and pass it to the view:

{% highlight ruby %}

class BookController < ApplicationController

	def show
		@book = Book.find(params[:id])
		@presenter = BookPresenter.new(@book)
	end

end

{% endhighlight %}

Our ugly view above can now be written like this:

{% highlight html %}

<h1><%= @book.title %></h1>
<p>Publication date: <%= @presenter.pub_date %></p>

{% endhighlight %}

This is much cleaner to read for developers and designers alike, and additionally allows us to unit test our presentation methods so we are confident in how data is being displayed.
