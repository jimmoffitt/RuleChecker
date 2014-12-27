RuleChecker
===========

A set of tools to analyze a set of Gnip PowerTrack rules.

Examines PowerTrack rulesets and performs a set of analyses on them...

Currently, this tool is designed to:
* Summarize real-time rulesets, providing basic stats such as number of rules and average/longext lengths.
* Identify rules with explicit ANDs.
    * Corrects rule and compares 'before and after' 30-day Search API counts.
* Other possibilies:
    * Rules with both ANDs and ORs with no parentheses.  
    * Missing double quotes around exact phrases.
* Produce report-ready output rendered in markdown.
