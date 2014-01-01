require 'helper'

class EvalFilterTest < Test::Unit::TestCase

  def setup
    Fluent::Test.setup
  end

  def create_driver(conf, tag = 'test')
    Fluent::Test::OutputTestDriver.new(Fluent::EvalFilterOutput, tag).configure(conf)
  end

  def test_drop
    d = create_driver(%[
      filter1 nil
    ])

    d.run do
      d.emit({})
    end

    emits = d.emits
    assert_equal 0, emits.size
  end

  def test_reference_to_an_instance_variable
    hostname = `hostname -s`
    d = create_driver(%[
      config1 @hostname = `hostname -s`
      filter1 tag + '.' + @hostname
    ])

    d.run do
      d.emit({})
    end

    emits = d.emits
    assert_equal 1, emits.size
    p emits[0]
    assert_equal "test.#{hostname}", emits[0][0]
  end

end
