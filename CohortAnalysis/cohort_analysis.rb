require 'keen'
require 'active_support/all'
require 'date'

Keen.project_id = '<PROJECT_ID>'
Keen.read_key = 'READ_KEY'

signup_start_date = Date.new(2020, 1, 5) # "2020-01-05 00:00:00 -0800"  # monday morning at midnight
#puts Date.today.at_beginning_of_week
#puts signup_start_date < Date.today.at_beginning_of_week

while signup_start_date < Date.today.at_beginning_of_week do 

  puts "start date = ", signup_start_date

  puts Keen.funnel(:steps => [{ 
  :actor_property => "organization.id", 
  :event_collection => "create_organization", #Signups
  :timeframe => {   # This defines the timeframe for the first step in the funnel 
    :start => signup_start_date,  
    :end => signup_start_date + 7,
    },
  },

  {
  :actor_property => "project.organization.id", 
  :event_collection => "events_added_api_call", #Data Sent
  :timeframe => {   # This defines the timeframe for the first step in the funnel 
    :start => signup_start_date,  
    :end => signup_start_date + 7,
  	},
  :optional => true
  }, 

  {
  :actor_property => "project.organization.id", 
  :event_collection => "events_added_api_call", #Data Sent
  :timeframe => {  
    :start => signup_start_date + 7,  
    :end => signup_start_date + 14,
    },
  :optional => true
  }, 

  {
  :actor_property => "project.organization.id", 
  :event_collection => "analysis_api_call", #Query
  :timeframe => {   
    :start => signup_start_date,  
    :end => signup_start_date + 7,
    },
  :optional => true  
  }, 

  {
  :actor_property => "project.organization.id", 
  :event_collection => "analysis_api_call", #Query
  :timeframe => {    
    :start => signup_start_date + 7,  
    :end => signup_start_date + 14,
    },
  :optional => true  
  }, 

  {
  :actor_property => "organization.id", 
  :event_collection => "submit_payment", #Paying Customer
  :timeframe => {   
    :start => signup_start_date,  
    :end => signup_start_date + 7,
    },
  :filters => [{
    "property_name" => "plan",
    "operator" => "not_contains",
    "property_value" => "FREE"
  	}],
  :optional => true  
  },

  {
  :actor_property => "organization.id", 
  :event_collection => "submit_payment", #Paying Customer
  :timeframe => {   
    :start => signup_start_date + 7,  
    :end => signup_start_date + 14,
    },
  :filters => [{
    "property_name" => "plan",
    "operator" => "not_contains",
    "property_value" => "FREE"
    }],
  }
  ]) 

  signup_start_date = signup_start_date + 7
end

