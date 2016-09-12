# 1.4.1
* Change array creation syntax to support Ruby 1.9

# 1.4.0
* Adds '_with_data' to the simple logger so we can display data in the terminal
* Adds 'respond_to?' to the multilogger so users can check capabilities of the loggers

# 1.3.1
* Loggers provide an inspect method to avoid being too noisy on outputs

# 1.3.0
* Time in the JSON output specifies microseconds.
* Using 'Z' to specify the UTC timezone instead of +0000 as per ISO 8601.
* Debug and Info messages use the default foreground color of the terminal.

# 1.2.1
* If a file does not exist, it will create it on behalf of the application

# 1.2
* Added a silence_logger method to the logger. For compatibility with activerecord-session and maybe other gems.

# 1.1.1
* Avoid syntax errors in rubies < 2.3

# 1.1.0
* Added an 'add' method to the logger so it is compatible with the Logger provided by Ruby's standard library

# 1.0.0
* Initial release
