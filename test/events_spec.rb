require 'ruby2d'

RSpec.describe Window do
  [:key, :key_down, :key_held, :key_up].each do |key_event_type|
    describe "on #{key_event_type}" do
      it "allows binding of event" do
        window = Ruby2D::Window.new
        value = 0
        window.on(key_event_type) do
          value += 1
        end
        callback_event_name = key_event_type.to_s.gsub("key_", "").to_sym
        window.key_callback(callback_event_name, "example_key")
        expect(value).to eq 1
      end

      it "allows binding of multiple events" do
        window = Ruby2D::Window.new
        value = 0
        window.on(key_event_type) do
          value += 1
        end
        window.on(key_event_type) do
          value += 2
        end
        callback_event_name = key_event_type.to_s.gsub("key_", "").to_sym
        window.key_callback(callback_event_name, "example_key")
        expect(value).to eq 3
      end

      it "returns value, which can be used to unbind event" do
        window = Ruby2D::Window.new
        value = 0
        event_descriptor = window.on(key_event_type) do
          value += 1
        end
        window.off(event_descriptor)
        callback_event_name = key_event_type.to_s.gsub("key_", "").to_sym
        window.key_callback(callback_event_name, "example_key")
        expect(value).to eq 0
      end
    end
  end

  [:mouse, :mouse_up, :mouse_down, :mouse_scroll, :mouse_move].each do |key_event_type|
    describe "on #{key_event_type}" do
      it "allows binding of event" do
        window = Ruby2D::Window.new
        value = 0
        window.on(key_event_type) do
          value += 1
        end
        callback_event_name = key_event_type.to_s.gsub("mouse_", "").to_sym
        window.mouse_callback(callback_event_name, nil, nil, 0, 0, 0, 0)
        expect(value).to eq 1
      end

      it "allows binding of multiple events" do
        window = Ruby2D::Window.new
        value = 0
        window.on(key_event_type) do
          value += 1
        end
        window.on(key_event_type) do
          value += 2
        end
        callback_event_name = key_event_type.to_s.gsub("mouse_", "").to_sym
        window.mouse_callback(callback_event_name, nil, nil, 0, 0, 0, 0)
        expect(value).to eq 3
      end

      it "returns value, which can be used to unbind event" do
        window = Ruby2D::Window.new
        value = 0
        event_descriptor = window.on(key_event_type) do
          value += 1
        end
        window.off(event_descriptor)
        callback_event_name = key_event_type.to_s.gsub("mouse_", "").to_sym
        window.mouse_callback(callback_event_name, nil, nil, 0, 0, 0, 0)
        expect(value).to eq 0
      end
    end
  end

  [:controller, :controller_axis, :controller_button_up, :controller_button_down].each do |key_event_type|
    describe "on #{key_event_type}" do
      it "allows binding of event" do
        window = Ruby2D::Window.new
        value = 0
        window.on(key_event_type) do
          value += 1
        end
        callback_event_name = key_event_type.to_s.gsub("controller_", "").to_sym
        window.controller_callback(nil, callback_event_name, nil, nil, nil)
        expect(value).to eq 1
      end

      it "allows binding of multiple events" do
        window = Ruby2D::Window.new
        value = 0
        window.on(key_event_type) do
          value += 1
        end
        window.on(key_event_type) do
          value += 2
        end
        callback_event_name = key_event_type.to_s.gsub("controller_", "").to_sym
        window.controller_callback(nil, callback_event_name, nil, nil, nil)
        expect(value).to eq 3
      end

      it "returns value, which can be used to unbind event" do
        window = Ruby2D::Window.new
        value = 0
        event_descriptor = window.on(key_event_type) do
          value += 1
        end
        window.off(event_descriptor)
        callback_event_name = key_event_type.to_s.gsub("controller_", "").to_sym
        window.controller_callback(nil, callback_event_name, nil, nil, nil)
        expect(value).to eq 0
      end
    end
  end
end
