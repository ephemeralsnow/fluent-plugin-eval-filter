require 'helper'
require 'fluent/test/driver/output'

class EvalFilterOutputTest < Test::Unit::TestCase

  def setup
    Fluent::Test.setup
  end

  def create_driver(conf)
    Fluent::Test::Driver::Output.new(Fluent::Plugin::EvalFilterOutput).configure(conf)
  end

  def test_configure
    assert_raise(Fluent::ConfigError) do
      create_driver('')
    end
    assert_raise(Fluent::ConfigError) do
      create_driver(%[config1 @test = "\#{self.to_s}"])
    end
    assert_raise(NameError) do
      create_driver(%[filter1 "\#{tag}"])
    end
  end

  def test_remove_tag_prefix
    d = create_driver(%[
      remove_tag_prefix t1
      filter1 tag
    ])

    d.run(default_tag: 't1.t2.t3') { d.feed({}) }

    emits = d.events
    assert_equal 1, emits.size
    assert_equal 't2.t3', emits[0][0]
  end

  def test_remove_tag_suffix
    d = create_driver(%[
      remove_tag_suffix t3
      filter1 tag
    ])

    d.run(default_tag: 't1.t2.t3') { d.feed({}) }

    emits = d.events
    assert_equal 1, emits.size
    assert_equal 't1.t2', emits[0][0]
  end

  def test_add_tag_prefix
    d = create_driver(%[
      add_tag_prefix t0
      filter1 tag
    ])

    d.run(default_tag: 't1.t2.t3') { d.feed({}) }

    emits = d.events
    assert_equal 1, emits.size
    assert_equal 't0.t1.t2.t3', emits[0][0]
  end

  def test_add_tag_suffix
    d = create_driver(%[
      add_tag_suffix t4
      filter1 tag
    ])

    d.run(default_tag: 't1.t2.t3') { d.feed({}) }

    emits = d.events
    assert_equal 1, emits.size
    assert_equal 't1.t2.t3.t4', emits[0][0]
  end

  def test_handle_tag_all
    d = create_driver(%[
      remove_tag_prefix t1
      remove_tag_suffix t3
      add_tag_prefix t4
      add_tag_suffix t5
      filter1 tag
    ])

    d.run(default_tag: 't1.t2.t3') { d.feed({}) }

    emits = d.events
    assert_equal 1, emits.size
    assert_equal 't4.t2.t5', emits[0][0]
  end

  def test_drop_all_filter
    d = create_driver(%[
      filter1 nil
    ])

    d.run(default_tag: 't1.t2.t3') { d.feed({}) }

    emits = d.events
    assert_equal 0, emits.size
  end

  def test_modify_record_filter
    d = create_driver(%[
      filter1 "record.merge!({'key' => 'value'})"
    ])

    d.run(default_tag: 'test') { d.feed({}) }

    emits = d.events
    assert_equal 1, emits.size
    assert_equal 'test', emits[0][0]
    assert_equal 1, emits[0][2].size
    assert_equal true, emits[0][2].key?('key')
    assert_equal 'value', emits[0][2]['key']
  end

  def test_replace_all_filter
    d = create_driver(%[
      filter1 nil
      filter2 "['tag', 0, {'key' => 'value'}]"
    ])

    d.run(default_tag: 'test') { d.feed({}) }

    emits = d.events
    assert_equal 1, emits.size
    assert_equal 'tag', emits[0][0]
    assert_equal 0, emits[0][1]
    assert_equal 1, emits[0][2].size
    assert_equal true, emits[0][2].key?('key')
    assert_equal 'value', emits[0][2]['key']
  end

  def test_conditional_filter
    d = create_driver(%[
      filter1 "[['http', tag].join('.'), record] if /^http:/.match(record['url'])"
      filter2 "(record['secure'] = true; [['https', tag].join('.'), record]) if /^https:/.match(record['url'])"
    ])

    d.run(default_tag: 'test') do
      d.feed({'url' => 'http://example.com/'})
      d.feed({'url' => 'https://example.com/'})
      d.feed({'url' => 'ftp://example.com/'})
    end

    emits = d.events
    assert_equal 2, emits.size
    assert_equal 'http.test', emits[0][0]
    assert_equal 1, emits[0][2].size
    assert_equal true, emits[0][2].key?('url')
    assert_equal 'http://example.com/', emits[0][2]['url']
    assert_equal 'https.test', emits[1][0]
    assert_equal 2, emits[1][2].size
    assert_equal true, emits[1][2].key?('url')
    assert_equal 'https://example.com/', emits[1][2]['url']
    assert_equal true, emits[1][2].key?('secure')
    assert_equal true, emits[1][2]['secure']
  end

  def test_reference_to_an_instance_variable_filter
    hostname = `hostname -s`.chomp
    d = create_driver(%[
      config1 @hostname = `hostname -s`.chomp
      filter1 "[tag, @hostname].join('.')"
    ])

    d.run(default_tag: 'test') { d.feed({}) }

    emits = d.events
    assert_equal 1, emits.size
    assert_equal "test.#{hostname}", emits[0][0]
  end

  def test_amplify_tag_filter
    d = create_driver(%[
      filter1 "(1..3).map { |n| tag + n.to_s }.to_enum"
    ])

    d.run(default_tag: 'test') { d.feed({}) }

    emits = d.events
    assert_equal 3, emits.size
    assert_equal "test1", emits[0][0]
    assert_equal "test2", emits[1][0]
    assert_equal "test3", emits[2][0]
  end

  def test_amplify_time_filter
    d = create_driver(%[
      filter1 "(1..3).map { |n| time + n }.to_enum"
    ])

    d.run(default_tag: 'test') { d.feed({}) }

    emits = d.events
    assert_equal 3, emits.size
    assert emits[0][1] > 0
    assert_equal emits[0][1] + 1, emits[1][1]
    assert_equal emits[1][1] + 1, emits[2][1]
  end

  def test_amplify_record_filter
    d = create_driver(%[
      filter1 "(1..3).map { |n| record.merge({'n' => n}) }.to_enum"
    ])

    d.run(default_tag: 'test') { d.feed({'key' => 'value'}) }

    emits = d.events
    assert_equal 3, emits.size
    assert_equal 2, emits[0][2].size
    assert_equal true, emits[0][2].key?('key')
    assert_equal 'value', emits[0][2]['key']
    assert_equal true, emits[0][2].key?('n')
    assert_equal 1, emits[0][2]['n']
    assert_equal 2, emits[1][2].size
    assert_equal true, emits[1][2].key?('key')
    assert_equal 'value', emits[1][2]['key']
    assert_equal true, emits[1][2].key?('n')
    assert_equal 2, emits[1][2]['n']
    assert_equal 2, emits[2][2].size
    assert_equal true, emits[2][2].key?('key')
    assert_equal 'value', emits[2][2]['key']
    assert_equal true, emits[2][2].key?('n')
    assert_equal 3, emits[2][2]['n']
  end

  def test_split_record_filter
    d = create_driver(%[
      filter1 "record.map { |key, value| [[tag, key].join('.'), {'key' => value}] }.to_enum"
    ])

    d.run(default_tag: 'test') { d.feed({'key1' => 'value1', 'key2' => 'value2', 'key3' => 'value3'}) }

    emits = d.events
    assert_equal 3, emits.size
    assert_equal 'test.key1', emits[0][0]
    assert_equal 1, emits[0][2].size
    assert_equal true, emits[0][2].key?('key')
    assert_equal 'value1', emits[0][2]['key']
    assert_equal 'test.key2', emits[1][0]
    assert_equal 1, emits[1][2].size
    assert_equal true, emits[1][2].key?('key')
    assert_equal 'value2', emits[1][2]['key']
    assert_equal 'test.key3', emits[2][0]
    assert_equal 1, emits[2][2].size
    assert_equal true, emits[2][2].key?('key')
    assert_equal 'value3', emits[2][2]['key']
  end

  def test_split_array_in_record_filter
    d = create_driver(%[
      filter1 "record['array'].map { |v| {'value' => v} }.to_enum"
    ])

    d.run(default_tag: 'test') { d.feed({'array' => ['test1', 'test2', 'test3']}) }

    emits = d.events
    assert_equal 3, emits.size
    assert_equal 1, emits[0][2].size
    assert_equal true, emits[0][2].key?('value')
    assert_equal 'test1', emits[0][2]['value']
    assert_equal 1, emits[1][2].size
    assert_equal true, emits[1][2].key?('value')
    assert_equal 'test2', emits[1][2]['value']
    assert_equal 1, emits[2][2].size
    assert_equal true, emits[2][2].key?('value')
    assert_equal 'test3', emits[2][2]['value']
  end

  def test_require_libraries
    d = create_driver(%[
      requires yaml
      filter1 "record.to_yaml; ['tag', 0, record]"
    ])
    assert_nothing_raised {
      d.run(default_tag: 'test') { d.feed({'key' => 'value'}) }
    }
  end

  def test_require_error
    assert_raise(Fluent::ConfigError) do
      d = create_driver(%[
        requires hoge
        filter1 "record.to_yaml; ['tag', 0, record]"
      ])
    end
  end

end
