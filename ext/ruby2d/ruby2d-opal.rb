# ruby2d-opal.rb

$SELF = nil

`
// ruby2d.js

// @type_id values for rendering
const $R2D_TRIANGLE = 1;
const $R2D_QUAD     = 2;
const $R2D_IMAGE    = 3;
const $R2D_SPRITE   = 4;
const $R2D_TEXT     = 5;

function update() {
  #{$SELF.mouse_x = `win.mouse.x`};
  #{$SELF.mouse_y = `win.mouse.y`};
  #{$SELF.update_callback};
}

function render() {
  
  var objects = #{$SELF.objects};
  
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
      
      case $R2D_IMAGE:
        if (el.data == Opal.nil) {
          el.data = S2D.CreateImage(el.path);
        }
        
        el.data.x = el.x;
        el.data.y = el.y;
        
        if (el.width  != Opal.nil) el.data.width  = el.width;
        if (el.height != Opal.nil) el.data.height = el.height;
        
        S2D.DrawImage(el.data);
        break;
      
      case $R2D_SPRITE:
        /*
        if (el.data == Opal.nil) {
          el.data = S2D.CreateSprite(el.path);
        }
        
        el.data.x = el.x;
        el.data.y = el.y;
        
        S2D.DrawSprite(el.data);
        */
        break;
      
      case $R2D_TEXT:
        /*
        if (el.data == Opal.nil) {
          el.data = S2D.CreateText(el.font, el.text, el.size);
        }
        
        el.data.x = el.x;
        el.data.y = el.y;
        
        S2D_SetText(el.data, el.text);
        
        S2D.DrawText(el.data);
        */
        break;
    }
    
  }
}
`

module Ruby2D
  class Window
    def show
      $SELF = self
      
      if $SELF.diagnostics
        # `S2D.Diagnostics(true);`
      end
      
      `win = S2D.CreateWindow(
        #{$SELF.title}, #{$SELF.width}, #{$SELF.height}, update, render, "ruby2d-app", {}
      );`
      
      # TODO: Read flags, viewport w/h
      # `
      # win.viewport.width  = #{$SELF.viewport_width};
      # win.viewport.height = #{$SELF.viewport_height};
      # win.on_key          = on_key;
      # win.on_mouse        = on_mouse;
      # win.on_controller   = on_controller;
      # `
      
      `S2D.Show(win);`
    end
  end
end
