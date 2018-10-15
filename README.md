# Welcome to Ruby 2D!

[![Gem](https://img.shields.io/gem/v/ruby2d.svg)](https://rubygems.org/gems/ruby2d) [![Build Status](https://travis-ci.org/ruby2d/ruby2d.svg?branch=master)](https://travis-ci.org/ruby2d/ruby2d) [![Gitter](https://badges.gitter.im/ruby2d/ruby2d.svg)](https://gitter.im/ruby2d/ruby2d)

This is the [Ruby 2D gem](https://rubygems.org/gems/ruby2d). Check out the [Ruby 2D website](http://www.ruby2d.com) to learn how to get started building 2D apps in Ruby.

## Development

To work on the gem locally, first clone this repo using:

```bash
git clone --recursive https://github.com/ruby2d/ruby2d.git
```

To keep the size of this repository small, [Git submodules](https://git-scm.com/book/en/Git-Tools-Submodules) are used to reference [test media](https://github.com/simple2d/test_media) and other [assets](https://github.com/ruby2d/assets). The `--recursive` flag ensures submodules are initialized and updated when this repo is cloned. If you happened to clone this repo without the `--recursive` flag, you can still initialize and update submodules with:

```bash
git submodule init
git submodule update --remote
```

Update these submodules at any time using `git submodule update --remote` or the `rake update` task.

Next, install dependencies:
- With [Bundler](http://bundler.io), run `bundle install` to get the required development gems.
- Install the native graphics library [Simple 2D](https://github.com/simple2d/simple2d) by following the instructions in its README.
- Install [MRuby](http://mruby.org) in order to build Ruby 2D apps natively. On macOS using [Homebrew](https://brew.sh), run `brew install mruby`. On Linux, use `sudo apt install mruby libmruby-dev`

Finally, run `rake` to build and install the gem locally.

## Tests

Ruby 2D uses a combination of automated tests via [RSpec](http://rspec.info) and manual, interactive tests to verify the correctness of visual, audio, and input functionality. Build the gem and run all automated tests using the `rake` command. Build and run an interactive test in the [`test/`](test/) directory using `rake test:<environment> <name_of_test>`, for example:

```bash
# Run `test/testcard.rb` using the standard Ruby interpreter, MRI (CRuby)
rake test:int testcard

# Build `test/audio.rb` natively using MRuby and run
rake test:native audio

# Build `test/mouse.rb` for the web using WebAssembly and run in the default browser
rake test:web mouse
```

## Contribute

Ruby 2D is an entirely open-source project (including its dependencies) built by dedicated folks who believe creating 2D applications should be simple, natural, and joyful, in the spirit of the [Ruby language](https://www.ruby-lang.org/en/about) itself.

If you'd like to get involved, there are a number of ways to do so:

- **Suggest and implement new features.** 🌟 Ruby 2D is still early in development, so there are plenty of new things it could do. If you have a feature request, or a suggestion on how to improve the domain-specific language, or something else to add, remove, or change, [open a new issue](https://github.com/ruby2d/ruby2d/issues/new) and tell us about it. If you just want to casually talk through an idea without the pressure of opening an issue, send a note to the [mailing list](https://groups.google.com/d/forum/ruby2d) or chat with us on [Gitter](https://gitter.im/ruby2d/ruby2d).

- **Add support for more platforms.** 💻 Ruby 2D aims to be entirely cross platform. Take a look at the [platforms we currently support](http://www.ruby2d.com/platforms) and where the gaps are. Help us test and improve the developer experience on existing platforms and add new ones.

- **Find and fix issues.** 🐛 Any new project experiencing lots of change will have bugs. Your help identifying and fixing them, and improving performance along the way, will be critical to ensuring others have a solid experience using the library. Check out the [issue tracker](https://github.com/ruby2d/ruby2d/issues) and have at it!

- **Write and review documentation.** 📚 Vitally important to the success of every open-source project is documentation. We're off to a decent start here, but there's always more to write and edit. Browse through the [Ruby 2D website](http://www.ruby2d.com) and help us identify areas to add clarity or fill in gaps. At the bottom of every page, you'll see a link to "improve this page" which goes directly to the source file in the [website repo](https://github.com/ruby2d/ruby2d.com), making it easy to suggest changes.

- **Create and improve examples.** 👾 We're currently a little light on sample applications to help folks get started. We'd love to get your ideas on small, single-file apps to guide users through specific features or techniques, which we'll collect in the [examples repository](https://github.com/ruby2d/examples). If you've got larger projects you'd like to highlight, we'd love to hear about them as well! Maybe we can add a gallery page to the website and showcase them... 🤔

### Technical contributions

In order to achieve such simplicity, a lot has to happen under the hood. We recommend reviewing Ruby 2D's [technical architecture](http://www.ruby2d.com/learn/tech) for a high-level overview of how everything is put together.

Whether adding a feature or fixing a bug, try to do the following to ensure your pull request gets merged. Some of these might seem daunting, but we're happy to help along the way!

- **Check if there is an existing issue, and if not, open a new one to start a discussion.** Before dedicating time and energy to an idea or fix, let's make sure it's consistent with the principles and goals of the project, and that we have a solid strategy in place to implement and test.

- **Use a subset of Ruby that works everywhere.** Ruby 2D applications are, of course, written in Ruby. Some users may choose to harness the full power of the language, standard library, and ecosystem of gems by writing interpreted apps targeting the standard implementation, [MRI](https://en.wikipedia.org/wiki/Ruby_MRI). Others may want to target the web via [WebAssembly](https://webassembly.org), so their app can be run in any browser. And others still may want to compile their app to native code via [MRuby](http://mruby.org), so they can embed it on platforms like the [Raspberry Pi](https://www.raspberrypi.org), or run it on mobile platforms like iOS and Android, or on the big screen with Apple TV or Amazon Fire TV. Or even further, some may want to do all three! Ruby 2D aims to support all of these use cases, even with the same app codebase. Your code contribution to this gem has to support a subset of Ruby that is compatible and behaves similarly across MRI and MRuby. Beyond reading the documentation for each Ruby implementation, you can also try out code snippets on the command line using their respective REPLs: `irb` (MRI) and `mirb` (MRuby).

- **Comprehensively test your change.** Unlike other Ruby libraries, not everything here can be easily covered with unit tests alone. We also need to make sure things look and sound right, inputs work as expected, and behavior is consistent across all [platforms Ruby 2D supports](http://www.ruby2d.com/platforms).

## Preparing a release

1. Update the Simple 2D minimum version required in [`extconf.rb`](ext/ruby2d/extconf.rb)
2. Run tests on all supported platforms
3. Update the version number in [`version.rb`](lib/ruby2d/version.rb), commit changes
4. Create a [new release](https://github.com/ruby2d/ruby2d/releases) in GitHub, with tag in the form `v#.#.#`
5. Run `rake` to build the gem, then push it to [rubygems.org](https://rubygems.org) with `gem push ruby2d-#.#.#.gem`
6. 🎉
