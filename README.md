# Welcome to Ruby 2D!

[![Gem](https://img.shields.io/gem/v/ruby2d.svg?color=%23f63c38&style=for-the-badge)](https://rubygems.org/gems/ruby2d) [![Build Status](https://img.shields.io/travis/com/ruby2d/ruby2d.svg?style=for-the-badge)](https://travis-ci.com/ruby2d/ruby2d) [![Discord](https://img.shields.io/discord/807786505434693632?style=for-the-badge)](https://discord.com/invite/QBWguEasV7)

This is the [Ruby 2D gem](https://rubygems.org/gems/ruby2d). Check out the [Ruby 2D website](http://www.ruby2d.com) to learn how to get started building 2D apps in Ruby.

## Development

To work on the gem locally, first clone this repo using:

```bash
git clone --recursive https://github.com/ruby2d/ruby2d.git
```

To keep the size of this source code repository small, [Git submodules](https://git-scm.com/book/en/Git-Tools-Submodules) are used to reference [assets](https://github.com/ruby2d/assets). The `--recursive` flag ensures submodules are initialized and updated when this repo is cloned. If you happened to clone this repo without the `--recursive` flag, you can still initialize and update submodules with:

```bash
git submodule init
git submodule update --remote
```

Update these submodules at any time using `git submodule update --remote` or the `rake update` task.

Next, install dependencies with [Bundler](http://bundler.io) by running `bundle install` to get the development gems.

Finally, run `rake` to build and install the gem locally. Use `rake dev` to build referencing user-installed libraries (e.g. SDL).

## Tests

Ruby 2D uses a combination of automated tests via [RSpec](http://rspec.info) and manual, interactive tests to verify the correctness of visual, audio, and input functionality. Build the gem and run all automated tests using the `rake` command. Build and run an interactive test in the [`test/`](test/) directory using `rake test:<target> <name_of_test>`, for example:

```bash
# Run `test/testcard.rb` using the standard Ruby interpreter, MRI (CRuby)
rake test:cruby testcard  # `test:mri` or just `test` work also

# Build `test/audio.rb` using mruby and run
rake test:mruby audio

# Build `test/mouse.rb` for the web using WebAssembly and run in the default browser
rake test:wasm mouse
```

## Contribute

Ruby 2D is an entirely open-source project (including its dependencies) built by dedicated folks who believe creating 2D applications should be simple, natural, and joyful, in the spirit of the [Ruby language](https://www.ruby-lang.org/en/about) itself.

If you'd like to get involved, there are a number of ways to do so:

- **Suggest and implement new features.** 🌟 Ruby 2D already does a lot, but there are plenty of new things it could do. If you have a feature request, or a suggestion on how to improve the domain-specific language, or something else to add, remove, or change, [open a new issue](https://github.com/ruby2d/ruby2d/issues/new) and tell us about it. If you just want to casually talk through an idea without the pressure of opening an issue, send a note to the [mailing list](https://groups.google.com/d/forum/ruby2d) or chat with us on [Gitter](https://gitter.im/ruby2d/ruby2d).

- **Add support for more platforms.** 💻 Ruby 2D aims to be entirely cross platform. Help us test and improve the developer experience on existing platforms and add new ones.

- **Find and fix issues.** 🐛 Your help identifying and fixing bugs, and improving performance along the way, will be critical to ensuring others have a solid experience using the library. Check out the [issue tracker](https://github.com/ruby2d/ruby2d/issues) and have at it!

- **Write and review documentation.** 📚 Vitally important to the success of every open-source project is documentation. We're off to a decent start, but there's always more to write and edit. Browse through the [Ruby 2D website](http://www.ruby2d.com) and help us identify areas to add clarity or fill in gaps. At the top of most pages, you'll see a link to "suggest an edit" which goes directly to the source file in the [website repo](https://github.com/ruby2d/ruby2d.com).

- **Create and improve examples.** 👾 We're currently a little light on sample applications to help folks get started. We'd love to get your ideas for small, single-file apps to guide users through specific features or techniques, which we collect in the [examples repository](https://github.com/ruby2d/examples). [Check out the showcase](http://www.ruby2d.com/showcase) to see what people are building and get some inspiration.

### Technical contributions

In order to achieve such simplicity, a lot has to happen under the hood. Whether adding a feature or fixing a bug, try to do the following to ensure your pull request gets merged. Some of these might seem daunting, but we're happy to help along the way!

- **Check if there is an existing issue, and if not, open a new one to start a discussion.** Before dedicating time and energy to an idea or fix, let's make sure it's consistent with the principles and goals of the project, and that we have a solid strategy in place to implement and test.

- **Use a subset of Ruby that works everywhere.** Ruby 2D applications are, of course, written in Ruby. Some users may choose to harness the full power of the language, standard library, and ecosystem of gems by writing interpreted apps targeting the standard implementation, [MRI](https://en.wikipedia.org/wiki/Ruby_MRI). Others may want to target the web via [WebAssembly](https://webassembly.org), mobile devices, or build native desktop applications, all which make use of a different Ruby implementation called [mruby](http://mruby.org). Ruby 2D aims to support all of these use cases, even with the same app codebase. Your contribution must support a subset of Ruby that is compatible with and behaves similarly across MRI/CRuby and mruby. Beyond reading the documentation for each Ruby implementation, you can also try out code snippets on the command line using their respective REPLs: `irb` for MRI, and `mirb` for mruby.

- **Comprehensively test your change.** Unlike other Ruby libraries, not everything here can be easily covered with unit tests alone. We also need to make sure things look and sound right, inputs work as expected, and behavior is consistent across all platforms Ruby 2D supports.

## Updating Ruby 2D

1. Update the [assets](https://github.com/ruby2d/assets) repo, follow the instructions in the README
2. Run `rake update` to update the submodules

## Preparing a release

1. Run tests on all supported platforms
2. Update the version number in [`version.rb`](lib/ruby2d/version.rb), commit changes
3. Create a [new release](https://github.com/ruby2d/ruby2d/releases) in GitHub, with tag in the form `v#.#.#`, and write a little release note
4. Run `rake release` to build the gem, then push it to [rubygems.org](https://rubygems.org) with `gem push ruby2d-#.#.#.gem`
5. 🎉
