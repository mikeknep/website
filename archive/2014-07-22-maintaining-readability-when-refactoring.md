---
layout: post
title: Maintaining Readability When Refactoring
---

Significant refactors can be slick and impressive in the git diff, but it's important not to get carried away.

Alex wrote a great [post](http://alexander-hill.tumblr.com/post/91202439460/useful-clojure-macros-for-the-object-oriented) recently diving into Clojure macros. It inspired me to go back to my Clojure implementation of Tic-Tac-Toe and see if I could refactor any functions to be more terse and idiomatic. I quickly identified three functions using the `loop/recur` syntax that could be refactored into tighter, one-line statements:

```clojure
;
; Original
;

; (ns tictactoe.board)
(defn values-at-indexes [indexes board]
  (loop [indexes  indexes
         tokens   []]
    (if (empty? indexes)
      tokens
      (recur (rest indexes)
             (conj tokens (nth board (first indexes)))))))


; (ns tictactoe.paths)
(defn row-indexes [length]
  (loop [all-rows []
         counter  0]
    (if (= counter length)
      all-rows
      (recur (conj all-rows (take length (iterate inc (* length counter))))
             (inc counter)))))

(defn column-indexes [length]
  (loop [all-columns []
         counter     0]
    (if (= counter length)
      all-columns
      (recur (conj all-columns (take length (iterate (partial + length) counter)))
             (inc counter)))))


;
; New
;

; (ns tictactoe.board)
(defn values-at-indexes [indexes board]
  (map nth (repeat board) indexes))


; (ns tictactoe.paths)
(defn- row-indexes [length]
  (partition length (range (* length length))))

(defn- column-indexes [length]
  (apply mapv vector (row-indexes length)))
```

I greatly enjoyed refactoring these methods. Obviously the new versions are more concise, which is a quality I generally admire in all forms of communication. They also feel more dynamic and alive--looping and recurring feels tiresome compared to these few words that explode with action. But before we declare this refactor a success, there is one more important thing to take into consideration: readability.

Would someone reviewing my code easily understand what these functions are doing? Fortunately in this case I believe the refactored versions are more readable than the original versions, though both the old and new require more than a mere glance to really understand. Clojure has many core functions that "expand" or "unpack" to do a lot of work with very few characters, a trait that is both fascinating and dangerous. If other developers are constantly referencing the Clojure docs in order to understand your code, your one-line solution isn't clever--it's annoying. (Note: those "other developers" might include you in the future some day--don't make it hard on yourself!)

With that in mind, here are two ways to maintain readability while refactoring.


### Private functions

Astute readers will have noticed that my new `row-indexes` and `column-indexes` functions changed from `defn` to `defn-`. The hyphen sets these functions as private to the namespace. This means that they cannot be called by any function outside that namespace. My game's "paths" namespace has one public function, `all-winning-indexes`, which returns every permutation of rows, columns, and diagonals on a Tic-Tac-Toe board. This function makes use of three private functions: `row-indexes`, `column-indexes`, and `diagonal-indexes`. These three functions do not need to be exposed outside of the namespace; the other parts of the app only need to access the full set of winning indexes and do not care how that set is generated.

Making certain functions private prioritizes your code for other developers. They know at a glance that the public functions are both more important and higher-level than the private functions they rely on. If there is a bug occurring somewhere around that public function, or if they're just curious about the details, then they can dig into the private functions.


### Descriptive specs

My refactored `values-at-indexes` function might still be tricky to grasp. Is it named descriptively? Meh, I'm not overjoyed with the name, but I can't really think of a better one either. I can't make it private because some rule functions need to call it. However, given it is a public function and I practice TDD, there should be a test for this function. Indeed there is; it looks like this:

```clojure
(it "returns the tokens played on the board at the provided indexes"
  (let [indexes [0 2 4]
        board   ["X" nil "O"
                 nil nil nil
                 nil nil nil]]
    (should= ["X" "O" nil] (values-at-indexes indexes board)))))
```

Aha! The test clearly states in English what the function should do, and on top of that demonstrates it in action!

Much has been written about the value of thoroughly testing code and TDD. Many of these arguments focus on the value to the original developer (ex. confidence when refactoring) and the production code (ex. decoupled design), but the external value should not be overlooked. Clean, well-organized specs effectively serve as documentation for the production code; brevity aside, they are hardly any different than the official documentation for the language's core functions.
