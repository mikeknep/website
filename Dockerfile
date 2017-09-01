FROM ruby:2.4

RUN apt-get -qq update && apt-get -qqy install lilypond
