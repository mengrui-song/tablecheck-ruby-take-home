# tablecheck-ruby-take-home

Short description
This repository contains a Ruby-based take-home exercise for TableCheck. The README below gives practical steps to set up, run, and test the project locally.

## Prerequisites

- Ruby 3.3.5.
- Bundler (`gem install bundler`)
- Database: MangoDB
- Node.js & Yarn only if front-end assets are present (Rails apps).

## Installation

1. Clone the repository:
   git clone <https://github.com/mengrui-song/tablecheck-ruby-take-home.git>

   cd tablecheck-ruby-take-home

2. Install gems:
   bundle install

3. If the project has a `Gemfile.lock` created with a specific Ruby, consider using a Ruby version manager (rbenv/rvm).

4. Check for additional setup files:
   - If a `.env.example` exists, copy it to `.env` and fill in secrets:
     cp .env.example .env

## Running the app

- docker compose up

- Start a Rails console inside the running app container:
  docker compose exec app rails c

## Running tests

Common test commands:

- RSpec:
  bundle exec rspec

- MiniTest / Rake:
  bundle exec rake test

If tests require the DB, make sure to prepare the test database:
bundle exec rake db:test:prepare

## Linting and formatting

bundle exec rubocop

## Project structure (typical)

- app/ or lib/ — application code
- spec/ or test/ — tests
- config/ — configuration (DB, environment)
- bin/, exe/ — executables
- Gemfile — gems and versions

## Troubleshooting

- If a gem install fails, ensure you have system dependencies (e.g., libpq-dev for PostgreSQL).
- Check `Gemfile` for required versions.
- If the DB connection fails, verify credentials in `config/database.yml` or `.env`.

<!-- End of README -->
