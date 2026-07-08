/* Проект «Секреты Тёмнолесья»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок.
 * 
 * Автор: Мельников Даниил
 * Дата: 10.12.2025 г.
*/


-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков

-- 1.1. Доля платящих пользователей по всем данным:
SELECT
	COUNT(u.id) AS total_id_count,
	SUM(u.payer) AS total_payer_count,
	ROUND(AVG(u.payer), 2) AS payer_share
FROM fantasy.users u;

-- Результат:
-- total_id_count|total_payer_count|payer_share|
-- --------------+-----------------+-----------+
--          22214|             3929|       0.18|

-- 1.2. Доля платящих пользователей в разрезе расы персонажа:
SELECT
	race,
	SUM(u.payer) AS total_payer_count,
	COUNT(u.id) AS total_id_count,
	ROUND(AVG(u.payer), 2) AS payer_share
FROM fantasy.users u
LEFT JOIN fantasy.race USING(race_id)
GROUP BY race;

-- Результат:
-- race    |total_payer_count|total_id_count|payer_share|
-- --------+-----------------+--------------+-----------+
-- Angel   |              229|          1327|       0.17|
-- Elf     |              427|          2501|       0.17|
-- Demon   |              238|          1229|       0.19|
-- Orc     |              636|          3619|       0.18|
-- Human   |             1114|          6328|       0.18|
-- Northman|              626|          3562|       0.18|
-- Hobbit  |              659|          3648|       0.18|

-- Общая доля платящих игроков в игре составляет 18%. В разрезе расс значение варьируется незначительно - от 17% до 19%.
-- Следовательно выбранная расса персонажа напрямую не влияют на внутриигровые покупки.


-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:
SELECT
	COUNT(e.transaction_id) AS purchase_count,
	SUM(e.amount) AS total_sum,
	MIN(e.amount) AS min_amount,
	MAX(e.amount) AS max_amount,
	ROUND(AVG(e.amount)::NUMERIC, 2) AS avg_amount,
	PERCENTILE_DISC(0.50) WITHIN GROUP (ORDER BY e.amount) AS mediana,
	STDDEV(e.amount) AS stand_dev
FROM fantasy.events e 

-- Результат:
-- purchase_count|total_sum|min_amount|max_amount|avg_amount|mediana|stand_dev        |
-- --------------+---------+----------+----------+----------+-------+-----------------+
--        1307678|686615040|       0.0|  486615.1|    525.69|  74.86|2517.345444427788|

-- Общее количество покупок составило более 1.3 миллиона с общей суммой более 686 миллионов внутриигровой валюты. Минимальная стоимость покупки равна
-- нулю - это говорит о том, что в игре пристутствуют бесплатные покупки (транзакции). Самая дорогая покупка - 486615 внутриигровой валюты.
-- Сильно различаются значения среднего и медианы, что говорит об аномальных суммах покупок (бесплатные транзакции и дорогие покупки).
-- Разброс суммы от среднего огромный - 2500 единиц внутриигровой валюты.


-- 2.2: Аномальные нулевые покупки:
WITH free_purchase AS (
	SELECT
		COUNT(transaction_id) AS total_free_purchase
	FROM fantasy.events
	WHERE amount = 0
),
total_purchases AS (
	SELECT
		COUNT(transaction_id) AS total_purchases
	FROM fantasy.events
)
SELECT
	total_free_purchase,
	ROUND(total_free_purchase / total_purchases::NUMERIC * 100, 2) AS free_purchase_share -- доля нулевых покупок
FROM free_purchase, total_purchases;

-- Результат:
-- total_free_purchase|free_purchase_share|
-- -------------------+-------------------+
--                 907|               0.07|

-- Всего 907 нулевых покупок, их доля от общего количества покупок составила 7%.


-- 2.3: Популярные эпические предметы:
WITH purchase_per_item AS( 
	SELECT
		game_items,
		COUNT(transaction_id) AS total_purchase_per_item
	FROM fantasy.events
	LEFT JOIN fantasy.items ON events.item_code = items.item_code 
	WHERE amount > 0
	GROUP BY game_items
),
total_purchases AS( 
	SELECT
		COUNT(transaction_id) AS total_transactions
	FROM fantasy.events
	WHERE amount > 0
),
user_per_item AS ( 
	SELECT
		game_items,
		COUNT(DISTINCT tech_nickname) AS users_count
	FROM fantasy.users
	LEFT JOIN fantasy.events ON users.id = events.id
	LEFT JOIN fantasy.items ON events.item_code = items.item_code
	GROUP BY game_items
),
total_users AS(
	SELECT
		COUNT(DISTINCT events.id) AS buying_users
	FROM fantasy.users
	LEFT JOIN fantasy.events ON users.id = events.id
	WHERE amount > 0
)
SELECT
	game_items,
	total_purchase_per_item, 
	ROUND((total_purchase_per_item::NUMERIC / (SELECT total_transactions FROM total_purchases)) * 100, 2) AS item_share,
	ROUND((users_count::NUMERIC / (SELECT buying_users FROM total_users)) * 100, 2) AS user_share
FROM purchase_per_item
LEFT JOIN user_per_item USING (game_items)
ORDER BY total_purchase_per_item DESC;

-- Результат:
-- game_items               |total_purchase_per_item|item_share|user_share|
-- -------------------------+-----------------------+----------+----------+
-- Book of Legends          |                1004516|     76.87|     88.42|
-- Bag of Holding           |                 271875|     20.81|     86.77|
-- Necklace of Wisdom       |                  13828|      1.06|     11.80|
-- Gems of Insight          |                   3833|      0.29|      6.71|
-- Treasure Map             |                   3183|      0.24|      5.94|
-- и т.д.

-- Самым популярным предметом является Книга Легенд, доля ее покупок от общего числа составляет 76.87%, и ею владеют 88.42% игроков
-- Также популярна Сумка Обладания, доля ее покупок составляет 20.81%, а владеют ею 86.77% пользователей.
-- Доля покупок остальных предметов составляет 1% и меньше. Владеют такими предметами от 11.8% игроков и менее.


-- Часть 2. Решение ad hoc-задачи
-- Задача: Зависимость активности игроков от расы персонажа:
WITH user_reg AS(
	SELECT
		race_id,
		-- Зарегистрированные пользователи:
		COUNT(id) AS reg_users -- зарегистрированные пользователи
	FROM fantasy.users
	GROUP BY race_id
), 
buyer_users AS(
	SELECT
		race_id,
		-- Покупающие пользователи:
		COUNT(DISTINCT events.id) AS buying_users,
		-- Платящие пользователи:
        COUNT(DISTINCT events.id) FILTER(WHERE payer=1) AS paying_users
	FROM fantasy.events
	LEFT JOIN fantasy.users ON events.id = users.id
	WHERE transaction_id IS NOT NULL
	GROUP BY race_id
),
user_activity AS(
	SELECT
		race_id,
		race,
		COUNT(transaction_id) AS purchase_count,
		SUM(amount) AS total_amount
	FROM fantasy.events
	LEFT JOIN fantasy.users ON events.id = users.id
	LEFT JOIN fantasy.race USING(race_id)
	WHERE transaction_id IS NOT NULL AND amount > 0
	GROUP BY race_id, race
)
SELECT
	race, 
	reg_users,
	buying_users,
	paying_users,
	-- Доля покупающих от общего:
	ROUND(COUNT(DISTINCT events.id)::NUMERIC / reg_users * 100, 2) AS buyer_share,
	-- Доля платящих от покупающих:
	ROUND(COUNT(DISTINCT events.id) FILTER(WHERE payer=1)::NUMERIC / COUNT(DISTINCT events.id), 2) * 100 AS payer_share,
	-- Среднее количество покупок на игрока:
	ROUND(purchase_count / COUNT(DISTINCT events.id), 2) AS avg_purchase_per_user,
	-- Средняя суммарная стоимость всех покупок на игрока:
	ROUND(total_amount::NUMERIC / COUNT(DISTINCT events.id), 2) AS avg_cost_per_user,
	-- Средняя стоимость покупки:
	ROUND(total_amount::NUMERIC / purchase_count, 2) AS avg_cost_per_purchase
FROM user_activity
LEFT JOIN buyer_users USING(race_id)
LEFT JOIN user_reg USING(race_id)
LEFT JOIN fantasy.users USING (race_id)
LEFT JOIN fantasy.events ON events.id = users.id
GROUP BY
	race,
	reg_users,
	buying_users,
	paying_users,
	purchase_count,
	total_amount;

-- Результат:
-- race    |reg_users|buying_users|paying_users|buyer_share|payer_share|avg_purchase_per_user|avg_cost_per_user|avg_cost_per_purchase|
-- --------+---------+------------+------------+-----------+-----------+---------------------+-----------------+---------------------+
-- Angel   |     1327|         820|         137|      61.79|      17.00|               106.00|         48664.63|               455.64|
-- Demon   |     1229|         737|         147|      59.97|      20.00|                77.00|         41194.44|               529.02|
-- Elf     |     2501|        1543|         251|      61.70|      16.00|                78.00|         53761.24|               682.33|
-- Hobbit  |     3648|        2267|         401|      62.14|      18.00|                86.00|         47600.79|               552.91|
-- Human   |     6328|        3921|         706|      61.96|      18.00|               121.00|         48933.69|               403.07|
-- Northman|     3562|        2229|         406|      62.58|      18.00|                82.00|         62519.07|               761.48|
-- Orc     |     3619|        2276|         396|      62.89|      17.00|                81.00|         41761.69|               510.92|

-- Наиболее популярная раса среди игроков - Человек. Количество пользователей в разрезе других рас как минимум в два раза меньше.
-- Доли покупающих пользователей в разресе расы примерно равны - от 59.97% до 62.89%. Аналогично и доли платящих пользователей - от 17% до 20% игроков.

-- Обращают внимание высокие показатели среднего количества покупок у рас Ангела и Человека (106 и 121 шт соответственно), т.е. этим расам нужно
-- больше внутриигровых покупок для прохождения игры.

-- Наблюдается аномально высокая средняя суммарная стоимость покупок у расы Северянина, а также у расы Эльфа (62519 и 53761 внутриигровой валюты
-- соответственно), т.е. игрокам данных рас приходится тратить большую сумму для прохождения игры. Это видно и исходя из средней стоимости покупки
-- (761.48 и 682.33).


-- Общие выводы и рекомендации:
-- Гипотеза о том, что прохождение игры за персонажей разных рас требует примерно равного количества покупок эпических предметов не подтверждается.
-- При равных показателях платящих пользователей, игрока за Англеов и Людей требуется совершать большее количество покупок, а игрокам за Северян и
-- Эльфов тратить большую сумму, чем другим, т.к. стоимость предметов для этих рас выше.
-- Рекомендовано скореектировать количество и стоимости эпических предметов в игре, чтобы игроки с персонажами разных рас имели одинаковые возможности
-- пройти игру.