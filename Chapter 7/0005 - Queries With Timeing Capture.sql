SELECT Account1.AccountHandle + '->' + 
       STRING_AGG(CONCAT(Interest.InterestName,'->',Account2.AccountHandle), '->') WITHIN GROUP (GRAPH PATH) AS ConnectedPath, 
       LAST_VALUE(Account2.AccountHandle) WITHIN GROUP (GRAPH PATH) AS ConnectedToAccountHandle
FROM   SocialGraph.Account AS Account1
                   ,SocialGraph.Account FOR PATH AS Account2
                   ,SocialGraph.Interest FOR PATH AS Interest
                   ,SocialGraph.InterestedIn FOR PATH AS InterestedIn
                   ,SocialGraph.InterestedIn FOR PATH AS InterestedIn2
                   --Account1 is interested in an interest, and Account2 is also
WHERE  MATCH(SHORTEST_PATH(Account1(-(InterestedIn)->Interest<-(InterestedIn2)-Account2)+)) -- The interesting part
  AND  Account1.AccountHandle = '@Toby_Higgins'
OPTION (MAXDOP 1)

UPDATE SocialGraph.Account
SET   AccountHandle = CONCAT('@',REPLACE(AccountHandle,' ','_'))






  Toby Higgins
Mario Lindsey
Elisa Cooley
Bart Evans
Dana Kaufman
Jodi Hurley
SELECT *
FROM   SocialGraph.Account
WHERE $node_id 
IN
(
N'{"type":"node","schema":"SocialGraph","table":"Account","id":76574}',
N'{"type":"node","schema":"SocialGraph","table":"Account","id":92557}',
N'{"type":"node","schema":"SocialGraph","table":"Account","id":66843}',
N'{"type":"node","schema":"SocialGraph","table":"Account","id":65979}',
N'{"type":"node","schema":"SocialGraph","table":"Account","id":25900}',
N'{"type":"node","schema":"SocialGraph","table":"Account","id":96365}'
)
