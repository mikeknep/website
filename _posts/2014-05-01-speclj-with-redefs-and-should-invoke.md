---
layout: post
title: Speclj with-redefs and should-invoke
---

Speclj is a Clojure testing framework very similar to Ruby's RSpec. Its most basic component is `(should= x x)`--this function forms the backbone of my test suite, covering nearly all my unit tests much like `expect(x).to eq(x)` tends to do in my RSpec tests. However, I do have a few more complicated namespaces for which `should=` by itself is insufficient. I will walk through two more complicated test cases here.

### Stubbing with-redefs
This week I added a Spanish language option to my Clojure Tic-Tac-Toe. A config file holds a simple language declaration `{:language "English"}`, and a corresponding translation file `translations/english.txt` contains the raw output text for that language. In the code, `language` parses the config file to determine which language to use, while `language-source` calls the language function to return the appropriate language file:

{% highlight clojure %}
(ns tictactoe.language)

(defn language []
  ((load-string (parse "config.txt")) :language))

(defn language-source []
  (str "translations/" (clojure.string/lower-case (language)) ".txt"))
{% endhighlight %}

These functions both depend on the `parse` method reaching out to the config.txt file, which is exactly what I want during gameplay, but not ideal for testing, for two reasons. First, I only want to test the language namespace (the parse function is tested separately in its own spec). Second, the config.txt file will change in the future as users change their preferred language, but I want to control the data in my tests.

So, we want to stub the `parse` function. To do this, I used Clojure's `with-redefs` function. My tests look like this:

{% highlight clojure %}
(describe "language"
  (it "returns the language from the config file"
    (with-redefs [parse (fn [_] (str "{:language \"Pig-Latin\"}\n"))]
      (should= "Pig-Latin" (language))))

  (it "returns the english text file when language is set to English"
    (with-redefs [language #(str "English")]
      (should= "translations/english.txt" (language-source)))))
{% endhighlight %}

A couple things to notice here. First, `with-redefs` is not providing a static return value like a string; instead, it is temporarily redefining the function *as some other function to be executed*. That explains the somewhat silly-looking `#(str "English")`. Second, though I prefer Clojure's short anonymous function syntax (with the # symbol), I had to use the longer fn syntax for `parse` because my original `parse` function requires an argument (the filename). Even though I don't use that argument (represented in my test as an underscore) in the new temporary function, I still have to redefine the function with the same number of arguments. The hashtag (#) syntax doesn't let you declare an argument without using it.

### Should-invoke
My `play` function is the highest-level function in the game. It connects all the lower-level functions together, looping through them until the game is over. Testing this function is arguably unnecessary--some people have said that since all the individual functions within `play` have been tested in isolation, I don't really need to test `play` itself. However, I like having some tests for this function because they effectively serve as high-level, end-to-end integration tests. Wiring everything up together isn't necessarily a cakewalk, and these tests help me stay confident that the whole game can be played start to finish without having to fire up `lein trampoline run` and play a game myself.

The tricky part for me, though, was figuring out how to test this loop. My first decision was to use Speclj's `should-contain` function to make sure that, among the various messages printed to the screen, the game over messages were eventually printed. However, I realized how brittle these tests were when I added the Spanish language option. Switching the config file to `{:language "Spanish"}` would break the `play` tests because they were expecting "Draw!" or "Winner!" but instead received "Empate!" and "Ganador!". The `play` function itself was still working correctly--Spanish didn't break it--but my tests were providing incorrect feedback. Unacceptable.

Fortunately, Speclj provides `should-invoke`, which tests that a given function is called somewhere at some point. Now, instead of writing tests looking for specific messages, a la `(should-contain "Draw!" (play game))`, I simply make sure that the last function in the loop gets called: `(should-invoke present-result {:times 1} (play game))`. (Note: I had some trouble realizing that `should-invoke` requires some kind of option like `:times`. It seems you can't just test that a function is invoked without any detail about that invocation.) Now all my tests pass regardless of which language is selected in the config file. The code accommodates changes to the config file, but these changes do not cause tests to provide incorrect feedback about the code.