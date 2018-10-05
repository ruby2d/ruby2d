# Web extension for Opal

# Ruby 2D window
$R2D_WINDOW = nil

# Simple 2D window
`
var win;

// ruby2d.js

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
    el['$ext_render']();
  }
}
`


module Ruby2D
  class Triangle
    def ext_render
      `S2D.DrawTriangle(
        #{self}.x1, #{self}.y1, #{self}.c1.r, #{self}.c1.g, #{self}.c1.b, #{self}.c1.a,
        #{self}.x2, #{self}.y2, #{self}.c2.r, #{self}.c2.g, #{self}.c2.b, #{self}.c2.a,
        #{self}.x3, #{self}.y3, #{self}.c3.r, #{self}.c3.g, #{self}.c3.b, #{self}.c3.a
      );`
    end
  end

  class Quad
    def ext_render
      `S2D.DrawQuad(
        #{self}.x1, #{self}.y1, #{self}.c1.r, #{self}.c1.g, #{self}.c1.b, #{self}.c1.a,
        #{self}.x2, #{self}.y2, #{self}.c2.r, #{self}.c2.g, #{self}.c2.b, #{self}.c2.a,
        #{self}.x3, #{self}.y3, #{self}.c3.r, #{self}.c3.g, #{self}.c3.b, #{self}.c3.a,
        #{self}.x4, #{self}.y4, #{self}.c4.r, #{self}.c4.g, #{self}.c4.b, #{self}.c4.a
      );`
    end
  end

  class Line
    def ext_render
      `S2D.DrawLine(
        #{self}.x1, #{self}.y1, #{self}.x2, #{self}.y2, #{self}.width,
        #{self}.c1.r, #{self}.c1.g, #{self}.c1.b, #{self}.c1.a,
        #{self}.c2.r, #{self}.c2.g, #{self}.c2.b, #{self}.c2.a,
        #{self}.c3.r, #{self}.c3.g, #{self}.c3.b, #{self}.c3.a,
        #{self}.c4.r, #{self}.c4.g, #{self}.c4.b, #{self}.c4.a
      );`
    end
  end

  class Image
    def ext_init(path)
      `
      #{self}.data = S2D.CreateImage(path, function() {
        if (#{@width} == Opal.nil) {
          #{@width} = #{self}.data.width;
        }
        if (#{@height} == Opal.nil) {
          #{@height} = #{self}.data.height;
        }
      });
      `
    end

    def ext_render
      `
      #{self}.data.x = #{self}.x;
      #{self}.data.y = #{self}.y;

      if (#{self}.width  != Opal.nil) #{self}.data.width  = #{self}.width;
      if (#{self}.height != Opal.nil) #{self}.data.height = #{self}.height;

      #{self}.data.color.r = #{self}.color.r;
      #{self}.data.color.g = #{self}.color.g;
      #{self}.data.color.b = #{self}.color.b;
      #{self}.data.color.a = #{self}.color.a;

      S2D.DrawImage(#{self}.data);
      `
    end
  end

  class Sprite
    def ext_init(path)
      `#{self}.data = S2D.CreateSprite(path);`
    end

    def ext_render
      `
      #{self}.data.x = #{self}.x;
      #{self}.data.y = #{self}.y;

      S2D.ClipSprite(
        #{self}.data,
        #{self}.clip_x,
        #{self}.clip_y,
        #{self}.clip_w,
        #{self}.clip_h
      );

      S2D.DrawSprite(#{self}.data);
      `
    end
  end

  class Text
    def ext_init
      `
      #{self}.data = S2D.CreateText(#{self}.font, #{self}.text, #{self}.size);
      #{@width}  = #{self}.data.width;
      #{@height} = #{self}.data.height;
      `
    end

    def ext_set(msg)
      `
      S2D.SetText(#{self}.data, #{msg});
      #{@width}  = #{self}.data.width;
      #{@height} = #{self}.data.height;
      `
    end

    def ext_render
      `
      #{self}.data.x = #{self}.x;
      #{self}.data.y = #{self}.y;

      #{self}.data.color.r = #{self}.color.r;
      #{self}.data.color.g = #{self}.color.g;
      #{self}.data.color.b = #{self}.color.b;
      #{self}.data.color.a = #{self}.color.a;

      S2D.DrawText(#{self}.data);
      `
    end
  end

  class Sound
    def ext_init(path)
      `#{self}.data = S2D.CreateSound(path);`
    end

    def ext_play
      `S2D.PlaySound(#{self}.data);`
    end
  end

  class Music
    def ext_init(path)
      `#{self}.data = S2D.CreateMusic(path);`
    end

    def ext_play
      `S2D.PlayMusic(#{self}.data, #{self}.loop);`
    end

    def ext_pause
      `S2D.PauseMusic();`
    end

    def ext_resume
      `S2D.ResumeMusic();`
    end

    def ext_stop
      `S2D.StopMusic();`
    end
    
    def ext_music_fadeout(ms)
      `S2D.FadeOutMusic(ms);`
    end
  end

  class Window
    def ext_show
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

      S2D.Show(win);
      `
    end
  end
end
