require 'keen'
require 'active_support/all' #for datetime calculation e.g. weeks.ago.at_beginning_of_week
require 'date'

Keen.project_id = '5011efa95f546f2ce2000000'
Keen.read_key = 'ef717eaec4aeb8e8b8b18891ffaa1eafed8c14cac1f7cb90030eaa7ed79ed2d540ee267547267c73f4c6e7ff9bcb8f7dec4df9500499a70737777d71971a20e6e3cd6532b44a44c5d269811178c2308867fd5082d44e51c05496b0099c4a06649207b8db43fe0458cf3cc059f5ecaadc'

puts signup_start_date = Date.new(2015, 1, 5) #{}"2015-01-05 00:00:00 -0800"  # monday morning at midnight
puts one_month_out_start =  signup_start_date + 7


puts Keen.funnel(:steps => [{ 
  :actor_property => "organization.id", 
  :event_collection => "create_organization", #Signups
  :timeframe => "previous_day" },
  {
  :actor_property => "project.organization.id", 
  :event_collection => "events_added_api_call", #Data Sent
  :timeframe => {   # This defines the timeframe for the first step in the funnel 
    :start => signup_start_date,  
    :end => signup_start_date + 7,
  	},
  :optional => true }, 
  {
  :actor_property => "project.organization.id", 
  :event_collection => "analysis_api_call", #Query
  :timeframe => "previous_day",
  :optional => true  }, 
  {
  :actor_property => "organization.id", 
  :event_collection => "submit_payment", #Paying Customer
  :timeframe => "previous_day", 
  :filters => [{
    "property_name" => "plan",
    "operator" => "not_contains",
    "property_value" => "FREE"
  	}],
  }

  ]) 
