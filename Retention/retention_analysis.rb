require 'rubygems'
require 'keen'
require 'json'
require 'date'
require 'active_support/all' #for datetime calculation e.g. weeks.ago.at_beginning_of_week
require 'simple_xlsx' #for outputting excel files
require 'cgi' #for URL encoding
 
 
#================================oOo===================================
# This program helps you figure out how many entities that do an activity in a given week do a different activity in subsequent weeks
# For example, for users that create an account in a given week, how many of them login in subsequent weeks since their signup date
# This is commonly used for rentention analysis aka cohort analysis. Cohorts are defined by the week they do the first step in the funnel. 
# You must have event data stored in Keen IO in order to run this analysis
# The program uses the Keen IO funnel analysis API to do the calculations
# The analysis can go back any num_weeks in the past and will run analysis for each week since that time (one cohort for each week)
# The results will be outputted to Terminal and also an excel file
# The total number of funnel analyses is num_weeks^2/2 so the query can take some time, espeically for very large event collections.
#================================oOo===================================
 
# Step 1 - Determine how far back in the past you want to go for this analysis.
# Calculations will be run for every week since that week, up until the most recent completed week.
# num_weeks determines the number of cohorts in your analysis.
 
num_weeks = 52
 
# Step 2 - Enter your Keen Project Info
 
Keen.project_id = <project ID>
Keen.read_key = <key>
 
# Step 3 - Define your funnel steps. The first step will define your cohort groups. The last step will determine your "success" criteria.
# For example, say you are interested in login activity for customers who have paid
# step one: Create Account (counts the number of unique accounts that were created that week)
# step two: Login (counts how many unique customers in the cohort logged in that week)
# Add any number of filters to any step (e.g. exclude test accounts).
# You can optionally add filters to the steps.
 
$steps = [
    {
     :event_collection => "create_account",
     :actor_property => "account.id",
     # :filters => [{         
     #           :property_name => "account.name",
     #           :operator => "ne",
     #           :property_value => "TestAccount"
     #           }],    
     },
     {
     :event_collection => "logins",
     :actor_property => "project.account.id",
     },
 ]
 
# Protip: You may have more than two steps. Middle steps will further refine the number of candidates which make it to the last step.
# Step 4 - Run this script!
 
# These two nested loops run through all of the weeks since num_weeks ago, building funnel queries and running them.
 
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
                    
                # Insert cohort timeframe into the first funnel step
                $steps.first[:timeframe] = {   
                    :start => (num_weeks-i).weeks.ago.at_beginning_of_week,  
                    :end => (num_weeks-i-1).weeks.ago.at_beginning_of_week
                    }
                
                # Insert rentention timeframe into the final funnel step
                $steps.last[:timeframe] =  {
                    :start => (applicable_weeks-n).weeks.ago.at_beginning_of_week,
                    :end => (applicable_weeks-n-1).weeks.ago.at_beginning_of_week
                    }
                
                query_name = "Retention_cohort_"+i.to_s+".week"+n.to_s              
                answer = Keen.funnel(:steps => $steps) # Run the Keen IO Query 
                
                # The Keen IO query returns a result like [X, Y]
                # X is the result of the first funnel step (number of a new accounts in this example, aka Cohort Size)
                # Y is the result of the second funnel step (number of logins in this example)
 
                if n == 0
                    puts "Cohort Size: "+answer[0].to_s 
                    $cohortSize = answer[0]
                    $row_items << $cohortSize  # We jam stuff into this array so we can print it to excel later. Item 0 in the array is the Cohort Size.
                    puts "Week "+n.to_s+": "+answer.last.to_s
                    $row_items << (answer.last.to_f/$cohortSize.to_f)
                else
                    puts "Week "+n.to_s+": "+answer.last.to_s
                    $row_items << (answer.last.to_f/$cohortSize.to_f) # We jam stuff into this array so we can print it to excel later. In this example, each column shows the % of accounts who did step 2 in a given week after signup.
                end
 
            n=n+1
            end
 
         i=i+1 
         sheet.add_row($row_items) # Put the data into the excel file
         $row_items=[] # Empty the array so we can use it again for the next row.
         
        end
    end
end
