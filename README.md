[![Code Climate](https://codeclimate.com/github/kaspernj/apsis-on-steroids/badges/gpa.svg)](https://codeclimate.com/github/kaspernj/apsis-on-steroids)

# apsis-on-steroids

Library that implements the Apsis API in Ruby in regards to administrating subscribers and such for newsletters.

## Examples

### Connecting
```ruby
aos = ApsisOnSteroids.new(
  api_key: "[your api key]"
)
```

### List all mailing lists.
```ruby
aos.mailing_lists
```

### Create a mailing list
```ruby
aos.create_mailing_list(
  Name: "my_awesome_list",
  FromName: "Kasper Johansen",
  FromEmail: "kj@naoshi-dev.com",
  CharacterSet: "utf-8"
)
```

### Get a mailing list.
```ruby
mlist = aos.mailing_list_by_name("test_list")
```

### Delete a mailing list.
```ruby
mlist.delete
```

### Get a subscriber from a mailing list.
```ruby
sub = mlist.subscriber_by_email("some@email.com")
```

### Create one or more subscribers in a mailing list.
```ruby
mlist.create_subscribers(
  [
    {
      Email: "some@email.com",
      Name: "Some Name"
    },{
      Email: "some_other@email.com",
      Name: "Some Name"
    }
  ]
)
```

### Get details about subscribers.
```ruby
puts "Details: #{sub.details}"
```

### Update subscribers.
```ruby
sub.update(Email: "some_third@email.com")
```

### Remove subscriber from a mailing list.
```ruby
mlist.remove_subscriber(sub)
```

### Get a list of subscribers from a mailing list.
```ruby
list = mlist.subscribers
list.each do |sub|
  # do something
end
```

### Get a total list of subscribers.
```ruby
aos.subscribers do |sub|
  # do something
end
```

### Get sendings
```ruby
date_from = Date.new(2014, 6, 17)
date_to = Date.new(2014, 6, 24)

sendings = apsis.sendings_by_date_interval(@date_from, @date_to).to_a
```

### Get data from sendings
```ruby
sendings.opens(count: true) #=> 5
sendings.bounces(count: true) #=> 1
sendings.clicks(count: true) #=> 3
sendings.opt_outs(count: true) #=> 1

sendings.clicks.each do |click|
  puts "ClickData: #{click.data_hash}"
end
```

## Contributing to apsis-on-steroids

* Check out the latest master to make sure the feature hasn't been implemented or the bug hasn't been fixed yet.
* Check out the issue tracker to make sure someone already hasn't requested it and/or contributed it.
* Fork the project.
* Start a feature/bugfix branch.
* Commit and push until you are happy with your contribution.
* Make sure to add tests for it. This is important so I don't break it in a future version unintentionally.
* Please try not to mess with the Rakefile, version, or history. If you want to have your own version, or is otherwise necessary, that is fine, but please isolate to its own commit so I can cherry-pick around it.

## Copyright

Copyright (c) 2013 kaspernj. See LICENSE.txt for
further details.

