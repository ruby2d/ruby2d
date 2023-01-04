# Skip tests that error on CI:
#   "(Mix_OpenAudio) WASAPI can't find requested audio endpoint: Element not found."
SKIP_CI = ENV['CI'] && ENV['RUNNER_OS'] == 'Windows'
