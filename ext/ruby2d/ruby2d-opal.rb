# ruby2d-opal.rb

# Ruby 2D window
$R2D_WINDOW = nil

# Simple 2D window
`var win;`


`// ruby2d.js

// @type_id values for rendering
const $R2D_TRIANGLE = 1;
const $R2D_QUAD     = 2;
const $R2D_LINE     = 3;
const $R2D_IMAGE    = 4;
const $R2D_SPRITE   = 5;
const $R2D_TEXT     = 6;


function on_key(e) {

  switch (e.type) {
    case S2D.KEY_DOWN:
      #{type = :down};
      break;
    case S2D.KEY_HELD:
      #{type = :held};
      break;
    case S2D.KEY_UP:
      #{type = :up};
      break;
  }

  #{$R2D_WINDOW.key_callback(type, `e.key`)};
}


function on_mouse(e) {

  #{direction = nil}
  #{button    = nil}

  switch (e.type) {
    case S2D.MOUSE_DOWN:
      #{type = :down};
      break;
    case S2D.MOUSE_UP:
      #{type = :up};
      break;
    case S2D.MOUSE_SCROLL:
      #{type = :scroll};
      #{direction} = e.direction == S2D.MOUSE_SCROLL_NORMAL ? #{:normal} : #{:inverted};
      break;
    case S2D.MOUSE_MOVE:
      #{type = :move};
      break;
  }

  if (e.type == S2D.MOUSE_DOWN || e.type == S2D.MOUSE_UP) {
    switch (e.button) {
      case S2D.MOUSE_LEFT:
        #{button = :left};
        break;
      case S2D.MOUSE_MIDDLE:
        #{button = :middle};
        break;
      case S2D.MOUSE_RIGHT:
        #{button = :right};
        break;
      case S2D.MOUSE_X1:
        #{button = :x1};
        break;
      case S2D.MOUSE_X2:
        #{button = :x2};
        break;
    }
  }

  #{$R2D_WINDOW.mouse_callback(
    type, button, direction,
    `e.x`, `e.y`, `e.delta_x`, `e.delta_y`
  )};
}


function update() {
  #{$R2D_WINDOW.mouse_x = `win.mouse.x`};
  #{$R2D_WINDOW.mouse_y = `win.mouse.y`};
  #{$R2D_WINDOW.frames  = `win.frames`};
  #{$R2D_WINDOW.fps     = `win.fps`};
  #{$R2D_WINDOW.update_callback};
}


function render() {

  // Set background color
  win.background.r = #{$R2D_WINDOW.get(:background).r};
  win.background.g = #{$R2D_WINDOW.get(:background).g};
  win.background.b = #{$R2D_WINDOW.get(:background).b};
  win.background.a = #{$R2D_WINDOW.get(:background).a};

  var objects = #{$R2D_WINDOW.objects};

  for (var i = 0; i < objects.length; i++) {

    var el = objects[i];

    switch (el.type_id) {

      case $R2D_TRIANGLE:

        S2D.DrawTriangle(
          el.x1, el.y1, el.c1.r, el.c1.g, el.c1.b, el.c1.a,
          el.x2, el.y2, el.c2.r, el.c2.g, el.c2.b, el.c2.a,
          el.x3, el.y3, el.c3.r, el.c3.g, el.c3.b, el.c3.a
        );
        break;

      case $R2D_QUAD:
        S2D.DrawQuad(
          el.x1, el.y1, el.c1.r, el.c1.g, el.c1.b, el.c1.a,
          el.x2, el.y2, el.c2.r, el.c2.g, el.c2.b, el.c2.a,
          el.x3, el.y3, el.c3.r, el.c3.g, el.c3.b, el.c3.a,
          el.x4, el.y4, el.c4.r, el.c4.g, el.c4.b, el.c4.a
        );
        break;

      case $R2D_LINE:
        S2D.DrawLine(
          el.x1, el.y1, el.x2, el.y2, el.width,
          el.c1.r, el.c1.g, el.c1.b, el.c1.a,
          el.c2.r, el.c2.g, el.c2.b, el.c2.a,
          el.c3.r, el.c3.g, el.c3.b, el.c3.a,
          el.c4.r, el.c4.g, el.c4.b, el.c4.a
        );
        break;

      case $R2D_IMAGE:
        el.data.x = el.x;
        el.data.y = el.y;

        if (el.width  != Opal.nil) el.data.width  = el.width;
        if (el.height != Opal.nil) el.data.height = el.height;

        el.data.color.r = el.color.r;
        el.data.color.g = el.color.g;
        el.data.color.b = el.color.b;
        el.data.color.a = el.color.a;

        S2D.DrawImage(el.data);
        break;

      case $R2D_SPRITE:
        el.data.x = el.x;
        el.data.y = el.y;

        S2D.ClipSprite(
          el.data,
          el.clip_x,
          el.clip_y,
          el.clip_w,
          el.clip_h
        );

        S2D.DrawSprite(el.data);
        break;

      case $R2D_TEXT:
        el.data.x = el.x;
        el.data.y = el.y;

        el.data.color.r = el.color.r;
        el.data.color.g = el.color.g;
        el.data.color.b = el.color.b;
        el.data.color.a = el.color.a;

        S2D.DrawText(el.data);
        break;
    }

  }
}`


module Ruby2D
  class Image
    def ext_image_init(path)
      `#{self}.data = S2D.CreateImage(path, function() {
        if (#{@width} == Opal.nil) {
          #{@width} = #{self}.data.width;
        }
        if (#{@height} == Opal.nil) {
          #{@height} = #{self}.data.height;
        }
      });`
    end
  end

  class Sprite
    def ext_sprite_init(path)
      `#{self}.data = S2D.CreateSprite(path);`
    end
  end

  class Text
    def ext_text_init
      `#{self}.data = S2D.CreateText(#{self}.font, #{self}.text, #{self}.size);`
      @width  = `#{self}.data.width;`
      @height = `#{self}.data.height;`
    end

    def ext_text_set(msg)
      `S2D.SetText(#{self}.data, #{msg});`
      @width  = `#{self}.data.width;`
      @height = `#{self}.data.height;`
    end
  end

  class Sound
    def ext_sound_init(path)
      `#{self}.data = S2D.CreateSound(path);`
    end

    def ext_sound_play
      `S2D.PlaySound(#{self}.data);`
    end
  end

  class Music
    def ext_music_init(path)
      `#{self}.data = S2D.CreateMusic(path);`
    end

    def ext_music_play
      `S2D.PlayMusic(#{self}.data, #{self}.loop);`
    end

    def ext_music_pause
      `S2D.PauseMusic();`
    end

    def ext_music_resume
      `S2D.ResumeMusic();`
    end

    def ext_music_stop
      `S2D.StopMusic();`
    end

    def ext_music_fadeout(ms)
      `S2D.FadeOutMusic(ms);`
    end
  end

  class Window
    def ext_window_show
      $R2D_WINDOW = self

      `
      var width  = #{$R2D_WINDOW.get(:width)};
      var height = #{$R2D_WINDOW.get(:height)};

      var vp_w = #{$R2D_WINDOW.get(:viewport_width)};
      var viewport_width = vp_w != Opal.nil ? vp_w : width;

      var vp_h = #{$R2D_WINDOW.get(:viewport_height)};
      var viewport_height = vp_h != Opal.nil ? vp_h : height;

      win = S2D.CreateWindow(
        #{$R2D_WINDOW.get(:title)}, width, height, update, render, "ruby2d-app", {}
      );

      win.viewport.width  = viewport_width;
      win.viewport.height = viewport_height;
      win.on_key          = on_key;
      win.on_mouse        = on_mouse;

      S2D.Show(win);`
    end
  end
end
