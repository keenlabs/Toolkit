require 'rubygems'
require 'net/http'
require 'net/https'#for making API requests
require 'uri'
require 'json' #for converting hashes to json format
require 'date'
require 'active_support/all' #for datetime calculation e.g. weeks.ago.at_beginning_of_week
require 'simple_xlsx' #for outputting excel files
require 'cgi' #for URL encoding

#================================oOo===================================
# This script helps you figure out how many entities that do an activity in a given week do an activity (not neccessarily the same one) in subsequent weeks
# For example, for users that create account in a given week, how many of them login in subsequent weeks since their signup date
# This is commonly used for rentention analysis aka cohort analysis 
# You must have event data stored in Keen IO in order to run this analysis
# The program uses the Keen IO funnel analysis API to do the calculations
# The analysis can go back any num_weeks in the past and will run analysis for each week since that time (one cohort for each week)
# The results will be outputted to Terminal and also an excel file
# The total number of funnel analyses is num_weeks^2/2 so the query can take some time 
#================================oOo===================================

# Step 1 - Determine how far back in the past you want to go for this analysis.
# Calculations will be run for every week since that week, up until the most recent completed week.

num_weeks = 15

# Step 2 - Enter your Keen Project Info

$projectID = "5011efa95f546f2ce2000000"
$key = "bc77cc2ff8c24c2aa1972b0d6c2058c2"
$api_version = "3.0"   # You probably don't need to change this
$api_url = "https://api.keen.io" # You probably don't need to change this

# Step 3 - Define your funnel steps. The first step will define your cohort groups. The last step will determine your "success" criteria.
# For example, say you are interested in login activity for customers who have paid
# step one: Submit Payment (groups customers based on the week they paid)
# step two: Login (counts how many of those customers logged in since the week they paid)
# Add any number of filters to any step (e.g. exclude test accounts).

$steps = [
    {
     :event_collection => "create_organization",
     :actor_property => "organization.id",
     :filters => [{
               :property_name => "organization.name",
               :operator => "ne",
               :property_value => "Keen"
               }],    
     },
     {
     :event_collection => "events_added_api_call",
     :actor_property => "project.organization.id",
     },
 ]

# Protip: You may have more than two steps. Middle steps will further refine the number of candidates which make it to the last step.
# Step 4 - Run this script!


#================================oOo===================================
# Increases time for Ruby to wait for HTTPS queries (only needed if you have gigantic collections (many millions of events))
module Net
    class HTTP
        alias old_initialize initialize

        def initialize(*args)
            old_initialize(*args)
            @read_timeout = 10*60     # 10 minutes
        end
    end
end

#================================oOo===================================
# Function to get Keen IO funnel result
# Given a funnel query URL it will return the response from Keen IO

def get_keen_value(keen_query_url)

    uri = URI.parse(keen_query_url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE #Be better than this

    
    http.start() { |http|
        response = http.get(uri.request_uri)
        }
end

#================================oOo===================================
# These two nested loops run through all of the weeks since num_weeks ago, building funnels queries and running them.

SimpleXlsx::Serializer.new(Time.now.to_s[0..19]+".xlsx") do |doc|  # This will create an excel file to output results
    doc.add_sheet("Retention") do |sheet|
        first_row_labels=["Week","Cohort Size"]   # These are the first two column headers in excel
        
        
        # This loop cycles through each week in num_weeks so that we can assign that week to the first step of the funnel
        
        num_weeks.times do |w|   
            first_row_labels << "Week "+(w+1).to_s  # There is one column for every week depending on your num_weeks. Week 0, Week 1, ... Week N
        end
                  
        sheet.add_row(first_row_labels)

        i=0

        # This loop cycles through each of the weeks starting with the week num_weeks ago
        while i < num_weeks do
            
            $row_items=[]

            puts "==========================oOo============================="   
            puts "Retention Analysis for the Cohort from " + ((num_weeks-i).weeks.ago.at_beginning_of_week).to_s[0..10] 
            
            $row_items << ((num_weeks-i).weeks.ago.at_beginning_of_week).to_s[0..10]
                                            
            applicable_weeks = num_weeks - i
    
            n=0
            
            # This loop cycles through each of the weeks starting with the week the cohort was created and then progressing through each week since then
            applicable_weeks.times do |n|   
                    
                # Insert rentention timeframe into the final funnel step
                
                # Insert cohort timeframe into the first funnel step

                $steps.first[:timeframe] = {   # This defines the timeframe for the first step in the funnel 
                    :start => (num_weeks-i).weeks.ago.at_beginning_of_week,  
                    :end => (num_weeks-i-1).weeks.ago.at_beginning_of_week
                    }
                
                $steps.last[:timeframe] =  {   # This defines the timeframe for the last step in the funnel 
                    :start => (applicable_weeks-n).weeks.ago.at_beginning_of_week,
                    :end => (applicable_weeks-n-1).weeks.ago.at_beginning_of_week
                    }
                
                query_name = "Retention_cohort_"+i.to_s+".week"+n.to_s              
                
                    finalsteps = CGI::escape($steps.to_json)
                
                    query_url = "https://api.keen.io/#{$api_version}/projects/#{$projectID}/queries/funnel?api_key=#{$key}&steps=#{finalsteps}"
                    query_result = get_keen_value(query_url)

                    if query_result.to_s.include? 'HTTPOK' # Error Handling
                        answer = JSON.parse(query_result.body)['result']
                        
                        if n == 0
                            puts "Cohort Size: "+answer[0].to_s
                            $row_items << answer[0]
                            puts "Week "+n.to_s+": "+answer.last.to_s
                            $row_items << (answer.last.to_f/answer[0].to_f)
                            $initial_converts = answer.last.to_i
                        else
                            puts "Week "+n.to_s+": "+answer.last.to_s
                            $row_items << (answer.last.to_f/$initial_converts)
                        end
                    else
                        puts query_result.to_s
                        puts query_result.body.to_s
                    end 

            n=n+1
            query_url = 0
            query_result = 0
            end
 
         i=i+1 
         sheet.add_row($row_items)
         $row_items=[]
         $initial_converts = 0
         
        end
    end
end


    


