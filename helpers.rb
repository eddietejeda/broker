def reload!
  puts "Reloading #{ENV.fetch('ENV')} environment"
  load './bootup.rb'
end

module Grid
  
  def print(separator: ' ', padding: 20)
    self.each do |col|
      puts col.map { |e| "#{e.to_s.ljust(padding)}" }.join("#{separator} ")
    end
    nil
  end
end

module Table
  def print(separator: ' ', padding: 20, header: true)
    shares = [] 
    amount = []
    
    puts self.first.keys.map { |e| "#{e.to_s.ljust(padding)}" }.join("#{separator} ") if header
    
    self.each do |e| 
      col = []
      e.each do |v|
        col << "#{v.last.to_s[0..padding].gsub(/\s\w+\s*$/,'').ljust(padding)}"
      end
      puts col.join("#{separator} ")
    end

    nil
  end
end

class Array
  
  def stats(separator: ' ', padding: 20)

    self.each do |key, value|
      col = []
      col << key.to_s.ljust(padding)
      col << value.to_s.ljust(padding)
      puts col.join("#{separator} ")
    end
    
    nil
    #
  end

  
  def average
    if size > 0
      inject(&:+) / size
    else
      0
    end
  end

end


class Numeric
  
  def dollars
    "$#{add_commas(self)}"
  end

  def print_dollars
    puts dollars
    nil
  end

  def percent()
    "#{(self * 100).truncate(2)}%"
  end
  
  def percent_of(n)
    self.to_f / n.to_f * 100.0
  end
  
end


def date_diff(start_date, end_date, units=:months)
  seconds_between = (end_date.to_time.to_i - start_date.to_time.to_i).abs
  days_between = seconds_between / 60 / 60 / 24

  case units
    when :days
      days_between.floor
    when :months 
      (days_between / 30).floor
    when :years
      (days_between / 365).floor
    else
      seconds_between.floor
  end
end

def add_commas(num_string)
  dollar, cents = num_string.to_s.split(".")
  dollar.reverse.scan(/\d{3}|.+/).join(",").reverse
end

def positive_amount(value)
  value.to_s.gsub(/[^0-9\.]+/, "").to_f
end

def negative_amount(value)
  -(positive_amount(value))
end


def download_path(local="data/")
  `mkdir -p #{local}`
  if !File.exists?(local) && !File.directory?(local)
    puts "'#{local}' is not a valid file path."
  end
  return local
end