module Broker

  def datasource(raw:  false)
    # This will assume Schwab's data format
    skipped = []
    rows = []
    SmarterCSV.process(File.join(download_path, "equities.csv")) do |chunk|
      chunk.each do |t|
        if (raw == true)
          rows << t        
        elsif (t[:action] == "Journaled Shares" &&  t[:shares] < 0) || ([
          "Qual Div Reinvest", 
          "Reinvest Dividend", 
          "Cash Dividend", 
          "Pr Yr Div Reinvest"
        ].include?(t[:action]))
          skipped << t
        elsif t[:action] == "Sell"
          rows << { 
            ticker: t[:ticker], 
            date: DateTime.strptime(t[:date], "%m/%d/%Y").to_date, 
            action: t[:action], 
            description: t[:description], 
            price: positive_amount(t[:price]), 
            shares: -(t[:shares].to_f), 
            amount: negative_amount(t[:amount]) 
          } 
        else
          rows << { 
            ticker: t[:ticker], 
            date: DateTime.strptime(t[:date], "%m/%d/%Y").to_date, 
            action: t[:action], 
            description: t[:description], 
            price: positive_amount(t[:price]), 
            shares: t[:shares].to_f, 
            amount: positive_amount(t[:amount]) } 
        end
      end
    end
    rows.extend(Table).freeze
  end


  # Ticker specific
  def transactions(ticker,  start_date: false, end_date: false, raw:  false)
    # start_date not supported yet
    datasource(raw: raw).map do |t|
      if t[:ticker] == ticker
        # byebug
        if end_date && t[:date]
          if  t[:date] <= end_date.to_date
            { 
              ticker: t[:ticker], 
              date: t[:date], 
              action: t[:action], 
              shares: t[:shares], 
              price: t[:price], 
              amount: t[:amount] 
            }         
          end
        else
          { 
            ticker: t[:ticker], 
            date: t[:date], 
            action: t[:action], 
            shares: t[:shares], 
            price: t[:price], 
            amount: t[:amount] 
          } 
        end
      end
    end.compact.extend(Table).freeze
  end
  

  def portfolio

    heading = true
    stocks.map do |t|
    
      if heading
        heading = false
        ["ticker", "shares", "share/price", "amount"]
      else
        [t[:ticker], positive_amount(t[:shares]).truncate(2), t[:price].dollars, positive_amount(t[:amount]).dollars ]
      end

    end.extend(Grid)

  end
  


  def stocks(ownership: true)
    ## TODO ownership: true not implemented
    datasource.select {|h| 
      h[:ticker] && h[:ticker] =~ /^[A-Z]+$/ }.uniq{ |h| h[:ticker] }.map{|t| 
          { 
            ticker: t[:ticker], 
            shares: shares(t[:ticker]), 
            price:  price(t[:ticker]), 
            amount: market_value(t[:ticker])
          } 
        }.compact.extend(Table).freeze

  end

  def holding(ticker)
    today = Date.today
    summary = []
    summary << ["Market Value",     market_value(ticker).dollars ]
    summary << ["Cost Basis",       cost_basis(ticker).dollars ]
    summary << ["Current Shares",   shares(ticker).truncate(2) ]
    summary << ["Today's price",    price(ticker).dollars ]

    summary << ["YTD Return",       display_calculated_return(ticker, start_date: today.beginning_of_year, timeframe: :months) ]

    # Average, not CAGR
    summary << ["1 Month Return",   display_calculated_return(ticker, start_date: today - 1.months,   timeframe: :months) ]
    summary << ["3 Month Return",   display_calculated_return(ticker, start_date: today - 3.months,   timeframe: :months) ]
    summary << ["6 Month Return",   display_calculated_return(ticker, start_date: today - 6.months,   timeframe: :months) ]
    summary << ["1 Year Return",    display_calculated_return(ticker, start_date: today - 12.months,  timeframe: :months) ]
    summary << ["2 Year Return",    display_calculated_return(ticker, start_date: today - 24.months,  timeframe: :months) ]
    summary << ["3 Year Return",    display_calculated_return(ticker, start_date: today - 36.months,  timeframe: :months) ]
    summary << ["4 Year Return",    display_calculated_return(ticker, start_date: today - 48.months,  timeframe: :months) ]
    summary << ["5 Year Return",    display_calculated_return(ticker, start_date: today - 60.months,  timeframe: :months) ]

    summary << ["Total Return",     total_return(ticker).percent  ]
    summary.extend(Grid)
  end

  def market_value(ticker, date: false)
    shares(ticker, date: date) * price(ticker, date: date)
  end

  def cost_basis(ticker, date: false, strategy: :date)
    total_value_bought(ticker, date: date) - ( cost_basis_of_sold(ticker, date: date) + realized_gains(ticker, date: date) )
  end


  def get_stock_price_url(ticker)
    "https://financialmodelingprep.com/api/v3/quote-short/#{ticker}?apikey=#{ENV["STOCK_DATA_API_KEY"]}"
  end

  def get_stock_history_url(ticker)
    "https://financialmodelingprep.com/api/v3/historical-price-full/#{ticker}?serietype=line&apikey=#{ENV["STOCK_DATA_API_KEY"]}"
  end

  def price(ticker, date: false)
    # If its not a trading day, it will look for the next trading day
    # If it's today's date, then we check quote, not history
    if date && date.to_date != Date.today
      # TODO: this  "- 5.days" in an unfortunate hack. I didn't realize the 
      # this implemention would return 0 if the date is not a trading day.
      # So I get 5 days before to find last trading day
      price_history(ticker,  start_date: (date - 5.days), end_date: date).last.to_a.last.to_f
    else
      filename = "#{download_path}#{ticker}-quote.json"

      if( !File.exists?(filename) || File.ctime(filename).to_date < Date.today )
        # puts "downloading new file"
        uri = URI.parse(get_stock_price_url(ticker))
        request = Net::HTTP::Get.new(uri)
        request["Upgrade-Insecure-Requests"] = "1"

        req_options = {
          use_ssl: uri.scheme == "https",
        }

        response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
          http.request(request)
        end
        File.open(filename, "w") { |f| f.write response.body }
      end

      JSON.parse(File.read(filename)).first.to_h['price'].to_f
    end
  end


  def price_history(ticker,  start_date: false, end_date: false)
    start_date = start_date ? start_date.to_date : oldest_holding_date(ticker)
    end_date = end_date ? end_date.to_date : Date.today

    filename = "#{download_path}#{ticker}.json"

    if( !File.exists?(filename) || File.ctime(filename).to_date < Date.today )
      puts "downloading new file"
      uri = URI.parse(get_stock_history_url(ticker))
      request = Net::HTTP::Get.new(uri)
      request["Upgrade-Insecure-Requests"] = "1"

      req_options = {
        use_ssl: uri.scheme == "https",
      }

      response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
        http.request(request)
      end
      File.open(filename, "w") { |f| f.write response.body }
    end

    JSON.parse(File.read(filename))['historical'].reverse.map do |row|
  
      if( row['date'].to_date >= start_date && row['date'].to_date <= end_date )
        [ row['date'], row['close'].to_f.truncate(2) ]
      end
     
    end.compact
  end

  # TOTAL
  def total_dividends(ticker, end_date: false)
    #TODO: Yeah.
  end

  def total_return(ticker, date: false)
    (market_value(ticker, date: date) - cost_basis(ticker, date: date))  / cost_basis(ticker, date: date)
  end

  def calculated_return(ticker, date: false)
    date = oldest_holding_date(ticker) if date == false
    total_return(ticker) - total_return(ticker, date: date)
  end


  def display_calculated_return(ticker, start_date: false, end_date: false, timeframe: :months)
  
    if oldest_holding_date(ticker) > start_date
      "-"
    else
      calculated_return(ticker, date: start_date).percent
    end
  end

  def oldest_holding_date(ticker)
    transactions(ticker).first[:date]
  end

  def format_date(date)
    date.strftime("%Y-%m-%d")
  end


  def total_shares_sold(ticker,  date: false)
    # check
    value = []  
    # First we see how many shares are sold and how much
    transactions(ticker).each do |t|
      if ["Sell"].include?(t[:action])
        if date == false
          value << t[:shares].abs
        elsif date  && t[:date] <= date.to_date 
          value << t[:shares].abs
        end      
      end
    end
    value.sum  
  end


  def total_value_bought(ticker,  date: false)
    # stock_price = price(ticker, date: date)
  
    value = []
    transactions(ticker).each do |t|
      if ["Journaled Shares", "Buy", "Reinvest Shares"].include?(t[:action])
        if date == false
          value << t[:amount]
        elsif date  && t[:date] <= date.to_date 
          value << t[:amount]
        end
      end
    end

    value.sum
  end

  def total_value_of_sold(ticker, date: false )
    # check
    value = []  
    # First we see how many shares are sold and how much
    transactions(ticker).each do |t|
      if ["Sell"].include?(t[:action])
        if date == false
          value <<  t[:amount].abs
        elsif date  && t[:date] <= date.to_date 
          value <<  t[:amount].abs
        end
      end
    end  
    value.sum  
  end

  def cost_basis_of_sold(ticker, date: false, strategy: :date)
    total_shares_sold(ticker, date: date) * average_sale_price(ticker, date: date, strategy: strategy)
  end

  def realized_gains(ticker,  date: false,  strategy: :date)
    total_value_of_sold(ticker, date: date) - cost_basis_of_sold(ticker, date: date)
  end

  # strategy: :date = FIFO
  # strategy: :price = cheapest first
  def average_sale_price(ticker,  date: false, strategy: :date)
    shares_count = []
  
    # First we see how many shares are sold and how much
    transactions(ticker).each do |t|
      if ["Sell"].include?(t[:action])
        if date == false
          shares_count << t[:shares].to_i
        elsif date  && t[:date] <= date.to_date 
          shares_count << t[:shares].to_i
        end
      end
    end
  
    # FIFO calculation, get the prices of the earliest shares.
    i = 0
    sale_prices = []
    shares_sold = shares_count.sum.abs
  
    transactions(ticker).sort_by { |h| h[strategy] }.each do |t|    
      if ["Buy"].include?(t[:action]) && i < shares_sold
        t[:shares].to_i.times do |s|
          if i < shares_sold
            sale_prices << t[:price]
          end
          i = i + 1
        end
      end
    end
    sale_prices.average
  end



  def shares(ticker, date: false)
    # we count the number of shares until the end_date
    transactions(ticker, end_date: date).map { |h| h[:shares] }.sum
  end


end

include Broker