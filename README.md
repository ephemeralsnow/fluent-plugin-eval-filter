# fluent-plugin-eval-filter

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
  type eval_filter
  remove_tag_prefix raw
  add_tag_prefix filtered

  config1 @hostname = `hostname -s`.chomp

  filter1 [[tag, @hostname].join('.'), time, record] if record['method'] == 'GET'
</match>
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
