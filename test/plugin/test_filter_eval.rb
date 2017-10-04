# coding: utf-8
require 'helper'
require 'fluent/test/driver/filter'

class EvalFilterTest < Test::Unit::TestCase
  include Fluent

  setup do
    Fluent::Test.setup
    @time = event_time
  end

  def create_driver(conf = '')
    Test::Driver::Filter.new(Plugin::EvalFilter).configure(conf)
  end

  def filter(config, msgs)
    d = create_driver(config)
    d.run(default_tag: 'test') {
      msgs.each {|msg|
        d.feed(@time, msg) # Filterプラグインにメッセージを通す
      }
    }
    filtered = d.filtered.map{|e| e.last} # 結果を受け取る. [record]の配列
    filtered
  end

  sub_test_case 'configure' do
    test 'check default' do
      config = %[
        <rule>
          filter "[time, record] if record['status'] == '404'"
        </rule>
      ]
      assert_nothing_raised {
        create_driver(config)
      }

      assert_raise(Fluent::ConfigError) do
        create_driver('')
      end
    end
  end

  sub_test_case 'filter stream' do
    test 'filter' do
      msgs = [
        {'status' => '301', 'message' => 'message'},
        {'status' => '302', 'message' => 'message'},
        {'status' => '404', 'message' => 'message'},
        {'status' => '503', 'message' => 'message'},
        {'status' => '401', 'message' => 'message'}
      ]
      config = %[
        <rule>
          filter "[time, record] if record['status'] == '404'"
        </rule>
        <rule>
          filter "[time, record] if record['status'] == '503'"
        </rule>
      ]
      es = filter(config, msgs)
      assert_equal(es.size, 2)
      assert_equal(es[0][1]['status'], '404')
      assert_equal(es[1][1]['status'], '503')
    end
  end

  sub_test_case 'convert type' do
    test 'to_i' do
      msgs = [
        {'status' => '301', 'message' => 'message'},
        {'status' => '302', 'message' => 'message'},
        {'status' => '404', 'message' => 'message'},
        {'status' => '503', 'message' => 'message'},
        {'status' => '401', 'message' => 'message'}
      ]
      config = %[
        <rule>
         filter "record['status'] = record['status'].to_i; [time, record]"
        </rule>
      ]
      es = filter(config, msgs)
      assert_equal(es.size, 5)
      assert_equal(es[0][1]['status'], 301)
      assert_equal(es[1][1]['status'], 302)
      assert_equal(es[2][1]['status'], 404)
      assert_equal(es[3][1]['status'], 503)
      assert_equal(es[4][1]['status'], 401)
    end
  end

  sub_test_case 'add value' do
    test 'add user_id' do
      msgs = [
        {'status' => '301', 'message' => 'user_id:1'},
        {'status' => '302', 'message' => 'user_id:2'},
        {'status' => '404', 'message' => 'user_id:3'},
        {'status' => '503', 'message' => 'user_id:4'},
        {'status' => '401', 'message' => 'user_id:5'}
      ]
      config = %[
        <rule>
          filter "record['user_id'] = record['message'].split(':').last.to_i; [time, record]"
        </rule>
      ]
      es = filter(config, msgs)
      assert_equal(es.size, 5)
      assert_equal(es[0][1]['user_id'], 1)
      assert_equal(es[1][1]['user_id'], 2)
      assert_equal(es[2][1]['user_id'], 3)
      assert_equal(es[3][1]['user_id'], 4)
      assert_equal(es[4][1]['user_id'], 5)
    end
  end

  sub_test_case 'require libraries' do
    test 'require yaml' do
      config = %[
        requires yaml
        <rule>
          filter "record.to_yaml; [time, record]"
        </rule>
      ]
      assert_nothing_raised {
        create_driver(config)
        es = filter(config, [{'key' => 'value'}])
        assert_equal(es.size, 1)
      }
    end

    test 'require libraries with whitespace' do
      d = create_driver(%[
        requires yaml, time
        <rule>
          filter "record.to_yaml; [Time.now.to_i, record]"
        </rule>
      ])
      assert_nothing_raised {
        d.run(default_tag: 'test') { d.feed({'key' => 'value'}) }
      }
    end

    test 'require error' do
      config = %[
        requires hoge
        <rule>
          filter "record.to_yaml; [time, record]"
        </rule>
      ]
      assert_raise(Fluent::ConfigError) do
        create_driver(config)
      end
    end
  end
end
