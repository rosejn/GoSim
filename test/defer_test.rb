$:.unshift(File.dirname(__FILE__) + '/../lib')

require 'test/unit'

require 'gosim/defer'

class TestDefer < Test::Unit::TestCase
  include GoSim::Net

  def setup
    @cb_result = 0
    @eb_result = 0
  end

  def test_add_cb
    d = Deferred.new

    d.add_callbacks(method(:good_cb))
    d.add_callbacks(method(:good_cb), method(:good_eb))
    d.add_callback {|r| good_cb(r) }
    d.add_errback(method(:good_eb))
    d.add_callback(method(:good_cb))

    val = 0
    d.callback(val)
    assert(@cb_result == 4)
  end

  def test_add_eb
    d = Deferred.new

    d.add_callback(method(:good_cb))
    d.add_callbacks(method(:good_to_bad_cb))
    d.add_callbacks(method(:good_cb), method(:good_eb))
    d.add_errback(method(:good_eb))
    d.add_errback(method(:good_eb))
    d.add_errback(method(:good_eb))
    d.add_errback(method(:bad_to_good_eb))
    d.add_callback(method(:good_cb))

    val = 0
    d.callback(val)
    assert_equal(4, @eb_result)
    assert_equal(2, @cb_result)
  end

  def test_errback
    d = Deferred.new

    d.add_errback(method(:good_eb))
    d.add_errback {|f| good_eb(f) }
    d.add_errback(method(:good_eb))

    val = 0
    d.errback(Failure.new(val))
    assert_equal(3, @eb_result)
  end

  def test_pause
    d = Deferred.new

    d.callback(0)

    d.add_callback(method(:good_cb))
    d.add_callback(method(:good_cb))
    assert_equal(2, @cb_result)

    d.pause
    d.add_callback(method(:good_cb))
    assert_equal(2, @cb_result)
    d.add_callback(method(:good_cb))
    d.unpause
    assert_equal(4, @cb_result)
  end

  def good_cb(val)
    @cb_result = val += 1
    return @cb_result
  end

  def good_to_bad_cb(val)
    Failure.new(val)
  end

  def good_eb(failure)
    @eb_result += 1
    return failure
  end

  def bad_to_good_eb(failure)
    failure.result
  end
end
