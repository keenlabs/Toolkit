Retention Analysis Script


================================oOo===================================
This script helps you figure out how many entities that do an activity in a given week do an activity (not neccessarily the same one) in subsequent weeks. For example, for users that create account in a given week, how many of them login in subsequent weeks since their signup date. This is commonly used for rentention analysis aka cohort analysis.
You must have event data stored in Keen IO in order to run this analysis. The program uses the Keen IO funnel analysis API to do the calculations.
The analysis can go back any num_weeks in the past and will run analysis for each week since that time (one cohort for each week). The results will be outputted to Terminal and also an excel file. The total number of funnel calculations is the number of weeks^2/2 so the query can take some time; be patient!
================================oOo===================================

Step 1 - Determine how far back in the past you want to go for this analysis and set the value of num_weeks. Calculations will be run for every week since that week, up until the most recent completed week.
Step 2 - Enter your Keen Project Info into the script variables.
Step 3 - Define your funnel steps in the script. The first step will define your cohort groups. The last step will determine your "success" criteria.
Step 4 - Run the script!

If you have any questions about this script, you can contact me at michelle@keen.io or join our Keen IO developers google group.
https://groups.google.com/forum/#!forum/keen-io-devs
