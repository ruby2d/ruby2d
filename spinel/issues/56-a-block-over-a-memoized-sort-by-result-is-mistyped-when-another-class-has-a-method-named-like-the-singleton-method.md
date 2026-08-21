# [Compile] A block over a memoized `sort_by` result is mis-typed when another class defines a method named like the enclosing singleton method

Found while porting [Ruby 2D](https://github.com/ruby2d/ruby2d) to Spinel: `Font.path(name)` searches a memoized, sorted list of font files. It compiled until `Image`, which has a `path` attribute, joined the program — then `Font.path` stopped compiling, although nothing calls it.

## Description

`Font.path` iterates `@all_paths ||= files.sort_by { … }` with `find { |path| path.include?(name) }`. The generated C declares the block parameter as `const char *` (the element type) but emits the `include?` call as a poly dispatch over `sp_RbVal`, so the C compiler rejects the initialization:

```
error: initializing 'sp_RbVal' with an expression of incompatible type 'const char *'
```

Three things have to hold at once: the list is memoized in an ivar (`||=`); it comes from `sort_by` on a method's result; and some other class defines an instance method with the same name as the singleton method that searches the list (`Img#path` vs `Font.path`). Drop any one and the program compiles. Whether `Font.path` is ever called makes no difference.

A singleton lookup named after the thing it returns (`Font.path`, `Color.set`) and an unrelated class with an attribute of that name are both ordinary; a program that has both should compile.

## Reproduction

```ruby
class Img
  attr_reader :path

  def initialize(p)
    @path = p
  end
end

class Font
  class << self
    def path(font_name)
      all_paths.find { |path| path.include?(font_name) }
    end

    def all_paths
      @all_paths ||= files.sort_by { |f| f.downcase }
    end

    def files
      ['fonts/beta.ttf', 'fonts/alpha.ttf']
    end
  end
end

puts Img.new('x.png').path
```

**Ruby 4.0.6:**
```
x.png
```

**Spinel (2aed9817):**
```
a.rb:16:21: error: initializing 'sp_RbVal' with an expression of incompatible type 'const char *'
   16 |     if (({ sp_RbVal _t4 = lv_path; SP_GC_ROOT_RBVAL(_t4); … switch (_t4.cls_id) { … } _t5; })) { _t3 = lv_path; break; }
      |                     ^     ~~~~~~~
1 error generated.
spinel: C compilation failed
```

## Additional Findings

| Variant | Result |
|---|---|
| As above | **C compilation fails** |
| `Font.path` renamed to `Font.lookup` | compiles |
| `Img#path` renamed to `Img#file` | compiles |
| `Img#path` as a plain `def path` (not `attr_reader`), or taking an argument | fails |
| `files.sort_by { … }` without the `@all_paths ||=` memo | compiles |
| `sort_by` replaced by `map` or `select` (memo kept) | compiles |
| `sort_by` replaced by block-less `sort` | compiles |
| `['…', '…'].sort_by { … }` (array literal instead of the `files` call) | compiles |
| `Font.path('alpha')` also called from the program | fails the same way |
| `def self.path` … instead of `class << self` | fails the same way |

## Environment

- Spinel commit: `2aed9817`
- Ruby version: 4.0.6
- Platform: macOS 26 (arm64), Apple clang 21
