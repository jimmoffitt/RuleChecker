RuleChecker
===========

A set of tools to analyze a set of Gnip PowerTrack rules. Tools to identify rules that result in both __less__ and __more__ tweets being delivered than intended. Also anticipate tools for translating rules from other formats into PowerTrack rules.    
Examines PowerTrack rulesets and performs a set of analyses on them...

Currently, there are tools designed to:
* Summarize real-time rulesets, providing basic stats such as number of rules and average/longext lengths.
* Identify rules with explicit ANDs.
    * Corrects rule and compares 'before and after' 30-day Search API counts.
* Help access the effectiveness of negation terms.
* Translates long rules (> 17K characters) in Lucene-like syntax into PowerTrack syntax.
 
* Other possibilies:
    * Rules with both ANDs and ORs with no parentheses.  
    * Missing double quotes around exact phrases.
    * Produce report-ready output rendered in markdown.


####Examples of 'ineffective' PowerTrack rules

#####Explicit ANDs

Using explicit ANDs is likely the most common mistake when developing PowerTrack rules. Many query languages like SQL and Lucene use these operators for combining clauses. PowerTrack instead uses a space between terms.

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

#####Assessing Negation Effectiveness
