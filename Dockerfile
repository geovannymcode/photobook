# syntax=docker/dockerfile:1
ARG RUBY_VERSION=3.3.13
FROM ruby:${RUBY_VERSION}-slim AS base
WORKDIR /rails
ENV RAILS_ENV=production BUNDLE_DEPLOYMENT=1 BUNDLE_PATH=/usr/local/bundle BUNDLE_WITHOUT=development:test
RUN apt-get update -qq && apt-get install --no-install-recommends -y libvips sqlite3 curl && rm -rf /var/lib/apt/lists/*

FROM base AS build
RUN apt-get update -qq && apt-get install --no-install-recommends -y build-essential pkg-config libyaml-dev git && rm -rf /var/lib/apt/lists/*
COPY Gemfile Gemfile.lock ./
RUN bundle install
COPY . .
RUN SECRET_KEY_BASE_DUMMY=1 APP_HOST=localhost SMTP_ADDRESS=localhost bundle exec rails assets:precompile

FROM base
RUN groupadd --gid 1000 rails && useradd --uid 1000 --gid 1000 --create-home rails
COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build --chown=rails:rails /rails /rails
RUN mkdir -p storage tmp log && chown -R rails:rails storage tmp log
USER rails
EXPOSE 3000
ENTRYPOINT ["/rails/bin/docker-entrypoint"]
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
