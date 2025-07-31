FROM ruby:3.4.5

WORKDIR /app

RUN gem install bundler --version 2.7.1
RUN bundle config set force_ruby_platform true

COPY Gemfile /app
COPY Gemfile.lock /app
RUN bundle install

ENTRYPOINT ["bundle", "exec", "jekyll", "serve", "--host", "0.0.0.0"]
