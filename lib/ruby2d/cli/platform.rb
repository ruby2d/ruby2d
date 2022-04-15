# Set the OS and platform

case
when RUBY_PLATFORM.include?('darwin')
  $RUBY2D_PLATFORM = :macos
when RUBY_PLATFORM.include?('mingw')
  $RUBY2D_PLATFORM = :windows
when RUBY_PLATFORM.include?('linux')
  $RUBY2D_PLATFORM = :linux
  if `cat /etc/os-release`.include?('raspbian')
    $RUBY2D_PLATFORM = :linux_rpi
  end
when RUBY_PLATFORM.include?('bsd')
  $RUBY2D_PLATFORM = :bsd
when RUBY_PLATFORM.include?('wasm')
  $RUBY2D_PLATFORM = :wasm
else
  $RUBY2D_PLATFORM = nil
end
