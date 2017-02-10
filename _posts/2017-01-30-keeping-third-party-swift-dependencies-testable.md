---
layout: post
title: "Keeping Third-Party Swift Dependencies Testable"
8thLightURL: https://blog.8thlight.com/mike-knepper/2017/01/30/keeping-third-party-swift-dependencies-testable.html
---

When adding a third-party library to a project, I typically find plenty of examples of how to use the library in a dead-simple, script-like way, but not how to properly integrate it into a larger system.
In particular, it can be unclear how to use the library in a way that doesn't sacrifice testability.
In this post I will walk through adding [Alamofire][alamofire], an HTTP networking library, to a Swift project in a way that keeps business logic and behavior easily testable.

### Initial Integration

For completely decontextualized usage examples, check out Alamofire's README.
To begin this post, I'll start with a basic example of a service using Alamofire to send data about an "order" (a stand-in for any domain model) to a server.

```swift
import Alamofire

public class HttpOrderService {
    let baseUrl: String

    public init(baseUrl: String) {
        self.baseUrl = baseUrl
    }

    public func createOrder(order: Order) {
        let createOrderEndpoint = "\(baseUrl)/orders"
        let orderPayload = jsonify(order: order)
        Alamofire.request(createOrderEndpoint, method: .post, parameters: orderPayload, encoding: JSONEncoding.default)
            .responseJSON { response in
                if let json = response.result.value {
                    // handle response (elided)
                }
        }
    }

    func jsonify(order: Order) -> [String: Any] {
        // elided
    }
}
```

The problem here is obvious—`HttpOrderService` has a concrete dependency on Alamofire, and consequently any unit tests written for the service need to make network calls.
Yuck.

We know some solutions for this: interfaces and dependency injection.

### Protocols to the Rescue

Swift provides an abstraction called a protocol, which for the purpose of our example is essentially the same as an interface.
Let's define a protocol for communicating with a server:

```swift
public protocol NetworkAdapter {
    func post(destination: String, payload: [String: Any], responseHandler: TypeElidedForNow)
}
```

We'll come back to that elided `responseHandler` type a little later;
the immediate important point is that we can define a class that conforms to the `NetworkAdapter` protocol and uses Alamofire under the hood.

```swift
import Alamofire

public class AlamofireNetworkAdapter: NetworkAdapter {
    func post(destination: String, payload: [String: Any], responseHandler: TypeElidedForNow) {
        Alamofire.request(destination, method: .post, parameters: payload, encoding JSONEncoding.default)
            .responseJSON { response in responseHandler(response) }
    }
}
```

This is very similar to writing a "wrapper" in object-oriented languages.
In addition to the implementation above, we can define any number of mock network adapters for use in our tests.
As one example, to verify the destination and payload provided by the caller, we could write a spy:

```swift
class SpyingNetworkAdapter: NetworkAdapter {
    var postWasCalled = false
    var destination: String? = nil
    var payload: [String: Any]? = nil

    func post(destination: String, payload: [String: Any], responseHandler: TypeElidedForNow) {
        self.postWasCalled = true
        self.destination = destination
        self.payload = payload
    }
}
```

Now we simply use dependency injection to provide a `NetworkAdapter` to the `HttpOrderService`.

```swift
public class HttpOrderService {
    let baseUrl: String
    let networkAdapter: NetworkAdapter

    public init(baseUrl: String, networkAdapter: NetworkAdapter) {
        self.baseUrl = baseUrl
        self.networkAdapter = networkAdapter
    }

    public func createOrder(order: Order) {
        let createOrderEndpoint = "\(baseUrl)/orders"
        let orderPayload = jsonify(order: order)
        let responseHandler = buildResponseHandler()
        networkAdapter.post(destination: createOrderEndpoint, payload: orderPayload, responseHandler: responseHandler)
    }

    func buildResponseHandler() -> TypeElidedForNow {
        // handle the response
    }
}
```

### Custom Types

OK, I know, `TypeElidedForNow` is driving you nuts.
Me too—let's fix it.

The response handler is a callback function that operates on the response.
Because Alamofire executes asynchronously so that we aren't blocked by the network call, this function does not yield a return value.<a href="#footnote-1">[1]</a>
Its type signature will therefore look something like this: `@escaping (SomeResponseType) -> ()`.
Now we just need to figure out what that response type is.

According to the documentation, Alamofire's `responseJSON` function accepts a function (they call it a `completionHandler`) that operates on another type they define: `DataResponse<Any>`.
It would seem that our response handler therefore needs to operate on a `DataResponse<Any>`.
However, we know right away that this is definitely not what we want.
First of all, we don't want Alamofire details to leak into the rest of our system;
furthermore, we don't know how complicated it is to create an Alamofire `DataResponse<Any>`—constructing some for tests could be a deep rabbit hole.

Instead, let's define our own type—we'll call it `ServiceResponse`.
Thinking through the possibilities of a call to our server, our `ServiceResponse` has three logical states:
a call can succeed with a successful response from the server;
a call can succeed but return errors from the server (such as improper authentication or data validation errors);
or the call can fail to communicate with the server (e.g. the call times out).
All three of these states have associated data, such as information requested from the server or error messages.
Sounds like a great use for a Swift enum!

For convenience, I'll assume our back-end service conforms<a href="#footnote-2">[2]</a> to the [JSON API][json-api] specification.
I've added some type aliases to improve the readability.

```swift
typealias JsonData = [String: Any]
typealias JsonErrors = [[String: Any]]

public enum ServiceResponse {
    case success(JsonData)
    case errors(JsonErrors)
    case failure(String)
}
```

Constructing a `ServiceResponse` "by hand" will be easy enough in our tests, as it's just a Plain Old Swift Type.
However, if we try to pass a `responseHandler: @escaping (ServiceResponse) -> ()` to the `responseJSON` call in the `AlamofireNetworkAdapter` we will get a compiler error.
How do we reconcile the different types, `ServiceResponse` and `DataResponse<Any>`?

### Extending Types

The answer lies in "extensions."
Swift allows you to extend any type, including types defined by external libraries!
Let's extend the `DataResponse` to coerce itself into a `ServiceResponse`.

```swift
import Alamofire

extension Alamofire.DataResponse {
    public var serviceResponse: ServiceResponse {
        if let message = self.result.error?.localizedDescription {
            return ServiceResponse.failure(message)
        }

        guard let json = self.result.value as? JsonData else {
            return ServiceResponse.failure("Did not receive JSON response")
        }

        if let errors = json["errors"] as? JsonErrors {
            return ServiceResponse.errors(errors)
        }

        return ServiceResponse.success(json["data"])
    }
}
```

The above code adds a public `serviceResponse` property to Alamofire's `DataResponse` type, and uses existing properties (defined by Alamofire) on the `DataResponse` to create and return a `ServiceResponse`.
Now we just need to make one small change to our `AlamofireNetworkAdapter` so that the response handler it receives operates on that `serviceResponse` property of the Alamofire request's `response`:

```swift
import Alamofire

public class AlamofireNetworkAdapter: NetworkAdapter {
    func post(destination: String, payload: [String: Any], responseHandler: @escaping (ServiceResponse) -> ()) {
        Alamofire.request(destination, method: .post, parameters: payload, encoding JSONEncoding.default)
            .responseJSON { response in responseHandler(response.serviceResponse) }
    }
}
```

### Own Your Code

The end result of all this refactoring is a much more testable system.
The `SpyingNetworkAdapter` above validates that our `HttpOrderService` makes a network call to the correct destination and with the correct payload.
Other mocks can be written to test the behavior of the response handler in different response cases:

```swift
let successData: JsonData = ["orderId": "123"]
let errors: JsonErrors = [["itemNumber": "Invalid"], ["customerId": "Invalid"]]
let failureMessage = "Failed to communicate with server"

let successfulResponse = ServiceResponse.success(successData)
let erroredResponse = ServiceResponse.errors(errors)
let failedResponse = ServiceResponse.failure(failureMessage)

class MockSuccessfulNetworkAdapter: NetworkAdapter {
    func post(destination: String, payload: [String: Any], responseHandler: @escaping (ServiceResponse) -> ()) {
        responseHandler(successfulResponse)
    }
}

class MockErroredNetworkAdapter: NetworkAdapter {
    func post(destination: String, payload: [String : Any], responseHandler: @escaping (ServiceResponse) -> ()) {
        responseHandler(erroredResponse)
    }
}

class MockFailingNetworkAdapter: NetworkAdapter {
    func post(destination: String, payload: [String : Any], responseHandler: @escaping (ServiceResponse) -> ()) {
        responseHandler(failedResponse)
    }
}
```

The adapters above can be passed in to the `HttpOrderService` in different tests to simulate any of the possible responses without actually going out over the wire.
I find these tests ultimately operate at a level that truly verifies the behavior of the app, without mocking and stubbing to the point of feeling like I'm just testing my tests and have no confidence the wiring works in production.

We started with a concrete Alamofire implementation and used protocols and extensions to reduce Alamofire to an implementation detail—a solid exercise in wrangling dependencies.
However, the next external library addition doesn't need to follow the same development process.
Instead, when possible, I recommend trying to write code to the interface you want from the start, and incorporating third-party code to fit that interface second.
If you like TDD, this approach certainly better facilitates that approach.
More importantly, it ensures that the code fits the problem domain well.
When internally-defined interfaces drive the design of a system, the system becomes more consistent, easier to understand, and ultimately [more pleasant][williams-talk] to maintain and evolve.


#### Footnotes
<span id="footnote-1"><a href="#source-1">[1]</a></span> A function that returns void is either completely useless or mutates state. This seems antithetical to functional programming, but actually fits the [Model-View-Presenter pattern][mvp] quite well.

<span id="footnote-2"><a href="#source-2">[2]</a></span> _Almost_. Technically, the value of `data` could be an array of resource objects, not just a single resource object. Forgive me.


[alamofire]: https://github.com/Alamofire/Alamofire
[json-api]: http://jsonapi.org/format
[williams-talk]: https://youtu.be/A0VaIKK2ijM?t=11m7s
[mvp]: http://iyadagha.com/using-mvp-ios-swift/
