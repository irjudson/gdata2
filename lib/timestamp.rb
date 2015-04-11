 # Friendly Timestamp based on:
  #   http://almosteffortless.com/2007/07/29/the-perfect-timestamp/
  #   http://railsforum.com/viewtopic.php?pid=33185#p33185
  #
  # TODO : Update this to support time zones when added to this app, see example links above for possible help with that.
  def time_distance_or_time_stamp(time = nil, options = {})

    # base time is the time we measure against.  It is now by default.
    base_time = options[:base_time] ||= Time.now

    return '–' if time.nil?

    direction = (time.to_i < base_time.to_i) ? "ago" : "from now"
    distance_in_minutes = (((base_time - time).abs)/60).round
    distance_in_seconds = ((base_time - time).abs).round

    case distance_in_minutes
      when 0..1        then time = (distance_in_seconds < 60) ? "#{pluralize(distance_in_seconds, 'second')} #{direction}" : "1 minute #{direction}"
      when 2..59       then time = "#{distance_in_minutes} minutes #{direction}"
      when 60..90      then time = "1 hour #{direction}"
      when 90..1440    then time = "#{(distance_in_minutes.to_f / 60.0).round} hours #{direction}"
      when 1440..2160  then time = "1 day #{direction}" # 1 day to 1.5 days
      when 2160..2880  then time = "#{(distance_in_minutes.to_f / 1440.0).round} days #{direction}" # 1.5 days to 2 days
      else time = time.strftime("%a, %d %b %Y")
    end
    return time_stamp(time) if (options[:show_time] && distance_in_minutes > 2880)
    return time
  end

  def time_stamp(time)
    time.to_datetime.strftime("%a, %d %b %Y, %l:%M%P").squeeze(' ')
  end


#
#
# RSPEC TESTS
# --
#
  # describe "time_ago_or_time_stamp helper method" do
  #
  #   it "should return '–' if time is nil" do
  #     time = nil
  #     time_distance_or_time_stamp(time).should =~ /–/
  #   end
  #
  #   it "should return detailed timestamp if distance > 2880 minutes and options[:show_time] = true" do
  #     base_time = Time.utc(1966,"oct",25,05,35,0)
  #     time = base_time + (2881*60)
  #     time_distance_or_time_stamp(time, {:base_time => base_time, :show_time => true}).should =~ /Thu, 27 Oct 1966, 12:00am/
  #   end
  #
  #   it "should not return detailed timestamp if distance > 2880 minutes and options[:show_time] = false" do
  #     base_time = Time.utc(1966,"oct",25,05,35,0)
  #     time = base_time + (2881*60)
  #     time_distance_or_time_stamp(time, {:base_time => base_time, :show_time => false}).should =~ /Thu, 27 Oct 1966/
  #   end
  #
  #   it "should not return detailed timestamp if distance > 2880 minutes and options[:show_time] is not specified" do
  #     base_time = Time.utc(1966,"oct",25,05,35,0)
  #     time = base_time + (2881*60)
  #     time_distance_or_time_stamp(time, {:base_time => base_time}).should =~ /Thu, 27 Oct 1966/
  #   end
  #
  #   it "should return '1 second ago' when 1 second ago" do
  #     time = 1.second.ago
  #     time_distance_or_time_stamp(time).should =~ /1 second ago/
  #   end
  #
  #   it "should return '1 second from now' when 1 second from now" do
  #     time = 1.second.from_now
  #     time_distance_or_time_stamp(time).should =~ /1 second from now/
  #   end
  #
  #   it "should return '59 second ago' when 59 seconds ago" do
  #     time = 59.seconds.ago
  #     time_distance_or_time_stamp(time).should =~ /59 seconds ago/
  #   end
  #
  #   it "should return '59 second from now' when 59 seconds from now" do
  #     time = 59.seconds.from_now
  #     time_distance_or_time_stamp(time).should =~ /59 seconds from now/
  #   end
  #
  #   it "should return '1 minute ago' when 1 minute ago" do
  #     time = 60.seconds.ago
  #     time_distance_or_time_stamp(time).should =~ /1 minute ago/
  #   end
  #
  #   it "should return '1 minute from now' when 1 minute from now" do
  #     time = 60.seconds.from_now
  #     time_distance_or_time_stamp(time).should =~ /1 minute from now/
  #   end
  #
  #   it "should return '2 minutes ago' when 2 minutes ago" do
  #     time = 2.minutes.ago
  #     time_distance_or_time_stamp(time).should =~ /2 minutes ago/
  #   end
  #
  #   it "should return '2 minutes from now' when 2 minutes from now" do
  #     time = 2.minutes.from_now
  #     time_distance_or_time_stamp(time).should =~ /2 minutes from now/
  #   end
  #
  #   it "should return '59 minutes ago' when 59 minutes ago" do
  #     time = 59.minutes.ago
  #     time_distance_or_time_stamp(time).should =~ /59 minutes ago/
  #   end
  #
  #   it "should return '59 minutes from now' when 59 minutes from now" do
  #     time = 59.minutes.from_now
  #     time_distance_or_time_stamp(time).should =~ /59 minutes from now/
  #   end
  #
  #   it "should return '1 hour ago' when 1 hour ago" do
  #     time = 1.hour.ago
  #     time_distance_or_time_stamp(time).should =~ /1 hour ago/
  #   end
  #
  #   it "should return '1 hour from now' when 1 hour from now" do
  #     time = 1.hour.from_now
  #     time_distance_or_time_stamp(time).should =~ /1 hour from now/
  #   end
  #
  #   it "should return '23 hour ago' when 23 hours ago" do
  #     time = 23.hours.ago
  #     time_distance_or_time_stamp(time).should =~ /23 hours ago/
  #   end
  #
  #   it "should return '23 hour from now' when 23 hours from now" do
  #     time = 23.hours.from_now
  #     time_distance_or_time_stamp(time).should =~ /23 hours from now/
  #   end
  #
  #   it "should return '24 hours ago' when 24 hours ago" do
  #     time = 24.hours.ago
  #     time_distance_or_time_stamp(time).should =~ /24 hours ago/
  #   end
  #
  #   it "should return '24 hours from now' when 24 hours from now" do
  #     time = 24.hours.from_now
  #     time_distance_or_time_stamp(time).should =~ /24 hours from now/
  #   end
  #
  #   it "should return '1 day ago' when 25 hours ago" do
  #     time = 25.hours.ago
  #     time_distance_or_time_stamp(time).should =~ /1 day ago/
  #   end
  #
  #   it "should return '1 day from now' when 25 hours from now" do
  #     time = 25.hours.from_now
  #     time_distance_or_time_stamp(time).should =~ /1 day from now/
  #   end
  #
  #   it "should return '1 day ago' when 36 hours ago" do
  #     time = 36.hours.ago
  #     time_distance_or_time_stamp(time).should =~ /1 day ago/
  #   end
  #
  #   it "should return '1 day from now' when 36 hours from now" do
  #     time = 36.hours.from_now
  #     time_distance_or_time_stamp(time).should =~ /1 day from now/
  #   end
  #
  #   it "should return '2 days ago' when 37 hours ago" do
  #     time = 37.hours.ago
  #     time_distance_or_time_stamp(time).should =~ /2 days ago/
  #   end
  #
  #   it "should return '2 days from now' when 37 hours from now" do
  #     time = 37.hours.from_now
  #     time_distance_or_time_stamp(time).should =~ /2 days from now/
  #   end
  #
  #   it "should return '2 days ago' when 48 hours ago" do
  #     time = 48.hours.ago
  #     time_distance_or_time_stamp(time).should =~ /2 days ago/
  #   end
  #
  #   it "should return '2 days from now' when 48 hours from now" do
  #     time = 48.hours.from_now
  #     time_distance_or_time_stamp(time).should =~ /2 days from now/
  #   end
  #
  #   it "should return time_stamp without 'ago' when 49+ hours ago" do
  #     time = 49.hours.ago
  #     time_distance_or_time_stamp(time).should_not =~ /ago/
  #   end
  #
  #   it "should return time_stamp without 'from now' when 49+ hours from now" do
  #     time = 49.hours.from_now
  #     time_distance_or_time_stamp(time).should_not =~ /from now/
  #   end
  #
  #   it "should return time_stamp with only day & date when 49+ hours ago" do
  #     time = Time.utc(1966,"oct",25,05,35,0)
  #     time_distance_or_time_stamp(time).should =~ /Tue, 25 Oct 1966/
  #   end
  #
  #   it "should return time_stamp with only day & date when 49+ hours from now" do
  #     time = Time.utc(2020,"oct",25,05,35,0)
  #     time_distance_or_time_stamp(time).should =~ /Sun, 25 Oct 2020/
  #   end
  #
  # end
  #
  # describe "time_stamp helper method" do
  #
  #   it "should return a properly formatted timestamp" do
  #     time = Time.utc(1966,"oct",25,05,35,0)
  #     time_stamp(time).should =~ /Tue, 25 Oct 1966, 5:35am/
  #   end
  #
  # end
