# fluent-plugin-eval-filter, a plugin for [Fluentd](http://fluentd.org) [![Build Status](https://travis-ci.org/ephemeralsnow/fluent-plugin-eval-filter.png?branch=master)](https://travis-ci.org/ephemeralsnow/fluent-plugin-eval-filter) [![Code Climate](https://codeclimate.com/github/ephemeralsnow/fluent-plugin-eval-filter.png)](https://codeclimate.com/github/ephemeralsnow/fluent-plugin-eval-filter)

## Installation

Add this line to your application's Gemfile:

    gem 'fluent-plugin-eval-filter'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install fluent-plugin-eval-filter

## Usage

```
<match raw.apache.access>
  @type eval_filter
  remove_tag_prefix raw
  add_tag_prefix filtered

  <filter>
    config @hostname = `hostname -s`.chomp

    filter "[[tag, @hostname].join('.'), time, record] if record['method'] == 'GET'"
  </filter>
</match>
```

### require libraries
```
<match raw.apache.access>
  @type eval_filter
  remove_tag_prefix raw
  add_tag_prefix filtered
  requires yaml # comma separated values

  <filter>
    config @hostname = YAML.load({'hostname' => 'web01'})['hostname']

    filter "[[tag, @hostname].join('.'), time, record] if record['method'] == 'GET'"
  </filter>
</match>
```

## Filter Plugin

Note that this filter version does not have rewrite tag functionality.
Should return [time, record].

## Configuration


### filter:

    <filter **>
      @type eval
      <filter>
        filter "[time, record] if record['status'] == '404'"
      </filter>
      <filter>
        filter "[time, record] if record['status'] == 'POST'"
      </filter>
    </filter>


### typecast(string to integer):

    <filter **>
      @type eval
      <filter>
        filter "record['status'] = record['status'].to_i; [time, record]"
      </filter>
    </filter>

### modify record(add value):

    <filter **>
      @type eval
      <filter>
        filter "record['user_id'] = record['message'].split(':').last.to_i; [time, record]"
      </filter>
    </filter>

#### input
    {'status' => '301', 'message' => 'user_id:1'}
    {'status' => '302', 'message' => 'user_id:2'}
    {'status' => '404', 'message' => 'user_id:3'}
    {'status' => '503', 'message' => 'user_id:4'}
    {'status' => '401', 'message' => 'user_id:5'}

#### output
    {'status' => '301', 'message' => 'user_id:1', 'user_id' => 1}
    {'status' => '302', 'message' => 'user_id:2', 'user_id' => 2}
    {'status' => '404', 'message' => 'user_id:3', 'user_id' => 3}
    {'status' => '503', 'message' => 'user_id:4', 'user_id' => 4}
    {'status' => '401', 'message' => 'user_id:5', 'user_id' => 5}



## Limitation

Can not be used expression substitution.
```
<match raw.apache.access>
  @type eval_filter
  <filter>
    filter "#{tag}"
  </filter>
</match>
```

'#' Is interpreted as the beginning of a comment.
```
  filter #=> "\""
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
