# Welcome to Ruby 2D!

This is the [Ruby 2D gem](https://rubygems.org/gems/ruby2d). Check out the [website](http://www.ruby2d.com) for help getting started, documentation, news, and more. See where we're headed in the [roadmap](http://www.ruby2d.com/roadmap) and learn about [contributing](http://www.ruby2d.com/contribute). If you encounter any issues, ping the [mailing list](https://groups.google.com/d/forum/ruby2d).

## Development

To work on the gem locally, first clone this repo with the test media [Git submodule](http://git-scm.com/book/en/v2/Git-Tools-Submodules):

```bash
git clone --recursive https://github.com/ruby2d/ruby2d.git
```

Along with cloning this repo, the above will grab the contents of the [`test_media`](https://github.com/simple2d/test_media) repo and place it in the `tests/media` directory. Simply run `git submodule update --remote` anytime to get the latest changes from `test_media` (i.e. when there's a new commit available). If you've already cloned this repo without the `--recursive` flag, make sure to run `git submodule init` before updating the submodule.

Next, install [Bundler](http://bundler.io) and run `bundle install` to get the required development gems.

Finally, install Simple 2D by following the instructions in the [README](https://github.com/simple2d/simple2d).

## Tests

Ruby 2D uses a combination of automated tests via [RSpec](http://rspec.info) and manual, interactive tests to verify visual, audio, and input functionality. Build the gem and run all automated tests with `rake`. Run other tests using `rake <name_of_test>`, such as `rake testcard`. Run `rake -T` to see a list of all available tests.

## Preparing a Release

1. Update the minimum Simple 2D version required in [extconf.rb](ext/ruby2d/extconf.rb)
2. Run tests on all supported platforms
3. Update the version number in [`version.rb`](lib/ruby2d/version.rb), commit changes
4. Create a [new release](https://github.com/ruby2d/ruby2d/releases) in GitHub, with tag in the form `v#.#.#`
5. Push to [rubygems.org](rubygems.org) with `gem push ruby2d-#.#.#.gem`
