# Welcome to Ruby 2D!

This is the Ruby 2D gem. [Check out the website](http://www.ruby2d.com) for help getting started, documentation, news, and more.

## Running Tests

### Getting the Test Media

To keep the size of this repository small, media needed for tests are checked into the Simple 2D [`test_media`](https://github.com/simple2d/test_media) repo and referenced as a [Git submodule](http://git-scm.com/book/en/v2/Git-Tools-Submodules). After cloning this repo, init the submodule and get its contents by using:

```bash
git submodule init
git submodule update --remote
```

Alternatively, you can clone the repo and update the submodule in one step:

```bash
git clone --recursive https://github.com/ruby2d/ruby2d.git
```

Simply run `git submodule update --remote` anytime to get the latest changes from `test_media` (i.e. when there's a new commit available).

### Available Tests

The current tests available are:

- [`testcard.rb`](tests/testcard.rb) – A graphical card, similar to [testcards from TV](http://en.wikipedia.org/wiki/Testcard), with the goal of making sure all visual and inputs are working properly.

Run a test using `rake <name_of_test>`, for example:

```bash
rake testcard
```
