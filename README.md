# Brokerage
I like coding in Ruby more than I like manipulating spreadsheets. So I created a command line interface to view Schwabb financial data.

The REPL is the UI. I want to stay in the Ruby ecosystem when I manipulate the data, to to use the methods, you will need to use. The code is not optimized for performance. Since the primary way I use this code is in the command line, I don't mind if it takes a second to load. Although, I developed the code with the mindset that if I optimize the backend, most of the code would still work.

WARNING: This is just an experiment and not fully tested. Do not trust results.

# Installation

```
bundle install
bundle exec bin/broker
```

# Using commands

When in IRB, you can run commands like this:

`> portfolio.print`


Note: if you run the command directly, you will get Array or Hash response. If you add .print to the method, it will format the display in IRB. For example 

`holding("AAPL")` returns an array
`holding("AAPL").print` prints the result in a table format.

# Public Methods

  - portfolio
  - holding(ticker)
  - stocks(ownership: true)
  - price(ticker, date: false)
  - transactions(ticker,  start_date: false, end_date: false, raw:  false)
  - market_value(ticker, date: false)
  - cost_basis(ticker, date: false, strategy: :date)
  - price_history(ticker,  start_date: false, end_date: false)
  - total_return(ticker, date: false)
  - calculated_return(ticker, date: false)
  - oldest_holding_date(ticker)
  - total_shares_sold(ticker,  date: false)
  - total_value_bought(ticker,  date: false)
  - total_value_of_sold(ticker, date: false )
  - cost_basis_of_sold(ticker, date: false, strategy: :date)
  - realized_gains(ticker,  date: false,  strategy: :date)
  - average_sale_price(ticker,  date: false, strategy: :date)
  - shares(ticker, date: false)
  
