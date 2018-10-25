<<<<<<< HEAD
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~--
/*
-----------------------------------------------
---|D|DDDD-----|D|-----|DDDDDD----|D|DDDDDD----
---|D|----D----|D|----|D----------|D|----------
---|D|-----D---|D|---|D-----------|D|DDDDDD----
---|D|----D----|D|----|D----------|D|----------
---|D|DDDD-----|D|-----|DDDDDD----|D|DDDDDD----
-----------------------------------------------
*/
-- 2/3/2017 - Erich Seifert
-- simulates a rolls of however many dice with however many sides
-- tells you probablity of rolling that combination
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~--
DECLARE @dice_staging 
AS TABLE 
(
   number_of_sides TINYINT
 , number_of_dice INT
)

INSERT INTO @dice_staging
( 
	number_of_sides -- number of rolls in table variable representing dice
  , number_of_dice  -- number of cross applies of above table variable
) 
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~--
VALUES  (3, 2),
		(5, 1)

IF (SELECT SUM(number_of_dice) FROM @dice_staging) > 11
BEGIN
            RAISERROR('Cartesian overload',16,1);
            RETURN; 
END 

IF EXISTS (SELECT 1 FROM @dice_staging GROUP BY number_of_sides HAVING COUNT(*) > 1)
BEGIN
            RAISERROR('Do not select two different dice with same amount of sides, combine them',16,1);
            RETURN; 
END 


--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~--
-- DYNAMIC SQL GOODIES
DECLARE   @CRLF CHAR(1) = CHAR(10) + CHAR(13)
		, @dyn_dice_table VARCHAR(MAX)			= ''
		, @dyn_dice_column_list VARCHAR(MAX)	= ''
		, @dyn_dice_var_volumn_list VARCHAR(MAX) = ''
		, @dyn_dice_cross_apply VARCHAR(MAX) 	= ''
		, @dyn_dice_sum VARCHAR(MAX)            = ''
		, @dyn_roll_variables VARCHAR(MAX)     = ''
		, @dice_side_inside_cursor VARCHAR(400) = ''
		, @dice_table_inside_cursor VARCHAR(400) = ''
		, @alias VARCHAR(400)       = ''
		, @exec VARCHAR(MAX) = ''

--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~--
-- CURSOR START
DECLARE dice_cursor 
CURSOR LOCAL FOR

		SELECT number_of_sides 
			 , number_of_dice

		FROM @dice_staging

DECLARE @number_of_sides TINYINT
	  , @number_of_dice INT 

OPEN dice_cursor 

FETCH NEXT FROM dice_cursor 
INTO @number_of_sides
   , @number_of_dice

WHILE @@FETCH_STATUS = 0

BEGIN 
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~--
-- CURSOR GUTS
SET @dice_side_inside_cursor =  '@dice_with_' + CAST(@number_of_sides AS VARCHAR(10)) +'_s'
SET @dice_table_inside_cursor = '@table_for_' + CAST(@number_of_sides AS VARCHAR(10)) +'_s'

SET @dyn_dice_table +=  
			  @CRLF +	'DECLARE ' + @dice_side_inside_cursor + ' INT = ' + CAST(@number_of_sides AS VARCHAR(10))
			+ @CRLF +   'DECLARE ' + @dice_table_inside_cursor + '  AS TABLE (roll TINYINT)'
			+ @CRLF	+	'WHILE ' + @dice_side_inside_cursor + ' > 0'
			+ @CRLF +	'BEGIN INSERT INTO ' + @dice_table_inside_cursor + '(roll)'
			+ @CRLF +	'VALUES (' + @dice_side_inside_cursor + ')'
			+ @CRLF +	'SET ' + @dice_side_inside_cursor + ' -= 1 END'

WHILE @number_of_dice > 0
BEGIN 
SET @alias += 'x' 
SET @dyn_dice_column_list +=  @CRLF + ',' + @alias + 'roll = ' + @alias + '.roll'
SET @dyn_dice_var_volumn_list += @CRLF + ', @' + @alias +'roll = ' + @alias + 'roll'
SET @dyn_dice_sum += @alias + '.roll +'
SET @dyn_dice_cross_apply += @CRLF + 'CROSS APPLY ' + @dice_table_inside_cursor + ' ' + @alias
SET @dyn_roll_variables += ',@' + @alias + 'roll TINYINT'

SET @number_of_dice -= 1
END 

--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~--
-- CURSOR END
FETCH NEXT FROM dice_cursor 
INTO @number_of_sides
   , @number_of_dice

					END 
						CLOSE dice_cursor
						DEALLOCATE dice_cursor
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~--
-- CLEAN UP STRINGS
SELECT @dyn_dice_column_list = RIGHT(@dyn_dice_column_list, LEN(@dyn_dice_column_list) - 2)
SELECT @dyn_dice_var_volumn_list = RIGHT(@dyn_dice_var_volumn_list, LEN(@dyn_dice_var_volumn_list) - 2)
SELECT @dyn_dice_sum = LEFT(@dyn_dice_sum, LEN(@dyn_dice_sum) - 1)
SELECT @dyn_dice_cross_apply = RIGHT(@dyn_dice_cross_apply, LEN(@dyn_dice_cross_apply) - 12)
SELECT @dyn_roll_variables = RIGHT(@dyn_roll_variables, LEN(@dyn_roll_variables) - 1)
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~--
SET @exec = @dyn_dice_table
+ @CRLF + 'SELECT'
+ @CRLF + @dyn_dice_column_list 
+ @CRLF + ', sum = ' + @dyn_dice_sum
+ @CRLF + 'INTO #n'
+ @CRLF + 'FROM ' + @dyn_dice_cross_apply
+ @CRLF +
+ @CRLF + 'DECLARE @N INT = ( SELECT COUNT(*) FROM #n)'
+ @CRLF + 'DECLARE ' + @dyn_roll_variables
+ @CRLF + 'CREATE CLUSTERED INDEX roll ON #n ([sum])'
+ @CRLF +
+ @CRLF + ';WITH cte AS ('
+ @CRLF + 'SELECT [sum], ct = COUNT(*) FROM #n GROUP BY [sum] )'
+ @CRLF + 'SELECT [sum], ct, prob = ct/CAST(@N AS FLOAT) * 100 '
+ @CRLF + 'INTO #n_aggregate'
+ @CRLF + 'FROM cte'
+ @CRLF +
+ @CRLF +'SELECT TOP 1'
+ @CRLF + @dyn_dice_var_volumn_list
+ @CRLF + 'FROM #n'
+ @CRLF + 'ORDER BY NEWID()'
+ @CRLF +
+ @CRLF +'SELECT ' + REPLACE(@dyn_roll_variables, 'TINYINT', '') + ', ' + ' [sum] = @' + REPLACE(REPLACE(@dyn_dice_sum, '.', ''), '+', '+@')
+ @CRLF +
+ @CRLF +'SELECT prob_of_current_role = CAST(CAST(prob AS DECIMAL(4,2)) AS VARCHAR(5)) +''%'' FROM #n_aggregate WHERE [sum] = @' + REPLACE(REPLACE(@dyn_dice_sum, '.', ''), '+', '+@')
+ @CRLF +'SELECT min_prob = CAST(CAST(MIN(prob) AS DECIMAL(4,2)) AS VARCHAR(5)) + ''%'', max_prob = CAST(CAST(MAX(prob) AS DECIMAL(4,2)) AS VARCHAR(5)) + ''%'' FROM #n_aggregate'
+ @CRLF +
+ @CRLF + 'DROP TABLE #n'
+ @CRLF + 'DROP TABLE #n_aggregate'

--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~--

--SELECT  (@exec)
=======
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~--
/*
-----------------------------------------------
---|D|DDDD-----|D|-----|DDDDDD----|D|DDDDDD----
---|D|----D----|D|----|D----------|D|----------
---|D|-----D---|D|---|D-----------|D|DDDDDD----
---|D|----D----|D|----|D----------|D|----------
---|D|DDDD-----|D|-----|DDDDDD----|D|DDDDDD----
-----------------------------------------------
*/
-- 2/3/2017 - Erich Seifert
-- simulates a rolls of however many dice with however many sides
-- tells you probablity of rolling that combination
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~--
DECLARE @dice_staging 
AS TABLE 
(
   number_of_sides TINYINT
 , number_of_dice INT
)

INSERT INTO @dice_staging
( 
	number_of_sides -- number of rolls in table variable representing dice
  , number_of_dice  -- number of cross applies of above table variable
) 
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~--
VALUES  (3, 2),
		(5, 1)

IF (SELECT SUM(number_of_dice) FROM @dice_staging) > 11
BEGIN
            RAISERROR('Cartesian overload',16,1);
            RETURN; 
END 

IF EXISTS (SELECT 1 FROM @dice_staging GROUP BY number_of_sides HAVING COUNT(*) > 1)
BEGIN
            RAISERROR('Do not select two different dice with same amount of sides, combine them',16,1);
            RETURN; 
END 


--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~--
-- DYNAMIC SQL GOODIES
DECLARE   @CRLF CHAR(1) = CHAR(10) + CHAR(13)
		, @dyn_dice_table VARCHAR(MAX)			= ''
		, @dyn_dice_column_list VARCHAR(MAX)	= ''
		, @dyn_dice_var_volumn_list VARCHAR(MAX) = ''
		, @dyn_dice_cross_apply VARCHAR(MAX) 	= ''
		, @dyn_dice_sum VARCHAR(MAX)            = ''
		, @dyn_roll_variables VARCHAR(MAX)     = ''
		, @dice_side_inside_cursor VARCHAR(400) = ''
		, @dice_table_inside_cursor VARCHAR(400) = ''
		, @alias VARCHAR(400)       = ''
		, @exec VARCHAR(MAX) = ''

--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~--
-- CURSOR START
DECLARE dice_cursor 
CURSOR LOCAL FOR

		SELECT number_of_sides 
			 , number_of_dice

		FROM @dice_staging

DECLARE @number_of_sides TINYINT
	  , @number_of_dice INT 

OPEN dice_cursor 

FETCH NEXT FROM dice_cursor 
INTO @number_of_sides
   , @number_of_dice

WHILE @@FETCH_STATUS = 0

BEGIN 
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~--
-- CURSOR GUTS
SET @dice_side_inside_cursor =  '@dice_with_' + CAST(@number_of_sides AS VARCHAR(10)) +'_s'
SET @dice_table_inside_cursor = '@table_for_' + CAST(@number_of_sides AS VARCHAR(10)) +'_s'

SET @dyn_dice_table +=  
			  @CRLF +	'DECLARE ' + @dice_side_inside_cursor + ' INT = ' + CAST(@number_of_sides AS VARCHAR(10))
			+ @CRLF +   'DECLARE ' + @dice_table_inside_cursor + '  AS TABLE (roll TINYINT)'
			+ @CRLF	+	'WHILE ' + @dice_side_inside_cursor + ' > 0'
			+ @CRLF +	'BEGIN INSERT INTO ' + @dice_table_inside_cursor + '(roll)'
			+ @CRLF +	'VALUES (' + @dice_side_inside_cursor + ')'
			+ @CRLF +	'SET ' + @dice_side_inside_cursor + ' -= 1 END'

WHILE @number_of_dice > 0
BEGIN 
SET @alias += 'x' 
SET @dyn_dice_column_list +=  @CRLF + ',' + @alias + 'roll = ' + @alias + '.roll'
SET @dyn_dice_var_volumn_list += @CRLF + ', @' + @alias +'roll = ' + @alias + 'roll'
SET @dyn_dice_sum += @alias + '.roll +'
SET @dyn_dice_cross_apply += @CRLF + 'CROSS APPLY ' + @dice_table_inside_cursor + ' ' + @alias
SET @dyn_roll_variables += ',@' + @alias + 'roll TINYINT'

SET @number_of_dice -= 1
END 

--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~--
-- CURSOR END
FETCH NEXT FROM dice_cursor 
INTO @number_of_sides
   , @number_of_dice

					END 
						CLOSE dice_cursor
						DEALLOCATE dice_cursor
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~--
-- CLEAN UP STRINGS
SELECT @dyn_dice_column_list = RIGHT(@dyn_dice_column_list, LEN(@dyn_dice_column_list) - 2)
SELECT @dyn_dice_var_volumn_list = RIGHT(@dyn_dice_var_volumn_list, LEN(@dyn_dice_var_volumn_list) - 2)
SELECT @dyn_dice_sum = LEFT(@dyn_dice_sum, LEN(@dyn_dice_sum) - 1)
SELECT @dyn_dice_cross_apply = RIGHT(@dyn_dice_cross_apply, LEN(@dyn_dice_cross_apply) - 12)
SELECT @dyn_roll_variables = RIGHT(@dyn_roll_variables, LEN(@dyn_roll_variables) - 1)
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~--
SET @exec = @dyn_dice_table
+ @CRLF + 'SELECT'
+ @CRLF + @dyn_dice_column_list 
+ @CRLF + ', sum = ' + @dyn_dice_sum
+ @CRLF + 'INTO #n'
+ @CRLF + 'FROM ' + @dyn_dice_cross_apply
+ @CRLF +
+ @CRLF + 'DECLARE @N INT = ( SELECT COUNT(*) FROM #n)'
+ @CRLF + 'DECLARE ' + @dyn_roll_variables
+ @CRLF + 'CREATE CLUSTERED INDEX roll ON #n ([sum])'
+ @CRLF +
+ @CRLF + ';WITH cte AS ('
+ @CRLF + 'SELECT [sum], ct = COUNT(*) FROM #n GROUP BY [sum] )'
+ @CRLF + 'SELECT [sum], ct, prob = ct/CAST(@N AS FLOAT) * 100 '
+ @CRLF + 'INTO #n_aggregate'
+ @CRLF + 'FROM cte'
+ @CRLF +
+ @CRLF +'SELECT TOP 1'
+ @CRLF + @dyn_dice_var_volumn_list
+ @CRLF + 'FROM #n'
+ @CRLF + 'ORDER BY NEWID()'
+ @CRLF +
+ @CRLF +'SELECT ' + REPLACE(@dyn_roll_variables, 'TINYINT', '') + ', ' + ' [sum] = @' + REPLACE(REPLACE(@dyn_dice_sum, '.', ''), '+', '+@')
+ @CRLF +
+ @CRLF +'SELECT prob_of_current_role = CAST(CAST(prob AS DECIMAL(4,2)) AS VARCHAR(5)) +''%'' FROM #n_aggregate WHERE [sum] = @' + REPLACE(REPLACE(@dyn_dice_sum, '.', ''), '+', '+@')
+ @CRLF +'SELECT min_prob = CAST(CAST(MIN(prob) AS DECIMAL(4,2)) AS VARCHAR(5)) + ''%'', max_prob = CAST(CAST(MAX(prob) AS DECIMAL(4,2)) AS VARCHAR(5)) + ''%'' FROM #n_aggregate'
+ @CRLF +
+ @CRLF + 'DROP TABLE #n'
+ @CRLF + 'DROP TABLE #n_aggregate'

--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~--

--SELECT  (@exec)
>>>>>>> 8a819bfa08327b6d7e13da7847f240362db566d4
EXEC (@exec)