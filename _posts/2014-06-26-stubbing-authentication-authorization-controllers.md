---
layout: post
title: Stubbing Authentication and Authorization in Controller Specs
---

(Also posted on the [8th Light blog][8lblog].)

Controllers are powerful and complicated objects that easily accumulate responsibilities. Even when following the classic Rails convention of "Skinny Controllers, Fat Models", controllers still have a lot to handle. One extremely important responsibility is checking user authentication and authorization. The typical way to handle these two critical aspects of a web application in Rails is through the use of `before_action` or `before_filter` statements. These are called before specified actions in the controller and are capable of redirecting users before they reach those actions. For example:

```ruby
class NuclearLaunchCodesController < ApplicationController
  before_action :authenticate_user
  before_action :require_admin, only: [:new, :create]

  def index
    @codes = NuclearLaunchCode.all
  end

  def show
    @code = NuclearLaunchCode.find(params[:id])
    @presenter = CodePresenter.new(@code) # did you read my last post? ;)
  end

  def new
    @code = NuclearLaunchCode.new
  end

  def create
    @code = NuclearLaunchCode.new(params[:code])
    @code.save!
    redirect_to(code_path(@code)), notice: "Successfully created new Nuclear Launch Code!"
  rescue StandardError => e
    flash[:error] = [e.message]
    redirect_to new_code_path(@code)
  end

  private

  def current_user
    @current_user = User.find_by_id(session[:user_id]) if session[:user_id]
  end

  def authenticate_user
    redirect_to(login_url, notice: "You must be signed in to view that page") unless current_user.present?
  end

  def require_admin
    redirect_to(root_url, notice: "You are not authorized to perform that action") unless current_user.admin?
  end
end
```

We don't want any random person browsing the web to access the index or show pages of our top secret nuclear launch codes, so we define a `before_action` filter to make sure a user is signed in. This method redirects every request to the login page unless a user is present. An unauthenticated browser cannot ever access those actions. In addition to that rule, our `new` and `create` actions have even tighter security: they can only be performed by admin users. Like the `authenticate_user` filter, `require_admin` will redirect any user to the home page unless they are an admin user.

This relatively simple technique actually works great for production. However, it definitely complicates the spec; if we try to run these actions in a test, the filters will boot us away from any action before we reach it, and thus all tests will fail. We could create a user in the spec file and log in before running the specs, but that can easily get extremely complicated: the users table may have validations that we'd need to know about and keep track of to successfully create a test user, we'd need to manipulate the session hash to simulate being logged in, etc. But do not fear--there is a better way.

### Authentication

First let's address authentication. Presumably logging in and out is tested somewhere else in the application (it better be!), so we know that if those tests pass, the filter will work here too. If it's safe to assume in the context of this test that the authentication method works, we just want to bypass it. It turns out we can do this fairly easily by stubbing the `before_action`. Stubbing is a concept that often seems intimidating but is actually quite simple: all you're doing when you stub a method is say "any time this method is called, don't actually call it, just return X". The syntax looks like this: `object.stub(:method) { return_value }`. In this case, our object is the controller under test, the method is the `authenticate_user` method, and it turns out our return value is nothing at all. Controller filters don't have a return value when they pass, but instead simply allow the controller to continue on to the requested action. So in our spec, we can simply write this to pass our `index` and `show` specs:

```ruby
describe NuclearLaunchCodesController do
  let(:test_code_1) { NuclearLaunchCodeFactory.create }
  let(:test_code_2) { NuclearLaunchCodeFactory.create }

  it "assigns all codes to @codes" do
    controller.stub(:authenticate_user)
    get :index
    expect(assigns(:codes)).to eq([test_code_1, test_code_2])
  end

  it "assigns the correct code to @code" do
    controller.stub(:authenticate_user)
    get :show, :id => test_code_2.id
    expect(assigns(:code)).to eq(test_code_2)
  end
end
```

(I'm hiding the details of a spec_helper factory generating test launch codes.)

When `get :index` and `get :show` are called, the controller intends to made the `before_action :authenticate_user` call, but recognizes that that method has been stubbed out, so it ignores the production code and continues right along. Perfect!

### Authorization

What about the `new` and `create` actions? We could stub out the call to the `require_admin` filter like we do for authentication, but let's assume that this is the only place in our app that requires admin permissions. We want to be 100% sure that regular users can't create new launch codes, and this is the only place that will really be tested.

The trick here is to allow the `before_action :require_admin` call to be made, but simulate being logged in as an admin user in one test and as a regular user in another. But remember, we want to do this without making user objects. Fortunately, `current_user` is a method on the controller that returns and/or fetches the current user from the session hash. (Technically this would be in the ApplicationController, but for readability I've put it in the controller under test.) Because `current_user` is a method call, we can stub it and tell it to return some dummy admin user. However, that returned dummy can't just be a primitive Ruby object like a String, because it needs to have the method `admin?` defined (otherwise we'd get an "undefined method" error). What we need is a "double":

```ruby
admin_user = double('a user', :admin? => true)
controller.stub(:current_user) { admin_user }
```

The first line creates our double. The first argument, `'a user'`, is little more than an identifier, but the second argument is critical: it allows the object to have the method `admin?` called on it and return `true`. Essentially it is defining the method and stubbing it, all in one.

Once the double is set up, we stub the controller's `current_user` method to return that double. This line can also be written like this: `allow(controller).to receive(:current_user).and_return(admin_user)`.

We can now write our test for the `new` action:

```ruby
it "assigns a new instance of a NuclearLaunchCode to @code" do
  admin_user = double('a user', :admin? => true)
  controller.stub(:current_user) { admin_user }
  get :new
  expect(assigns(:code)).to be_a_new(NuclearLaunchCode)
end
```

`get :new` is called. The controller recognizes `new` as an action requiring first calling the `require_admin` filter. The filter will redirect to the root page, `unless current_user.admin?`. What is `current_user`... a variable? a method? It's a method that has been stubbed on the controller to return a double object. OK, next call `admin?` on that object. Is it defined? Yes, in the definition/instantiation of the double, `admin?` is set to return `true`. The filter therefore does not redirect to root but instead allows the request to `get :new` to continue on.

### Final refactor

After some refactoring, our controller spec becomes quite readable--the requisite high-level behavior is provided without cluttering up the specs, keeping the focus on the object under test: the controller.

```ruby
describe NuclearLaunchCodesController do
  let(:code_1) { NuclearLaunchCodeFactory.create }
  let(:code_2) { NuclearLaunchCodeFactory.create }

  before :each do
    controller.stub(:authenticate_user)
  end

  def log_in_as_admin_user
    admin_user = double('an admin user', admin: true)
    allow(controller).to receive(:current_user).and_return(admin_user)
  end

  def log_in_as_regular_user
    regular_user = double('a regular user', admin: false)
    allow(controller).to receive(:current_user).and_return(regular_user)
  end


  context "#index" do
    it "assigns all launch codes to @codes" do
      get :index
      expect(assigns(:codes)).to eq([code_1, code_2])
    end
  end

  context "#show" do
    it "assigns the correct launch code to @code" do
      get :show, :id => code_2.id
      expect(assigns(:code)).to eq(code_2)
    end
  end

  context "#new" do
    it "assigns a new NuclearLaunchCode to @code" do
      log_in_as_admin_user
      get :new
      expect(assigns(:code)).to be_a_new(NuclearLaunchCode)
    end

    it "does not allow non-admin users to see the new code page" do
      log_in_as_regular_user
      get :new
      expect(response).to redirect_to(root_url)
    end
  end

  context "#create" do
    it "allows admins to create a new NuclearLaunchCode" do
      log_in_as_admin_user
      params = {:launch_sequence => 12345, :target => "Moscow"}
      expect{
        post :create, params
      }.to change(NuclearLaunchCode, :count).by(1)
      new_code = NuclearLaunchCode.find_by_launch_sequence(12345)
      expect(new_code.target).to eq("Moscow")
    end

    it "doesn't allow non-admins to create a new code" do
      log_in_as_regular_user
      params = {:launch_sequence => 12345, :target => "Moscow"}
      expect{
        post :create, params
      }.to_not change(NuclearLaunchCode, :count)
    end
  end
end
```

[8lblog]: http://blog.8thlight.com/mike-knepper/2014/07/01/stubbing-authentication-and-authorization-in-controller-specs.html
