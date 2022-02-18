# Set the OS and platform

case RUBY_PLATFORM
when /darwin/
  $RUBY2D_PLATFORM = :macos
when /linux/
  $RUBY2D_PLATFORM = :linux
  if `cat /etc/os-release` =~ /raspbian/
    $RUBY2D_PLATFORM = :linux_rpi
  end
when /bsd/
  $RUBY2D_PLATFORM = :bsd
when /mingw/
  $RUBY2D_PLATFORM = :windows
else
  $RUBY2D_PLATFORM = nil
end
