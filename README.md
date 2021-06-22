# Q3Servers

This gem will help you browse through Quake3-style master servers (Protocol 68) (tested only with Urban Terror)


## Installation

Add this line to your application's Gemfile:

```ruby
gem 'q3_servers'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install q3_servers


## Usage
```ruby
    q3_urt_list = Q3Servers::List.new
    
    #### Some defaults settings you can change
    # q3_urt_list.master_address
    # q3_urt_list.only_favorites = false
    # q3_urt_list.timeout = 1
    # q3_urt_list.master_cache_secs = 600
    # q3_urt_list.info_cache_secs = 60
    # q3_urt_list.debug = true
    ####
    # q3_urt_list.add_favorite('XXX.XXX.XXX.XXX', '27960')
    # q3_urt_list.add_favorite('YYY.YYY.YYY.YYY', '27961')
    
    servers = q3_urt_list.fetch_servers({})
```
##### Threads
  You can use use_threads keyword, for multi-threaded fetching (one for each server found!)
   ```ruby
   q3_urt_list.fetch_servers({}, use_threads: true)
   ```

##### Filter
  Filter by keys from "info" attribute in Q3Servers::Server
  example:
  ```ruby
   q3_urt_list.fetch_servers({hostname: "Arg"})
   ```

#### And now read information from each server
##### Examples:
```ruby
    # print info from a server
    servers.first.tap do |server| 
      puts server.info['hostname'] ## server.name_c_sanitized exclude symbols and colors from hostname field
      puts server.gametype # print gametype mapped in Q3Servers::Server::GT Hash
      puts server.info.keys # for more information you can access
    end

    # get only servers with clients
    server_with_clients = servers.select { |server| server.info['clients'].to_i > 0 }
    
    # show players 
    server_with_clients.each do |server|
      server.info['sv_status']['players'].each do |player|
      puts "#{player.name} has ping: #{player.ping} with #{player.kills} kills"
      end    
    end
```

#### More info

You can set `only_favorites = true` for fetch only servers added with `add_favorite(host, port)` method

#### TODO
- Tests
- Pool of threads

#### This gem was built only for fun :)

##### Used in `UrbanterrorBot` on Telegram

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/jpgarritano/q3_servers.

