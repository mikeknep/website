# SOLID Design Principles

## Single Responsibility
There should never be more than one reason for a class to change.

A Rectangle class has two instance methods: `calculate_area` and `display_in_Terminal`. This class is currently handling two responsibilities: geometric calculation and visual display. What if we want to change the characters used to display the rectangle from, say, hyphens to asterisks? This change has nothing to do with the `calculate_area` method, which has a fixed and independent responsibility.

We should instead have two classes: Rectangle and RectangleDisplay. Now, if we want to change how rectangles are displayed, we alter the RectangleDisplay class without needlessly affecting the Rectangle class.


## Open-Closed
Software entities should be open for extension, but closed for modification

A ShapeCalculator class has a `calculate_area(shape)` method that calculates the area of different shapes (instances of, for example, Circle or Rectangle classes). The method cases the class of the argument (the shape) and performs different private methods (`circle_area`, `rectangle_area`) to return the area of the shape based on the class. The problem here is that if you want to add a new shape (let's say a triangle), you have to add a new method `triangle_area` and edit the `calculate_area(shape)` method to include `when Triangle`. In other words, it's very difficult to extend the class to accommodate more shapes, and to do so requires modifying the ShapeCalculator class.

The better way to do this is to give each shape class an `area` method, and the `calculate_area(shape)` method in the ShapeCalculator class simply calls the `area` instance method on the instance of whatever shape it receives as the argument. Now you can write a new class, Triangle, with a method `area`, and ShapeCalculator's `calculate_area(shape)` will be able to accommodate triangle instances. ShapeCalculator has been extended without requiring any modification.


## Liskov Substitution
Functions that use pointers or references to base classes must be able to use objects of derived classes without knowing it.

**THIS ONE IS CONFUSING**


## Interface Segregation
Clients should not be forced to depend upon interfaces that they do not use



## D (??)