---
layout: post
title: "Keeping Laravel Controllers Clean with Form Requests"
8thLightURL: https://blog.8thlight.com/mike-knepper/2016/09/26/keeping-laravel-controllers-clean-with-form-requests.html
---

I've recently been working in PHP and have been very impressed by the [Laravel][laravel-home] web framework.
At first, having only heard horror stories of massive `if/else` statements and SQL queries in HTML views, I wondered if writing clean PHP code would even be possible.
But while PHP certainly has many "gotchas," one can still use it to write well-organized, testable software.
Furthermore, Laravel in particular is an excellent, modern MVC framework, offering a logical directory structure out of the box without being too dictatorial about where your code should go.
Laravel will feel quite familiar to Rails or Django developers, but it also provides a few unique and valuable tools.
Perhaps my favorite of these are Form Requests, which provide a great way to keep your controllers clean and concise.


### Form Requests

Like many MVC frameworks, every action in a Laravel controller can access details about the HTTP request routed to that action.
Laravel takes an extra step by allowing the developer to define different types of requests specific to certain actions.
These action-specific requests serve as contracts that must be met for the action to be processed.

Imagine we have a POST endpoint for a form that creates a new `Book`.
<span id="source-1"><a href="#footnote-1">[1]</a></span>
Each `Book` must have a title and publication date.
Typically our controller action (or, preferably, some custom validator object called within that action) needs to access the request parameters and validate the presence and data types of the two `Book` fields.
The action then switches on the success or failure of that validation logic to either create the `Book` or redirect back to the form with error messages.

In Laravel, we can push this validation logic above the controller using a Form Request:

```php
<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class CreateBookFormRequest extends FormRequest
{
    public function authorize()
    {
        return true;
    }

    public function rules()
    {
        return [
            'title' => 'required|alpha_num',
            'publicationDate' => 'required|date'
        ];
    }
}
```

To use this Form Request, we simply type-hint it in the argument list of the controller action:

```php
<?php

namespace App\Http\Controllers;

use App\Http\CreateBookFormRequest;

class BookController extends Controller
{
    public function store(CreateBookFormRequest $request)
    {
        // ...
    }
}
```

Now all requests to the `book.store` route will be validated against the rules defined in the `CreateBookFormRequest`—namely that `title` is alpha-numeric and `publicationDate` is a date.
Requests that fail to meet this criteria are automatically redirected back to the form page with clear error messages.
By specifying these request details in the signature of the controller function, we identify and handle invalid requests as early and close to the user as possible.
<span id="source-2"><a href="#footnote-1">[2]</a></span>
As a result, our controller code can focus exclusively on happy-path user input scenarios—we are certain `title` and `publicationDate` are present and valid inside the `store` action and need not write defensive `null` or type checks for them.


#### Writing custom validation rules

Laravel ships with [several useful validations][validations] out of the box (including `required` and `alpha_num` used above), but also provides a way to define custom validation rules.
Simply extend the default Validation Factory in the Form Request's constructor, then add the named rule to the relevant field's list of rules in `rules`:

```php
<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Factory;

class CreateBookFormRequest extends FormRequest
{
    public function __construct(Factory $factory)
    {
        $name = 'is_palindrome'; // a name for our custom rule, to be referenced in `rules` below
        $test = function ($_, $value, $_) {
            return $value === strrev($value);
        };
        $errorMessage = 'Book titles must be palindromes (spelled the same backward and forward).';

        $factory->extend($name, $test, $errorMessage);
    }

    public function authorize()
    {
        return true;
    }

    public function rules()
    {
        return [
            'title' => 'required|alpha_num|is_palindrome', // $name from new rule above added here
            'publicationDate' => 'required|date',
        ];
    }
}
```

Our library will now get significantly fewer additions, as only palindromic titles will be accepted.

In our app, rather than adding these rules inline as above, we define all custom validations as individual classes that implement a `CustomValidation` interface.
This facilitates easier and more focused unit tests for potentially complex validation logic, as well as ensuring we provide descriptive error messages (which are technically optional on `Factory#extend`).
The full code looks like this:

```php
<?php

namespace App\Http\Validations;

interface CustomValidation
{
    public function name();
    public function test();
    public function errorMessage();
}


---

<?php

namespace App\Http\Validations;

use CustomValidation;

class PalindromeTitle implements CustomValidation
{
    public function name()
    {
        return 'is_palindrome';
    }

    public function test()
    {
        return function ($_, $value, $_) {
            return $value === strrev($value);
        }
    }

    public function errorMessage()
    {
        return 'Book titles nust be palindromes (spelled the same backward and forward).';
    }
}


---

<?php

namespace App\Http\Requests;

use App\Http\Validations\PalindromeTitle;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Factory;

class CreateBookFormRequest extends FormRequest
{
    public function __construct(Factory $factory)
    {
        $this->useCustomValidations($factory, $this->applicableValidations());
    }

    public function authorize()
    {
        return true;
    }

    public function rules()
    {
        return [
            'title' => 'required|alpha_num|is_palindrome',
            'publicationDate' => 'required|date',
        ];
    }

    private function applicableValidations()
    {
        return collect([
            new PalindromeTitle(),
            // add other custom validations here
        ]);
    }

    private function useCustomValidations($factory, $validations)
    {
        $validations->each(function ($validation) use ($factory) {
            $factory->extend($validation->name(), $validation->test(), $validation->errorMessage());
        });
    }
}
```


#### What about that authorize method?

You may be wondering about the `authorize` function returning `true` in the snippets above.
This function allows you to reject certain requests, not because they contain invalid data, but rather because their source is unauthorized.
In my experience, authorization is more logically implemented as middleware that applies to entire controllers rather than individual requests, but your mileage may vary.


### A splash of static analysis

In some statically typed languages, the compiler analyzes all possible code paths, knows if values can be `null`, and warns the developer when the possibility of `null` has not been addressed.
Dynamically typed languages do not have this benefit, and consequently often include substantially more defensive coding like `null` checks and type coercion.
By using Form Requests in Laravel, you can mimic some of the benefits of static type analysis, knowing that the params values entering your controller action meet specified criteria.
As a result, your code is both safer and more readable.


<br />
<span id="footnote-1"><a href="#source-1">[1]</a></span> You can define custom requests for GET endpoints too, which are particularly useful for API endpoints that support filtering via query parameters.
<span id="footnote-2"><a href="#source-2">[2]</a></span> Within the context of a server-side framework, at least. These same validations could be performed on the client using JavaScript.

[laravel-home]: https://laravel.com/
[validations]: https://laravel.com/docs/5.3/validation#available-validation-rules
