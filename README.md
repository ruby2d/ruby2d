# Welcome to Ruby 2D!

[![Gem](https://img.shields.io/gem/v/ruby2d.svg?maxAge=2592000)](https://rubygems.org/gems/ruby2d) [![Build Status](https://travis-ci.org/ruby2d/ruby2d.svg?branch=master)](https://travis-ci.org/ruby2d/ruby2d) [![Gitter](https://badges.gitter.im/ruby2d/ruby2d.svg)](https://gitter.im/ruby2d/ruby2d)

This is the [Ruby 2D gem](https://rubygems.org/gems/ruby2d). Check out the [website](http://www.ruby2d.com) for all things getting started, documentation, news, and more. The [roadmap](http://www.ruby2d.com/roadmap) will show you where we're headed, and if you're interested in getting involved in development, read the [contributor's guide](http://www.ruby2d.com/contribute). If you encounter any issues, [chat with us](https://gitter.im/ruby2d/ruby2d), send a note to the [mailing list](https://groups.google.com/d/forum/ruby2d), or open an issue. Enjoy!

## Development

To work on the gem locally, first clone this repo with the test media [Git submodule](http://git-scm.com/book/en/v2/Git-Tools-Submodules):

```bash
git clone --recursive https://github.com/ruby2d/ruby2d.git
```

Along with cloning this repo, the command above will grab the contents of the [`test_media`](https://github.com/simple2d/test_media) repo and place it in the `tests/media` directory. Simply run `git submodule update --remote` anytime to get the latest changes from `test_media` (i.e. when there's a new commit available). If you've already cloned this repo without the `--recursive` flag, make sure to run `git submodule init` before updating the submodule.

Next, install [Bundler](http://bundler.io) and run `bundle install` to get the required development gems.

Finally, install Simple 2D by following the instructions in its [README](https://github.com/simple2d/simple2d).

## Tests

Ruby 2D uses a combination of automated tests via [RSpec](http://rspec.info) and manual, interactive tests to verify the correctness of visual, audio, and input functionality. Build the gem and run all automated tests with the `rake` command. Run other tests using `rake <name_of_test>`, such as `rake testcard`. Use `rake -T` to see a list of all available tests.

## Preparing a Release

1. Update the Simple 2D minimum version required in [extconf.rb](ext/ruby2d/extconf.rb)
2. Run tests on all supported platforms
3. Update the version number in [`version.rb`](lib/ruby2d/version.rb), commit changes
4. Create a [new release](https://github.com/ruby2d/ruby2d/releases) in GitHub, with tag in the form `v#.#.#`
5. Push to [rubygems.org](rubygems.org) with `gem push ruby2d-#.#.#.gem`
