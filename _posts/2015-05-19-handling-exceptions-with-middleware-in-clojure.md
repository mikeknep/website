---
layout: post
title: "Handling Exceptions with Middleware in Clojure"
---

(Also posted on the [8th Light blog][8Lblog].)

My team was recently tasked with developing a few HTTP endpoints in our Clojure service to be used by a separate UI.
The requirements included a few POST endpoints to allow users to create new records in our Postgres database.
In this post I will walk through the evolution of this feature to demonstrate a pattern for handling exceptions using middleware.

### Getting started

We begin with a basic POST endpoint using the popular [Compojure][Compojure] and [Ring][Ring] libraries:

```clojure
(ns library.routes
  (:require [compojure.core :refer [defroutes POST]]
            [compojure.handler :as handler]
            [ring.middleware.json :as ring-json]
            [library.db :as db]))

(defroutes app-routes
  (POST "/books"
    {params :params}
    (let [{:keys [id]} (db/insert-book params)]
      {:status 201 :body {:id id}})))

(def app
  (-> (handler/api app-routes)
      ring-json/wrap-json-response
      ring-json/wrap-json-params))
```

Notice the Ring functions on the last two lines.
As their namespace suggests, these functions are middleware functions.
They help simplify the code in `defroutes` by parsing between JSON and Clojure data structures.
Consider this `curl` request:

```
$ curl -X POST \
  -H "Content-Type: application/json" \
  -d "{\"title\":\"The Brothers Karamazov\",\"author-id\":1}" \
  localhost:3000/books
```

Ring's `wrap-json-params` will parse the JSON data in the request and include `{:params {:title "The Brothers Karamazov" :author-id 1}}` in the request map that the route accepts as an argument (destructured above).
On the other side, `wrap-json-response` allows us to simply return a map at the end of the route definition and not worry about translating it to JSON.

### User errors

The code above works in "happy-path" situations, but unfortunately we can't trust users to always provide valid data.
What if someone tried sending a string as the author id or a map as the title?
Without any checks or transformations between here and the database, Postgres will throw an exception when attempting to insert incorrect data types.
That exception will then bubble all the way back to the user as the HTTP response.
This is not only a bad user experience, but additionally could expose some dangerous details like raw SQL strings.
The easiest way to avoid this is to wrap our call in a `try/catch` block:

```clojure
(POST "/books"
  {params :params}
  (try
    (let [{:keys [id]} (db/insert-book json-params)]
      {:status 201 :body {:id id}})
    (catch Exception e
      {:status 400 :body "Invalid data"})))
```

Now, if `db/insert-book` throws an exception, the route catches that exception and returns an HTTP response with a 400 status code and a safe, controlled error message.
This is a nice, quick win for creating books, but the UI requires additional endpoints—users also need to be able to create new authors, publishers, and other resources.
So we add more POST endpoints, remembering each time to wrap the database insert calls in `try/catch` for safety...

No! Of course not!
Such duplication is an obvious code smell, and we don't want to risk forgetting to add `try/catch` to some future POST endpoint.
On top of that, the code is significantly less readable with the awkward indentation of `try/catch` and two HTTP response maps in each route.
It'd be nice if we could just define the logic of catching exceptions and responding safely in one place, and have it apply to all our request/response processing.
That way we'd keep our route definitions focused on the happy path of creating new resources and minimize the risk of human forgetfulness.

Just as the Ring middleware library provides JSON conversion around all our endpoints, we can define our own middleware function to deal with this exception handling:

```clojure
(defn wrap-exception-handling
  [handler]
  (fn [request]
    (try
      (handler request)
      (catch Exception e
        {:status 400 :body "Invalid data"}))))

(def app
  (-> (handler/api app-routes)
      ring-json/wrap-json-response
      ring-json/wrap-json-params
      wrap-exception-handling))
```

Let's start digesting this by taking a closer look at `app`.
According to the Compojure [source][handler/api], `handler/api` takes a definition of Compojure routes as an argument and returns "a handler suitable for a web API."
More simply, `handler/api` returns a function.
This returned function accepts a single argument—an HTTP request—and uses the route definitions to generate a response.

We're using the threading macro to pass the return value of `(handler/api app-routes)` to the ring-json functions and now our new `wrap-exception-handling` function.
In order to preserve the behavior of `app`, which without any middleware would return that handler function, each of these middleware functions must accept a single argument—a handler—and return a new function.
Our new `wrap-exception-handling` function does just that.
Like the original handler, the return value is a function that accepts a request as an argument.
When called, this returned function will attempt to call the original function `wrap-exception-handling` received (the original handler we threaded to it) with the request argument, and return its result.
Any exceptions in that call will be caught, and our handy 400 response map will be returned.

### Finer grained exception handling

With exception handling now covered by the middleware function, we can strip the duplicative `try/catch` calls out of the routes, leaving them nice and clean.
However, we've introduced a new, subtler problem.
Our middleware function will return a 400 response in the case of any exception, even if "invalid data" in the request isn't the cause.
It's a little irresponsible to blame the user if, for example, our database server goes down and we can't establish a connection.

The problem lies in our `catch` clause—we want to get finer-grained than the all-encompassing `catch Exception e`.
We could start by splitting the function in two—one to catch Postgres exceptions (which would get thrown due to invalid data) and another to catch all other unexpected exceptions:

```clojure
(defn wrap-postgres-exception
  [handler]
  (fn [request]
    (try
      (handler request)
      (catch org.postgresql.util.PSQLException e
        {:status 400 :body "Invalid data"}))))

(defn wrap-fallback-exception
  [handler]
  (fn [request]
    (try
      (handler request)
      (catch Exception e
        {:status 500 :body "Something isn't quite right..."}))))

(def app
  (-> (handler/api app-routes)
      ring-json/wrap-json-response
      ring-json/wrap-json-params
      wrap-postgres-exception
      wrap-fallback-exception))
```

However, this implementation implicitly couples our routes namespace to our database implementation, since it knows to be on the lookout specifically for `PSQLException`.
If we changed our database, we would need to change code in this namespace as well.
To avoid this, let's move the PSQLException details to the database namespace and take ownership of them there using Clojure's `throw` and `ex-info` functions:

```clojure
(ns library.db
  (:require [clojure.java.jdbc :as jdbc]))

(defn wrap-exceptions
  [insert-call]
  (fn [connection table field-value-map]
    (try
      (insert-call connection table field-value-map)
      (catch org.postgres.util.PSQLException e
        (throw (ex-info "Invalid data" {}))))))

(def do-insert
  (wrap-exceptions (jdbc/insert!))

(defn insert!
  [connection table field-value-map]
  (do-insert connection table field-value-map))
```

Clojure's `ex-info` creates an instance of `clojure.lang.ExceptionInfo`, a more generic exception type.
We catch the Postgres-specific exception and throw the more generic one in its place—one that we can reference in the routes namespace:

```clojure
;; ns library.routes

(defn wrap-library-exception
  [handler]
  (fn [request]
    (try
      (handler request)
      (catch clojure.lang.ExceptionInfo e
        {:status 400 :body (.getMessage e)}))))
```

### Better feedback to users

Astute readers will notice the use of `getMessage` in the last code snippet.
Clojure's ExceptionInfo accepts a message and map as arguments when instantiated with `ex-info`, and we can access those values with `getMessage` and `ex-data` respectively.
The message we're passing to `ex-info` is still just "Invalid data," though, which isn't very helpful—our users may not understand _why_ the data they submitted is problematic.

Remember that when we catch the PSQLException, we have access to that exception object and can execute whatever code we like.
What if we call `getMessage` on that original Postgres exception?
Some example return values for various PSQLExceptions include:

```
null value in column "title" violates not-null constraint

new row for relation "books" violates check constraint "postive_page_count"
```

It's not much, but it's enough to provide significantly more informative error messages using regular expressions:

```clojure
;; ns library.db

(defn handle-pg-exception
  [exception]
  (let [message (.getMessage exception)
        not-null #"null value in column \"(\w+)\" violates not-null constraint"
        positive-page-count #"new row for relation \"books\" violates check constraint \"positive_page_count\""]
    (when-let [[_ field] (re-find not-null message)]
      (throw
        (ex-info
          (format "%s field cannot be blank" field)
          {})))
    (when (re-find positive-page-count message)
      (throw
        (ex-info
          "Books must have a positive page count"
          {})))
    (throw exception)))

(defn wrap-exceptions
  [insert-call]
  (fn [connection table field-value-map]
    (try
      (insert-call connection table field-value-map)
      (catch org.postgres.util.PSQLException e
        (handle-pg-exception e)))))
```

It is important to note the final `(throw exception)` call in `handle-pg-exception`.
We can define `when` clauses for all the constraints we explicitly define in our database, but some other Postgres exception not covered by our regexes could arise.
We don't want to just swallow that exception and return `nil`, so we have to throw that exception as-is.
This exception will still be a PSQLException, which means `wrap-library-exception` will not catch it, but `wrap-fallback-exception` will.

### Middleware in other contexts

Though most often associated with HTTP requests and responses, this middleware pattern is not limited exclusively to that context.
Let's use it to refactor all those `when` statements in `handle-pg-exception`:

```clojure
(defn- catch-clause?
  [x]
  (and (seq? x) (= 'catch (first x))))

(defmacro try-psql
  [& exprs]
  (let [[body [_ message-regexp bindings catch-expr]] (split-with (complement catch-clause?) exprs)]
    `(try ~@body
       (catch org.postgresql.util.PSQLException exception#
         (if-let [~bindings (re-find ~message-regexp (.getMessage exception#))]
           ~catch-expr
           (throw exception#))))))

(defn wrap-not-null-constraint
  [insert-call]
  (fn [& args]
    (try-psql
      (apply insert-call args)
      (catch #"null value in column \"(\w+)\" violates not-null constraint" [_ field]
        (throw
          (ex-info
            (format "%s field cannot be blank" field)
            {}))))))

(defn wrap-positive-page-count-exception
  [insert-call]
  (fn [& args]
    (try-psql
      (apply insert-call args)
      (catch #"new row for relation \"books\" violates check constraint \"positive_page_count\"" _
        (throw
          (ex-info
            "Books must have a positive page count"
            {}))))))

(def insert!
  (-> jdbc/insert!
      wrap-not-null-constraint
      wrap-positive-page-count-exception))
```

With this pattern implemented in the database namespace, adding middleware functions to handle new constraints introduced in later migrations becomes trivial.
Additionally, with the PSQLException details refactored into the `try-psql` macro, we can add middleware functions that don't deal with exceptions at all but transform data around insert calls in other ways.
For example, we could transform the keys of our field value maps between snake- and kebab-case before or after the insert call so that our codebase can use one consistent style.
Simply define a new `wrap-kebab-case-keys` function that takes `insert` (or a wrapped version of it) and returns a function that transforms data around the `insert` call.
Then add it to the thread in `def insert!`.

### Even further nuance

I've found this pattern to be incredibly fun to work with, and continue to expand on it today.
Most recently I've been working on providing the ID of an existing resource when a POST request attempts to create a duplicate.
I can look up the id using the request data and add the id to the error message in a `wrap-unique-constraint` middleware function.
However, this is one example of a few PSQLException situations in which 400 is not the most appropriate response code.
To provide more flexibility, I've started adding data to the previously blank maps passed to `ex-info`.
As mentioned above, the map can be accessed in the route middleware function via `ex-data`.
If we add a `:cause` to the exceptions we raise in the database namespace, we can provide more nuanced and appropriate status codes in our HTTP responses:

```clojure
;; ns library.db

(defn find-existing-record-id
  [args]
  ;; use args to query db and return id
)

(defn wrap-unique-constraint
  [insert-call]
  (fn [& args]
    (try-psql
      (apply insert-call args)
      (catch #"violates unique constraint \"(\w+)\"" [_ index]
        (let [id (find-existing-record-id (vec args))]
          (throw
            (ex-info
              (format "Resource already exists with id %s" id)
              {:cause :resource-exists}))))))

(defn wrap-broken-connection
  [insert-call]
  (fn [& args]
    (try-psql
      (apply insert-call args)
      (catch #"Connection refused" _
        (throw
          (ex-info
            "An error occurred attempting to connect to the database"
            {:cause :service-unavailable))))))


;; ns library.routes

(defn status-code-for
  [cause]
  (case cause
    :resource-exists 303
    :service-unavailable 503
    400))

(defn wrap-library-exception
  [handler]
  (fn [request]
    (try
      (handler request)
      (catch clojure.lang.ExceptionInfo e
        (let [cause (:cause (ex-info e))
              status-code (status-code-for cause)]
          {:status status-code :body (.getMessage e)})))))
```

A single, vague 400 response has evolved into a suite of detailed and informative responses thanks in large part to the middleware pattern.
It facilitates more readable, composable, and extensible code, which in turn encourages creative thinking;
I can imagine some interesting applications of middleware in other contexts like logging or even state transitions.
Try it out on your next Clojure project and see where it takes you!


[8lblog]: http://blog.8thlight.com/mike-knepper/2015/05/19/handling-exceptions-with-middleware-in-clojure.html
[Compojure]: https://github.com/ring-clojure/ring "Compojure"
[Ring]: https://github.com/ring-clojure/ring "Ring"
[handler/api]: https://github.com/weavejester/compojure/blob/master/src/compojure/handler.clj#L19-L30 "handler/api"
