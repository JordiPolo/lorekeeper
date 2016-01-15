# Lorekeeper

[![Build Status](https://travis-ci.org/JordiPolo/lorekeeper.svg?branch=master)](https://travis-ci.org/JordiPolo/lorekeeper)

LoreKeeper contains a highly optimized JSON logger. It outputs messages as JSON and let the users to add their own customized fields.
When used without extra fields it outputs 20% faster than the standard Logger for messages not longer than one line of text.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'lorekeeper'
```

And then execute:

    $ bundle


## Usage

### Normal logging methods

LoreKeeper::JSONLogger API is compatible with standard lib's Logger's. Level is not showed in the output.

```Ruby
logger.error("This is a message")
```

Will output:
```
{ "message": "This is a message", "timestamp": "1970-01-01T00:00:00.000+0100" }
```

Timestamps use ISO8601
Messages are json escaped so the total result is JSON parseable.


### Adding keys to the output

Keys can be added to the output at any moment. These keys will be output in each message till they are removed again. If you want to output keys in only one message use the _with_data method instead.

Keys can be added using the `add_fields` method which accepts a hash:

```Ruby
logger.add_fields( 'role' => 'backend' )
logger.error("This is a message")
logger.warning("This is another message")
```

Will output:
```json
{ "message": "This is a message", "timestamp": "1970-01-01T00:00:00.000+0100", "role": "backend" }
{ "message": "This is another message", "timestamp": "1970-01-01T00:00:00.000+0100", "role": "backend" }
```

Because of speed purposes the JSON dumping is done as simply as possible. If you provide a hash of keys like:
```ruby
{ key: 'value' }
```
The output will include:
```json
{ ":key": "value" }
```


### Logging methods with data

All methods (info, debug, etc.) has a _with_data equivalent: "info_with_data", "debug_with_data".
These methods accept and extra hash to add it to the JSON.

```Ruby
logger.error_with_data('message', {data1: 'Extra data', data2: 'Extra data2'})
```

Will output:
```json
{ "message": "This is a message", "timestamp": "1970-01-01T00:00:00.000+0100", "data": {"data1": "Extra data", "data2": "Extra data2"} }
```


### Logging exceptions

There is a method to help you log exceptions in an standard way.

```Ruby
rescue StandardError => e
  logger.exception(e)
```

Will output:
```json
{ "message": "#{e.message}", "timestamp": "1970-01-01T00:00:00.000+0100", "exception": "<exception name>", "stack": ["<stacktraceline1>", "<stacktraceline2>"] }
```


## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/lorekeeper.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

