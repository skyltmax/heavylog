# Heavylog

[![Gem Version](https://badge.fury.io/rb/heavylog.svg)](https://badge.fury.io/rb/heavylog)
[![CI](https://github.com/skyltmax/heavylog/actions/workflows/ci.yml/badge.svg)](https://github.com/skyltmax/heavylog/actions/workflows/ci.yml)

Heavylog enables you to log all Rails requests to file as JSON or any other format you want.

Aside from metadata about requests full output is also included like SQL/Rails logging and `puts` statements.
Example request using the JSON formatter:
```
{"request_id":"e2cdef0a-9851-4aab-b58f-60e607b4d1a9","request_start":"2021-04-25T15:37:20+00:00","ip":"52.52.52.52","messages":"Started GET \"/admin/info/sidekiq\" for 52.52.52.52 at 2021-04-25 15:37:20 +0000\nProcessing by Admin::InfoController#sidekiq_stats as */*\nRequested via apphost.com as */*\n  Snippet Load (1.8ms)  SELECT \"snippets\".* FROM \"snippets\" WHERE (locale = 'sv-SE' AND tag = 'information_notice_contact') ORDER BY \"snippets\".\"id\" ASC LIMIT $1  [[\"LIMIT\", 1]]\n  Snippet Load (1.5ms)  SELECT \"snippets\".* FROM \"snippets\" WHERE (locale = 'sv-SE' AND tag = 'contact_us_frame') ORDER BY \"snippets\".\"id\" ASC LIMIT $1  [[\"LIMIT\", 1]]\n  Rendering text template\n  Rendered text template (Duration: 0.1ms | Allocations: 16)\nCompleted 200 OK in 41ms (Views: 0.6ms | ActiveRecord: 3.3ms | Allocations: 10734)\n","method":"GET","path":"/admin/info/sidekiq","format":"*/*","controller":"Admin::InfoController","action":"sidekiq_stats","status":200,"duration":40.74,"view_runtime":0.56,"db_runtime":3.28,"user_id":null,"admin_id":null,"request_host":"apphost.com","ua":"curl/7.58.0","operation":null}
```

Example use case is collecting the JSON files and shipping them to an Elastic/Kibana cluster for centralized logging.
## Installation

Add this line to your application's Gemfile:

```ruby
gem "heavylog"
```

And then execute:

```bash
$ bundle
```

## Usage

Enable and configure in a Rails initializer `config/initializers/logger.rb`:

```rb
Rails.application.configure do
  config.heavylog.enabled = true
  config.heavylog.path = Rails.root.join("log/heavylog.log")
  # Default formatter is Heavylog::Formatters::Raw which simply outputs the ruby hash as a string
  config.heavylog.formatter = Heavylog::Formatters::Json.new
  config.heavylog.log_sidekiq = true # Default is `false`, set to `true` to automatically log sidekiq job runs too.
end
```

## Configuration

| Option | Type     | Description                |
| :-------- | :------- | :------------------------- |
| `enabled` | `boolean` | Set to `true` to enable logging. Default: `false`.  |
| `path` | `string` | Path to output file. Default: `log/heavylog.log`.  |
| `message_limit` | `integer` | Request output will be truncated if longer than this limit. Default: `52428800` (50MB).  |
| `log_sidekiq` | `boolean` | Set to `true` to automatically log sidekiq jobs too. Default: `false`.  |
| `error_handler` | `lambda/proc` | Code to execute when formatter throws exception. Default: `->(e) { p "HeavyLog: Error writing to log: #{e.class}: #{e.message}\n  #{e.backtrace.join("\n  ")}" }`
| `custom_payload` | `block` | Block executed for every request that should return hash with extra fields you want to log. Default: `nil`. |

### Custom payload

`custom_payload` accepts a block with a single argument, `controller` you can use to access any methods you normally would in a controller action.
It should return a hash with the extra fields you want to log.

```rb
Rails.application.configure do
  config.heavylog.custom_payload do |controller|
    user_id = controller.respond_to?(:current_user) ? controller.current_user&.id : nil

    {
      user_id:      user_id,
      request_host: controller.request.host,
      ua:           controller.request.user_agent,
      operation:    controller.request.params[:operationName],
    }
  end
end
```

### Sidekiq logging

Set `log_sidekiq` to `true` if you want to automatically log Sidekiq job runs to the same file. Example with JSON formatter:
```
{"request_id":"fb2c3798e2634011d670f753","request_start":"2021-04-25T16:00:53+00:00","ip":"127.0.0.1","messages":"  Order Load (1.8ms)  SELECT \"orders\".* FROM \"orders\" WHERE \"orders\".\"id\" = $1 LIMIT $2  [[\"id\", 109987473], [\"LIMIT\", 1]]\n  Customer Load (1.7ms)  SELECT \"customers\".* FROM \"customers\" WHERE \"customers\".\"id\" = $1 LIMIT $2  [[\"id\", 1027337], [\"LIMIT\", 1]]\n","controller":"SidekiqLogger","action":"MailPrepaidCheckupsJob","args":"[109987473]"}
```

Sidekiq job runs go into the same file as regular request logs but have controller set to `SidekiqLogger` and action to the name of the job.

### Karafka logging

Subclass your `ApplicationConsumer` class to `Heavylog::Adapters::KarafkaConsumer` if you want to automatically log Karafka consumer runs to the same file. Example with JSON formatter:
```
{"@timestamp":"2026-02-11T10:31:21+00:00","message":"  main (5.4ms)  SELECT 1\n  ↳ /workspaces/skyltmax/api/app/consumers/click_house_ingest_consumer.rb:9:in 'ClickHouseIngestConsumer#consume'\n  main (71.7ms)  INSERT INTO admin_recent_visits (ts, admin_id, section) SETTINGS async_insert=1, wait_for_async_insert=1 FORMAT CSV\n  ↳ /workspaces/skyltmax/api/app/consumers/click_house_ingest_consumer.rb:24:in 'block in ClickHouseIngestConsumer#insert_rows'\n[d354a60d632b] Consume job for AdminRecentVisitIngestConsumer on sm-dev-admin-recent-visits-0 finished in 131.71 ms\n","http":{"request":{"id":"640cdbee-9685-4a48-a1b1-ddf2e34d10bb"}},"source":{"address":"127.0.0.1","ip":"127.0.0.1"},"heavylog":{"controller":"KarafkaLogger","action":"AdminRecentVisitIngestConsumer","args":"topic=sm-dev-admin-recent-visits partition=0 messages=2"},"event":{"module":"heavylog","category":"web","dataset":"heavylog.karafka"},"url":{"path":null}}
```

Karafka consumer runs go into the same file as regular request logs but have controller set to `KarafkaLogger` and action to the name of the consumer.

### JSON formatter

Every request results in a hash containing all info about the request. The default `Heavylog::Formatters::Raw` formatter simply outputs the hash as a string to the output file.
Use the `Heavylog::Formatters::Json` formatter to convert the hash to JSON. The resulting file will contain one JSON object per line for every request.

### Custom formatter

The formatter interface is simply a class with a `call` method that accepts a single argument which is the hash containing info about the request.
The method should return the final result you want to write to file. Heavylog writes one line per request.

JSON formatter for example:
```rb
class Json
  def call(data)
    ::JSON.dump(data)
  end
end
```

## Publishing

This repo publishes a Ruby gem (heavylog) whenever a GitHub Release is published.

Setup (one-time):

- In rubygems configure trusted publishing.
- Ensure gem version matches. The workflow verifies that the git tag version equals gem version.

How to release:

1. Update version:
   - `lib/heavylog/version.rb`: `VERSION = "x.y.z"`
2. Commit and push changes.
3. Create a Git tag vX.Y.Z and a GitHub Release for that tag.

What the workflow does:

- Verifies tag version matches package.json and version.rb
- Publishes the npm package with provenance enabled
- Builds and pushes the gem to RubyGems

## License

[MIT](https://choosealicense.com/licenses/mit/)


