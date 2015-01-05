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


###Examples of 'ineffective' PowerTrack rules

```
snow AND cold

Corrected: snow cold
--> 30-day count --> Original: 45,775 | Corrected: 155,132
                     Delta: 109,357 | Factor: 3.4
```

```
climate AND change

Corrected: climate change
--> 30-day count --> Original: 67,807 | Corrected: 408,912
                     Delta: 341,105 | Factor: 6.0
```

```
Amazon AND (Drone OR Drones)

Corrected: Amazon (Drone OR Drones)
--> 30-day count --> Original: 1,026 | Corrected: 27,152
                     Delta: 26,126 | Factor: 26.5
```

Mistakenly mixing in the English word 'AND' with non-English terms can have particularly bad effects: 

```
lang:es AND playa

Corrected: lang:es playa
--> 30-day count --> Original: 610 | Corrected: 1,805,695
                     Delta: 1,805,085 | Factor: 2960.2
```


