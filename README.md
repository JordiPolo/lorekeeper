# Lorekeeper

[![Build Status](https://travis-ci.org/JordiPolo/lorekeeper.svg?branch=master)](https://travis-ci.org/JordiPolo/lorekeeper)

LoreKeeper contains a highly optimized JSON logger. It outputs messages as JSON and let the users to add their own customized fields.
When used without extra fields it outputs 20% faster than the standard Logger for messages not longer than one line of text.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'lorekeeper', '~> 1.7'
```

And then execute:

```sh
bundle
```


## Usage

### Normal logging methods

[LoreKeeper::JSONLogger](./lib/lorekeeper/json_logger.rb) API is compatible with the stdlib's Logger's.

```ruby
logger.error("This is a message")
```

Will output:
```
{
  "message": "This is a message",
  "timestamp": "1970-01-01T00:00:00.000+0100",
  "level": "debug"
}
```

Timestamps use ISO8601.
Messages are JSON escaped so the total result is JSON parseable.


### Log Levels

| Method Name | JSON Property          |
| ----------- | ---------------------- |
| debug       | "level": "debug"       |
| info        | "level": "info"        |
| warn        | **"level": "warning"** |
| error       | "level": "error"       |
| fatal       | "level": "fatal"       |


### Adding keys to the output

Keys can be added to the output at any moment.
These keys will be output in each message till they are removed again.
If you want to output keys in only one message use the `*_with_data` method instead.

Keys can be added using the `add_fields` method which accepts a hash:

```ruby
logger.add_fields("role" => "backend")
logger.error("This is a message")
logger.warn("This is another message")
```

Will output:
```javascript
{
  "message": "This is a message",
  "timestamp": "1970-01-01T00:00:00.000+0100",
  "level": "error",
  "role": "backend"
}
{
  "message": "This is another message",
  "timestamp": "1970-01-01T00:00:00.000+0100",
  "level": "warning",
  "role": "backend"
}
```

Because of speed purposes the JSON dumping is done as simply as possible. If you provide a hash of keys like:
```ruby
{ key: 'value' }
```
The output will include:
```javascript
{ ":key": "value" }
```


### Logging methods with data

All methods (info, debug, etc.) have a `*_with_data` equivalent: `info_with_data`, `debug_with_data`, etc.
These methods accept and extra hash to add it to the JSON.

```ruby
logger.error_with_data('message', { data1: 'Extra data', data2: 'Extra data2' })
```

Will output:
```javascript
{
  "message": "This is a message",
  "timestamp": "1970-01-01T00:00:00.000+0100",
  "level": "debug",
  "data": {
    "data1": "Extra data",
    "data2": "Extra data2"
  }
}
```


### Logging exceptions

There is a method to help you log exceptions in an standard way.

```ruby
rescue => e
  logger.exception(e)
end
```

Will output:
```javascript
{
  "message": "#{e.message}",
  "timestamp": "1970-01-01T00:00:00.000+0100",
  "level": "error",
  "exception": "<exception name>",
  "stack": [
    "<stacktraceline1>",
    "<stacktraceline2>"
  ]
}
```

This method also accepts a custom message, data and log level.

```ruby
rescue => e
  logger.exception(e, "custom msg!", { some: { data: 123 } }, :warn)
end
```

Will output:

```javascript
{
  "message": "custom msg!",
  "timestamp": "1970-01-01T00:00:00.000+0100",
  "level": "warning",
  "data": {
    ":some": {
      ":data": 123
    }
  },
  "exception": "<exception name>",
  "stack": [
    "<stacktraceline1>",
    "<stacktraceline2>"
  ]
}
```

Alternatively you can use named parameters:


```ruby
rescue => e
  logger.exception(e, message: "custom msg!", data: { some: { data: 123 } }, level: :warn)
end
```

This is specially useful when there is no custom message or data:

```ruby
rescue => e
  logger.exception(e, level: :warn)
end
```



## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
