# Skip tests that error on CI

SKIP_CI_LINUX = false
SKIP_CI_WINDOWS_LINUX = false

if ENV['CI']
  if ENV['RUNNER_OS'] == 'Linux'
    SKIP_CI_LINUX = true
  end

  if ENV['RUNNER_OS'] == 'Linux' ||
     ENV['RUNNER_OS'] == 'Windows'
    SKIP_CI_WINDOWS_LINUX = true
  end
end
