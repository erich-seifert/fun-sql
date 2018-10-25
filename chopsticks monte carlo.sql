<<<<<<< HEAD
SET NOCOUNT ON 

IF OBJECT_ID('tempdb..#chopsticks', 'U') IS NOT NULL DROP TABLE #chopsticks;
IF OBJECT_ID('tempdb..#gameflow', 'U') IS NOT NULL DROP TABLE #gameflow;


/*
	things to do: cant use ur hand if its zero
	allow splitting of hands CHECK
	current can get stuck in infinite loop if hands become null 

*/

CREATE TABLE #chopsticks (player INT , hand_0_value INT , hand_1_value INT)
INSERT INTO #chopsticks  (player	 , hand_0_value		, hand_1_value	  ) VALUES (0, 1, 1), (1, 1, 1)

CREATE TABLE #gameflow (turn INT IDENTITY(1,1) PRIMARY KEY, player_added_to BIT, receive_hand BIT, give_hand BIT, p0h0 INT , p0h1 INT , p1h0 INT ,p1h1 INT, split BIT )

DECLARE @randomness AS TABLE (my_int int) 
	INSERT INTO @randomness VALUES (0),(0),(0),(1) -- 1/4

DECLARE @hand_states AS TABLE ( [values] INT)
	INSERT INTO @hand_states
	([values]) VALUES (0),(1),(2),(3),(4)

DECLARE @possible_hand_combinations AS TABLE (hand_one INT , hand_two INT, total INT)
DECLARE @split_results AS TABLE (id INT IDENTITY(1,1), split_old_h0 INT, split_old_h1 INT, split_new_h0 INT, split_new_h1 INT)

INSERT INTO @possible_hand_combinations
(
    hand_one
  , hand_two
  , total
)

SELECT h1.[values]
     , h2.[values]
	 , h1.[values] + h2.[values]

	  FROM @hand_states h1 
	  CROSS APPLY @hand_states h2


DECLARE @turn_flipper BIT = ROUND(RAND(),0) -- WHICH PLAYER GETS POINTS ADDED
DECLARE @set_turn_flipper BIT 
DECLARE @hand_giver BIT 
DECLARE @hand_receiver BIT 
DECLARE @total_points_for_p INT 



DECLARE @sql_exec VARCHAR(MAX),
		@CRLF VARCHAR(1) = CHAR(13)


INSERT INTO #gameflow
(
    player_added_to
  , p0h0
  , p0h1
  , p1h0
  , p1h1
  , split 
)
SELECT 
	  @turn_flipper
	, p0.hand_0_value
    , p0.hand_1_value
    , p1.hand_0_value
    , p1.hand_1_value
	, NULL 
FROM #chopsticks p0
OUTER APPLY #chopsticks p1
WHERE p0.player = 0
AND p1.player = 1


WHILE NOT EXISTS (SELECT 1 
					FROM #chopsticks
					WHERE hand_0_value + hand_1_value = 0
				 )

BEGIN 

SET @turn_flipper = ~@turn_flipper
SET @set_turn_flipper = @turn_flipper

	/*
		WHAT HAND UPDATES WHAT HAND?
	*/

	SET @hand_giver = ROUND(RAND(),0)
	SET @hand_receiver = ROUND(RAND(),0) 

	--IF EXISTS (SELECT 1 FROM #chopsticks
	--			WHERE player = ~@turn_flipper
	--			AND hand_0_value = 0
	--		  ) AND @hand_receiver = 0
	--		  SET @hand_receiver = ~@hand_receiver

	--IF EXISTS (SELECT 1 FROM #chopsticks
	--			WHERE player = ~@turn_flipper
	--			AND hand_1_value = 0
	--		  ) AND @hand_receiver = 1
	--		  SET @hand_receiver = ~@hand_receiver



SET @total_points_for_p =
(
    SELECT hand_0_value + hand_1_value
    FROM #chopsticks
    WHERE player = ~ @turn_flipper
);


        IF (
			SELECT TOP 1 my_int 
			FROM @randomness 
			ORDER BY NEWID()
			) = 1		-- and you hit the one in the random table
            BEGIN

					UPDATE cp
					SET cp.hand_0_value = phc.hand_one
						,cp.hand_1_value = phc.hand_two
					OUTPUT inserted.hand_0_value, inserted.hand_1_value, deleted.hand_0_value, deleted.hand_1_value
					INTO @split_results (split_new_h0, split_new_h1, split_old_h0, split_old_h1)
					FROM #chopsticks cp
					OUTER APPLY (SELECT TOP 1 hand_one
                                            , hand_two
                                            , total
									 FROM @possible_hand_combinations phc
									 WHERE phc.total = (cp.hand_0_value + cp.hand_1_value)
									 AND phc.hand_one != cp.hand_0_value
									 AND phc.hand_two != cp.hand_1_value
									 AND phc.hand_one != cp.hand_1_value
									 AND phc.hand_two != cp.hand_0_value
									 ORDER BY NEWID()
									 ) phc
					WHERE cp.player = ~@turn_flipper
						AND phc.hand_one IS NOT NULL 
						AND phc.hand_two IS NOT NULL 


					INSERT INTO #gameflow
					(
					    player_added_to
					  , receive_hand
					  , give_hand
					  , p0h0
					  , p0h1
					  , p1h0
					  , p1h1
					  , split 
					)
					SELECT 
						  ~@turn_flipper
						, NULL
						, NULL
						, p0.hand_0_value
					    , p0.hand_1_value
					    , p1.hand_0_value
					    , p1.hand_1_value
						, 1
					
					FROM #chopsticks p0
					OUTER APPLY #chopsticks p1
					WHERE p0.player = 0
					AND p1.player = 1


			END
	ELSE 
	BEGIN 
		SET @sql_exec = 
			  @CRLF + 'UPDATE p' + CAST(@set_turn_flipper AS VARCHAR(1))
			+ @CRLF + 'SET p'+ CAST(@set_turn_flipper AS VARCHAR(1)) + '.hand_' + CAST(@hand_receiver AS VARCHAR(1)) + '_value = '
			+ @CRLF + '('
			+ @CRLF + 'p'+ CAST(@set_turn_flipper AS VARCHAR(1)) + '.hand_' + CAST(@hand_receiver AS VARCHAR(1)) + '_value +' 
			+ @CRLF + 'p'+ CAST(~@set_turn_flipper AS VARCHAR(1)) + '.hand_'+ CAST(@hand_giver AS VARCHAR(1)) + '_value'
			+ @CRLF + ') % 5'

			+ @CRLF + 'FROM #chopsticks p0'
			+ @CRLF + 'OUTER APPLY #chopsticks p1'
			+ @CRLF + 'WHERE p0.player = 0'
			+ @CRLF + 'AND p1.player = 1'

		EXEC (@sql_exec)

		PRINT @sql_exec
		INSERT INTO #gameflow
		(
		    player_added_to
		  , receive_hand
		  , give_hand
		  , p0h0
		  , p0h1
		  , p1h0
		  , p1h1
		  , split 
		)
		SELECT 
			  @set_turn_flipper
			, @hand_receiver
			, @hand_giver
			, p0.hand_0_value
		    , p0.hand_1_value
		    , p1.hand_0_value
		    , p1.hand_1_value
			, 0
		
		FROM #chopsticks p0
		OUTER APPLY #chopsticks p1
		WHERE p0.player = 0
		AND p1.player = 1

	END 

SET @set_turn_flipper = NULL 
SET @sql_exec = NULL 

END 


SELECT  [turn] = turn - 1
      , player_added_to
      , receive_hand
      , give_hand
      , p0h0
      , p0h1
      , p1h0
      , p1h1
      , split 
	  , LAG(CASE WHEN player_added_to = 0 THEN p0h0 ELSE p1h0 END , 1, 0) OVER (ORDER BY turn) 
	  , LAG(CASE WHEN player_added_to = 0 THEN p0h1 ELSE p1h1 END , 1, 0) OVER (ORDER BY turn) 
	  
	  FROM #gameflow 
	  WHERE split IS NOT NULL 
	  ORDER BY turn 

SELECT * FROM @split_results ORDER BY id 

IF EXISTS   (SELECT 1 
					FROM #chopsticks
					WHERE hand_0_value + hand_1_value = 0
					AND player = 1
				 )
BEGIN 
SELECT 'PLAYER 0 WINS'
END 
ELSE 
BEGIN 
SELECT 'PLAYER 1 WINS'
=======
SET NOCOUNT ON 

IF OBJECT_ID('tempdb..#chopsticks', 'U') IS NOT NULL DROP TABLE #chopsticks;
IF OBJECT_ID('tempdb..#gameflow', 'U') IS NOT NULL DROP TABLE #gameflow;


/*
	things to do: cant use ur hand if its zero
	allow splitting of hands CHECK
	current can get stuck in infinite loop if hands become null 

*/

CREATE TABLE #chopsticks (player INT , hand_0_value INT , hand_1_value INT)
INSERT INTO #chopsticks  (player	 , hand_0_value		, hand_1_value	  )
VALUES (0, 1, 1), (1, 1, 1)

CREATE TABLE #gameflow (turn INT IDENTITY(1,1) PRIMARY KEY, player_added_to BIT, receive_hand BIT, give_hand BIT, p0h0 INT , p0h1 INT , p1h0 INT ,p1h1 INT, split BIT )

DECLARE @one_in_three AS TABLE (my_int int) INSERT INTO @one_in_three VALUES (0),(0),(0), (1)

DECLARE @possible_hand_combinations AS TABLE (hand_one INT , hand_two INT, total INT)

INSERT INTO @possible_hand_combinations
(
    hand_one
  , hand_two
  , total
)
VALUES
(1 , 1, 2) ,
(2 , 1, 3) ,
(3 , 1, 4) ,
(4 , 1, 5) ,
--(5 , 1, 6) ,
(1 , 2, 3) ,
(1 , 3, 4) ,
(1 , 4, 5) ,
--(1 , 5, 6) , 
(2 , 2, 4) ,
(2 , 3, 5) ,
(2 , 4, 6) , 
--(2 , 5, 7) ,
(3 , 2, 5) ,
(4 , 2, 6) ,
--(5 , 2, 7) ,
(3 , 3, 6) ,
(3 , 4, 7) ,
--(3 , 5, 8) ,
(4 , 3, 7) ,
--(5 , 3, 8) ,
(4 , 4, 8) 
--(4 , 5, 9) ,
--(5 , 4, 9) ,
--(5 , 5, 10)


DECLARE @turn_flipper BIT = ROUND(RAND(),0) -- WHICH PLAYER GETS POINTS ADDED
DECLARE @hand_giver BIT 
DECLARE @hand_taker BIT 
DECLARE @total_points_for_p INT 


DECLARE @sql_exec VARCHAR(MAX),
		@CRLF VARCHAR(1) = CHAR(13)


INSERT INTO #gameflow
(
    player_added_to
  , p0h0
  , p0h1
  , p1h0
  , p1h1
  , split 
)
SELECT 
	  @turn_flipper
	, p0.hand_0_value
    , p0.hand_1_value
    , p1.hand_0_value
    , p1.hand_1_value
	, NULL 
FROM #chopsticks p0
OUTER APPLY #chopsticks p1
WHERE p0.player = 0
AND p1.player = 1


WHILE NOT EXISTS (SELECT 1 
					FROM #chopsticks
					WHERE hand_0_value + hand_1_value = 0
				 )

BEGIN 
	
	/*
		WHAT HAND UPDATES WHAT HAND?
	*/

	SET @hand_giver = ROUND(RAND(),0)
	SET @hand_taker = ROUND(RAND(),0) 

	--IF EXISTS (SELECT 1 FROM #chopsticks
	--			WHERE player = ~@turn_flipper
	--			AND hand_0_value = 0
	--		  ) AND @hand_taker = 0
	--		  SET @hand_taker = ~@hand_taker

	--IF EXISTS (SELECT 1 FROM #chopsticks
	--			WHERE player = ~@turn_flipper
	--			AND hand_1_value = 0
	--		  ) AND @hand_taker = 1
	--		  SET @hand_taker = ~@hand_taker



SET @total_points_for_p =
(
    SELECT hand_0_value + hand_1_value
    FROM #chopsticks
    WHERE player = ~ @turn_flipper
);

IF @total_points_for_p > 2
    BEGIN
        IF
        (SELECT TOP 1 my_int FROM @one_in_three ORDER BY NEWID()) = 1
            BEGIN

					UPDATE cp
					SET cp.hand_0_value = phc.hand_one
						,cp.hand_1_value = phc.hand_two

					FROM #chopsticks cp
					OUTER APPLY (SELECT TOP 1 hand_one
                                            , hand_two
                                            , total
									 FROM @possible_hand_combinations phc
									 WHERE phc.total = (cp.hand_0_value + cp.hand_1_value)
									 AND phc.hand_one != cp.hand_0_value
									 AND phc.hand_two != cp.hand_1_value
									 AND phc.hand_one != cp.hand_1_value
									 AND phc.hand_two != cp.hand_0_value
									 ORDER BY NEWID()
									 ) phc
					WHERE cp.player = ~@turn_flipper


					INSERT INTO #gameflow
					(
					    player_added_to
					  , receive_hand
					  , give_hand
					  , p0h0
					  , p0h1
					  , p1h0
					  , p1h1
					  , split 
					)
					SELECT 
						  ~@turn_flipper
						, NULL
						, NULL
						, p0.hand_0_value
					    , p0.hand_1_value
					    , p1.hand_0_value
					    , p1.hand_1_value
						, 1
					
					FROM #chopsticks p0
					OUTER APPLY #chopsticks p1
					WHERE p0.player = 0
					AND p1.player = 1
			
			
			END;
    END;

	ELSE 
	BEGIN 


	SET @sql_exec = 
		  @CRLF + 'UPDATE p' + CAST(@turn_flipper AS VARCHAR(1))
		+ @CRLF + 'SET p'+ CAST(@turn_flipper AS VARCHAR(1)) + '.hand_' + CAST(@hand_taker AS VARCHAR(1)) + '_value = '
		+ @CRLF + '('
		+ @CRLF + 'p'+ CAST(@turn_flipper AS VARCHAR(1)) + '.hand_' + CAST(@hand_taker AS VARCHAR(1)) + '_value +' 
		+ @CRLF + 'p'+ CAST(~@turn_flipper AS VARCHAR(1)) + '.hand_'+ CAST(@hand_giver AS VARCHAR(1)) + '_value'
		+ @CRLF + ') % 5'

		+ @CRLF + 'FROM #chopsticks p0'
		+ @CRLF + 'OUTER APPLY #chopsticks p1'
		+ @CRLF + 'WHERE p0.player = 0'
		+ @CRLF + 'AND p1.player = 1'

	EXEC (@sql_exec)

	PRINT @sql_exec
	END 
INSERT INTO #gameflow
(
    player_added_to
  , receive_hand
  , give_hand
  , p0h0
  , p0h1
  , p1h0
  , p1h1
  , split 
)
SELECT 
	  @turn_flipper
	, @hand_taker
	, @hand_giver
	, p0.hand_0_value
    , p0.hand_1_value
    , p1.hand_0_value
    , p1.hand_1_value
	, 0

FROM #chopsticks p0
OUTER APPLY #chopsticks p1
WHERE p0.player = 0
AND p1.player = 1


SET @turn_flipper = ~@turn_flipper


END 


SELECT  [turn] = turn - 1
      , player_added_to
      , receive_hand
      , give_hand
      , p0h0
      , p0h1
      , p1h0
      , p1h1
      , split FROM #gameflow 
	  WHERE split IS NOT NULL 
	  ORDER BY turn 

IF EXISTS   (SELECT 1 
					FROM #chopsticks
					WHERE hand_0_value + hand_1_value = 0
					AND player = 1
				 )
BEGIN 
SELECT 'PLAYER 0 WINS'
END 
ELSE 
BEGIN 
SELECT 'PLAYER 1 WINS'
>>>>>>> 8a819bfa08327b6d7e13da7847f240362db566d4
END 