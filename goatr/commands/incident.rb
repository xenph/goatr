require 'goatr/storage/incident'

module Goatr
  module Commands
    class Incident < SlackRubyBot::Commands::Base
      @@responders_usergroup_handle = ENV['RESPONDERS_SLACK_USERGROUP_HANDLE']
      @@responsers_usergroup_id = ENV['RESPONDERS_SLACK_USERGROUP_ID']
      @@incident_bots_slack_ids = ENV['BOT_SLACK_IDS']
      @@slack_user = Slack::Web::Client.new(token:ENV['SLACK_USER_TOKEN'])
      @@slack_client = Slack::Web::Client.new(token:ENV['SLACK_API_TOKEN'])

      match(/^goatr incident start (?<channel_name>\w*)$/i) do |client, data, match|
        client.say(channel: data.channel,
        text: " <!subteam^#{@@responsers_usergroup_id}|#{@@responders_usergroup_handle}> Making an Incident channel with the name #{match[:channel_name]}...")

        #create a channel with the first 21 characters of supplied name
        response = create_channel(match[:channel_name])
        new_channel_id = get_channel_id(response)
        incident = create_new_incident(match[:channel_name],new_channel_id)

        client.say(channel: data.channel, text: "Incident channel <##{new_channel_id}|#{match[:channel_name]}> successfully created.")
        client.say(channel: data.channel, text: "Now starting the goat rodeo. Inviting Ops to incident channel ##{match[:channel_name]}")
        #invite_responders_to_channel(new_channel_id)
        invite_user_to_channel(new_channel_id,'U6BKN9HPX')
        #post_to_channel(new_channel_id,"Welcome to the party, pal! \n https://cdn3.bigcommerce.com/s-d2bmn/images/stencil/1280x1280/products/3884/6/escape__01810.1500921070.png")
        post_to_channel(new_channel_id, "incident data #{incident}")
      end


      #need to make this set the incident commander data in the incident data
      match(/^goatr I am IC$/i) do |client, data, match|
        #client.say(channel: data.channel, text: "#{data} + #{match}")
        user_name = get_slack_user_name(data['user'])
        #storage = Goatr::Storage::Incident.new
        set_channel_topic(data.channel,"Incident IC is #{user_name}")
      end

      match(/^goatr list incidents$/i) do |client, data, match|
        client.say(channel: data.channel, text:"#{get_incident_list}")
      end

      class << self
        #submits with the first 21 characters since that is the max limit for slack name
        #will refactor to do proper validation later

        def create_new_incident(channel_name,channel_id)
          storage = Goatr::Storage::Incident.new
          incident = storage.new_incident
          incident["slack_channel"] = {"id" => channel_id, "name" => channel_name}
          incident["status"] = "active"
          storage.save_incident(incident["id"],incident)
        end

        def create_channel(channel_name)
          @@slack_user.channels_create(name:channel_name[0..20])
        end

        def set_channel_topic(channel_id,topic_name)
          @@slack_client.channels_setTopic(channel:channel_id,topic:topic_name)
        end

        def post_to_channel(channel_id,message)
          @@slack_client.chat_postMessage(channel:channel_id,text:message,as_user:true)
        end

        def get_slack_user_name(user_id)
          user_info = get_user_info(user_id)
          return nil unless (user_info && !user_info.empty?)
          user_info['user']['profile']['real_name']
        end

        def get_incident_list
          storage = Goatr::Storage::Incident.new
          incidents = storage.get_incidents
          str_output = []
          incidents.each do |incident|
            str_output << "#{incident["id"]} - ##{incident["slack_channel"]["name"]} - Status: #{incident["status"]}"
          end
          str_output.join("\n")
        end

        def get_user_info(user_id)
          begin
            @@slack_client.users_info(user:user_id)
          rescue
            nil
          end
        end

        def get_usergroups
          begin
            response = @@slack_user.usergroups_list
          rescue
            nil
          end
          if response["ok"]
            response['usergroups']
          else
            nil
          end
        end

        def get_responders_usergroup_id
          usergroups = get_usergroups
          return nil unless (usergroups && !usergroups.empty?)
          ug = usergroups.select{|usergroup| usergroup['handle'] == @@responders_usergroup_handle}.first
          return nil unless (ug && !ug.empty?)
          ug['id']
        end

        def get_responder_ids
          responders_usergroup_id = get_responders_usergroup_id
          return nil unless responders_usergroup_id
          begin
            response = @@slack_user.usergroups_users_list(usergroup:responders_usergroup_id)
          rescue => e
            nil
          end
          return nil unless response and !response.empty?
          #returns a native ruby Array instead of Hashie::Array
          response.users.map{|user_id| user_id}
        end

        def invite_responders_to_channel(channel_id)
          responder_ids = get_responder_ids
          return nil unless responder_ids and !responder_ids.empty?
          bot_slack_ids = get_bot_slack_ids
          invite_users_to_channel(channel_id,(responder_ids + bot_slack_ids))
        end

        def invite_users_to_channel(channel_id,user_ids)
          user_ids.each do |user_id|
            invite_user_to_channel(channel_id,user_id)
          end
        end

        def invite_user_to_channel(channel_id,user_id)
          @@slack_user.channels_invite(channel:channel_id,user:user_id)
        end

        def get_bot_slack_ids
          @@incident_bots_slack_ids.split(",")
        end

        def get_usergroup_id(usergroup_handle,response)
          response['usergroups'].select{|usergroup| usergroup['handle'] == usergroup_handle}.first["id"]
        end

        def get_channel_id(response)
          response['channel']['id']
        end

        #To be implemented, input validation for legimitate slack channel names
        def incident_name

        end

      end

    end
  end
end
