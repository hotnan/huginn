module Agents
  class PinterestPublishAgent < Agent
    include PinterestConcern

    cannot_be_scheduled!

    description <<-MD
      The Pinterest Publish Agent publishes Pinterest posts from the events it receives.

      #{'## Include  `omniauth-Pinterest` in your Gemfile to use this Agent!' if dependencies_missing?}

      To be able to use this Agent you need to authenticate with Pinterest in the [Services](/services) section first.



      **Required fields:**

      `user_name` Your Pinterest  user name  (e.g. "john12")

      `board_name` Your Pinterest  board name  (e.g. "mustardhamsters")

      `note`  small note
      
      `link` Your project url
      
      `image_url` Image url 


      -------------

      [Full information on field options](https://www.github.com/realadeel/pinterest-api)

      Set `expected_update_period_in_days` to the maximum amount of time that you'd expect to pass between Events being created by this Agent.
    MD

    def validate_options
      errors.add(:base, "expected_update_period_in_days is required") unless options['expected_update_period_in_days'].present?
    end

    def working?
      event_created_within?(interpolated['expected_update_period_in_days']) && most_recent_event && most_recent_event.payload['success'] == true && !recent_error_logs?
    end

    def default_options
      {
        'expected_update_period_in_days' => "10",
        'board' => "{{user_name}}/{{board_name}}",
        'note' => "{{note}}",
        'link' => "{{link}}",
        'image_url' => "{{image_url}}",
      }
    end

    def receive(incoming_events)
      # if there are too many, dump a bunch to avoid getting rate limited
      if incoming_events.count > 20
        incoming_events = incoming_events.first(20)
      end
      incoming_events.each do |event|
        pinterest_board = interpolated(event)['board']
        pinterest_note = interpolated(event)['note']
        pinterest_link = interpolated(event)['link']
        pinterest_image_url = interpolated(event)['image_url']
        begin
          pinterest = publish_pin pinterest_board, pinterest_note, pinterest_link, pinterest_image_url
          create_event :payload => {
            'success' => true,
            'published_pin' => pinterest_image_url,
            'pin_id' => pinterest.id,
            'agent_id' => event.agent_id,
            'event_id' => event.id,
          }
        rescue Pinterest::Error => e
          create_event :payload => {
            'success' => false,
            'error' => e.message,
            'failed_pin' => pinterest_image_url,
            'agent_id' => event.agent_id,
            'event_id' => event.id,
          }
        end
      end
    end

    def publish_pin(pinterest_board, pinterest_note, pinterest_link, pinterest_image_url)
      pinterest.update(pinterest_board, pinterest_note, pinterest_link, pinterest_image_url)
    end
  end
end


# module Agents
#   class PinterestPublishAgent < Agent
#     include PinterestConcern

#     cannot_be_scheduled!

#     gem_dependency_check { defined?(Pinterest::Client) }

#     description <<-MD
#       The Pinterest Publish Agent publishes Pinterest posts from the events it receives.

#       #{'## Include  `omniauth-Pinterest` in your Gemfile to use this Agent!' if dependencies_missing?}

#       To be able to use this Agent you need to authenticate with Pinterest in the [Services](/services) section first.



#       **Required fields:**

#       `user_name` Your Pinterest  user name  (e.g. "john12")

#       `board_name` Your Pinterest  board name  (e.g. "mustardhamsters")

#       `note`  small note
      
#       `link` Your project url
      
#       `image_url` Image url 


#       -------------

#       [Full information on field options](https://www.github.com/realadeel/pinterest-api)

#       Set `expected_update_period_in_days` to the maximum amount of time that you'd expect to pass between Events being created by this Agent.
#     MD

#     def validate_options
#       errors.add(:base, "expected_update_period_in_days is required") unless options['expected_update_period_in_days'].present?
#     end

#     def working?
#       event_created_within?(interpolated['expected_update_period_in_days']) && most_recent_event && most_recent_event.payload['success'] == true && !recent_error_logs?
#     end

#     def default_options
#       {
#         'expected_update_period_in_days' => "10",
#         'board' => "{{user_name}}/{{board_name}}",
#         'note' => "{{note}}",
#         'link' => "{{link}}",
#         'image_url' => "{{image_url}}",
#       }
#     end

#     def receive(incoming_events)
#       # if there are too many, dump a bunch to avoid getting rate limited
#       if incoming_events.count > 20
#         incoming_events = incoming_events.first(20)
#       end
#       incoming_events.each do |event|
#         board = interpolated(event)['board']
#         note = interpolated(event)['note']
#         link = interpolated(event)['link']
#         image_url = interpolated(event)['image_url']
#         begin
#           post = publish_post(board_name, post_type, options)
#           if !post.has_key?('id')
#             log("Failed to create #{post_type} post on #{board_name}: #{post.to_json}, options: #{options.to_json}")
#             return
#           end
#           expanded_post = get_post(board_name, post["id"])
#           create_event :payload => {
#             'success' => true,
#             'published_post' => "["+board_name+"] "+post_type,
#             'post_id' => post["id"],
#             'agent_id' => event.agent_id,
#             'event_id' => event.id,
#             'post' => expanded_post
#           }
#         end
#       end
#     end

#     def publish_post(board_name, post_type, options)
#       options_obj = {
#         }

#       case post_type
#       when "photo"
#         options_obj[:caption] = options['caption']
#         options_obj[:link] = options['link']
#         options_obj[:source] = options['source']
#         tumblr.photo(board_name, options_obj)
#       end
#     end

#     def get_post(board_name, id)
#       obj = pinterest.posts(board_name, {
#         :id => id
#       })
#       obj["posts"].first
#     end
#   end
# end
