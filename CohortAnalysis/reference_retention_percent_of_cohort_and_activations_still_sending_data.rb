require 'rubygems'
require 'net/http'
require 'net/https'
require 'uri'
require 'keen'
require 'json'
require 'date'
require 'active_support/all' #for datetime calculation e.g. weeks.ago.at_beginning_of_week
require 'cgi' #for URL encoding


# optionally set this as an env var 
# KEEN_API_URL=http://dal05-prod-app-0002:8009
# export KEEN_API_URL=http://dal05-prod-app-0002:8009


#================================oOo===================================
# This program helps you figure out how many entities that do an activity in a given week do a different activity in subsequent weeks
# For example, for users that create an account in a given week, how many of them login in subsequent weeks since their signup date
# This is commonly used for rentention analysis aka cohort analysis 
# You must have event data stored in Keen IO in order to run this analysis
# The program uses the Keen IO funnel analysis API to do the calculations
# The analysis can go back any num_weeks in the past and will run analysis for each week since that time (one cohort for each week)
# The results will be outputted to Terminal and also an excel file
# The total number of funnel analyses is num_weeks^2/2 so the query can take some time, espeically for very large event collections.
#================================oOo===================================

# Step 1 - Determine how far back in the past you want to go for this analysis.
# Calculations will be run for every week since that week, up until the most recent completed week.

num_weeks = 24

report_description = "6mo retention for Dec 2014 Board Meeting"

# Step 2 - Enter your Keen Project Info

Keen.project_id = '5011efa95f546f2ce2000000'
Keen.read_key = 'ef717eaec4aeb8e8b8b18891ffaa1eafed8c14cac1f7cb90030eaa7ed79ed2d540ee267547267c73f4c6e7ff9bcb8f7dec4df9500499a70737777d71971a20e6e3cd6532b44a44c5d269811178c2308867fd5082d44e51c05496b0099c4a06649207b8db43fe0458cf3cc059f5ecaadc'

# Step 3 - Define your funnel steps. The first step will define your cohort groups. The last step will determine your "success" criteria.
# For example, say you are interested in login activity for customers who have paid
# step one: Submit Payment (groups customers based on the week they paid)
# step two: Login (counts how many of those customers logged in since the week they paid)
# Add any number of filters to any step (e.g. exclude test accounts).

$steps = [
    {
     :event_collection => "create_organization",
     :actor_property => "organization.id",
     # :filters => [{
     #           :property_name => "organization.name",
     #           :operator => "ne",
     #           :property_value => "TestOrg"
     #           }],    
     },
     {
     :event_collection => "events_added_api_call",
     :actor_property => "project.organization.id",
     },
 ]

# Protip: You may have more than two steps. Middle steps will further refine the number of candidates which make it to the last step.
# Step 4 - Run this script!

x = 0
sums = {}
while x < (num_weeks + 1) do
    sums[x] = {
        "count" => 0,
        "percent_of_cohort" => 0,
        "percent_of_activated_wk1" => 0
    }
    x = x + 1
end
$row_sums = []
$row_sums << "totals"

#================================oOo===================================
# These two nested loops run through all of the weeks since num_weeks ago, building funnels queries and running them.

string = (0...8).map { (65 + rand(26)).chr }.join

file = File.open('./Results/'+"#{report_description}_"+string+'.csv', 'w')

# SimpleXlsx::Serializer.new(Time.now.to_s[0..19]+".xlsx") do |doc|  # This will create an excel file to output results
#     doc.add_sheet("Retention") do |sheet|
        # first_row_labels=["Signup","Cohort"]   # These are the first two column headers in excel
        # second_row_labels=["Week", "Size"] # These are the two cells below that
        first_row_labels="Signup, Cohort, "   # These are the first two column headers in excel
        second_row_labels="Week, Size, " # These are the two cells below that
        
        # This loop cycles through each week in num_weeks so that we can assign that week to the first step of the funnel
        
        num_weeks.times do |w|   
            # first_row_labels << "Week"  # There is one column for every week depending on your num_weeks. Week 0, Week 1, ... Week N
            # first_row_labels << (w+1).to_s  # A an empty cell is needed since the next row has two cells per week
            # second_row_labels << "Num"
            # second_row_labels << "%"
            first_row_labels = first_row_labels + "Week " + (w+1).to_s + ", " + ", " + ", "
            second_row_labels = second_row_labels + "Num, " + "% of Signups, " + "% of Activated, "
        end
        
        file.puts first_row_labels
        file.puts second_row_labels
        
        file.close

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
            applicable_weeks.times do 
                    
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
                
                query_name = "Retention_cohort_"+ i.to_s + ".week" + n.to_s              
                answer = Keen.funnel(:steps => $steps)

                if n == 0
                    puts "Cohort Size: " + answer[0].to_s
                    $cohortSize = answer[0]
                    $firstWeekActivatedSize = answer.last
                    $row_items << $cohortSize
                    puts "Week " + n.to_s + ": " + answer.last.to_s     # answer.last is the second number in the funnel response, the number of times step2 happened
                    $row_items << answer.last                           # The number of orgs
                    $row_items << ((answer.last.to_f / $cohortSize.to_f)*100).to_i.to_s + "%"   # Percentage of Cohort
                    $row_items << ((answer.last.to_f / $firstWeekActivatedSize.to_f)*100).to_i.to_s + "%"   # Percentage of Activated first wk
                    sums[0]["count"] = sums[0]["count"] + $cohortSize
                    sums[1]["count"] = sums[1]["count"] + answer.last
                    sums[1]["percent_of_cohort"] = ((sums[1]["count"].to_f / sums[0]["count"].to_f)*100).to_i.to_s + "%"
                    sums[1]["percent_of_activated_wk1"] = ((sums[1]["count"].to_f / sums[1]["count"].to_f)*100).to_i.to_s + "%"
                else
                    puts "Week " + n.to_s + ": " + answer.last.to_s
                    $row_items << answer.last                          # The number of orgs
                    $row_items << ((answer.last.to_f/$cohortSize.to_f)*100).to_i.to_s + "%"  # Percentage of Cohort
                    $row_items << ((answer.last.to_f/$firstWeekActivatedSize.to_f)*100).to_i.to_s + "%"  # Percentage of Activated first wk                    
                    c = n + 1  # c is for column where there is one column for each week
                    sums[c]["count"] = sums[c]["count"] + answer.last
                    sums[c]["percent_of_cohort"] = sums[c]["count"].to_f / sums[0]["count"].to_f   
                    sums[c]["percent_of_activated_wk1"] = sums[c]["count"].to_f / sums[1]["count"].to_f                                 
                end

            n=n+1
            end
 
         i=i+1 
         # sheet.add_row($row_items)
         file = File.open('./Results/'+"#{report_description}_"+string+'.csv', 'a')
         text = ""
         $row_items.each do |i|
           text = text + i.to_s + ", "
         end
         
         file.puts text
         file.close
         $row_items=[]
         
        end
        
        z = 0
        while z < (num_weeks + 1) do
            if z == 0
                $row_sums << sums[z]["count"]
            else
                $row_sums << sums[z]["count"]
                $row_sums << (sums[z]["percent_of_cohort"] * 100).to_i.to_s + "%"
                $row_sums << (sums[z]["percent_of_activated_wk1"] * 100).to_i.to_s + "%"                
            end    
            z=z+1
        end    
        
        # sheet.add_row($row_sums)
        file = File.open('./Results/'+"#{report_description}_"+string+'.csv', 'a')
        stringy = ""
        $row_sums.each do |s|
          stringy = stringy + s.to_s + ", " 
        end
        file.puts stringy
        file.close



    


