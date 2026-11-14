--
-- PostgreSQL database dump
--

-- Dumped from database version 17.2
-- Dumped by pg_dump version 17.2

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: buldakov_food; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA buldakov_food;


--
-- Name: courier_status; Type: TYPE; Schema: buldakov_food; Owner: -
--

CREATE TYPE buldakov_food.courier_status AS ENUM (
    'свободен',
    'занят',
    'на_доставке',
    'уволен'
);


--
-- Name: order_status; Type: TYPE; Schema: buldakov_food; Owner: -
--

CREATE TYPE buldakov_food.order_status AS ENUM (
    'создан',
    'готовится',
    'в_доставке',
    'доставлен',
    'отменён'
);


--
-- Name: pay_status; Type: TYPE; Schema: buldakov_food; Owner: -
--

CREATE TYPE buldakov_food.pay_status AS ENUM (
    'ожидает',
    'оплачен',
    'ошибка'
);


--
-- Name: payment_status; Type: TYPE; Schema: buldakov_food; Owner: -
--

CREATE TYPE buldakov_food.payment_status AS ENUM (
    'успех',
    'ошибка',
    'в_обработке'
);


--
-- Name: payment_type; Type: TYPE; Schema: buldakov_food; Owner: -
--

CREATE TYPE buldakov_food.payment_type AS ENUM (
    'карта',
    'наличные',
    'безнал'
);


--
-- Name: product_status; Type: TYPE; Schema: buldakov_food; Owner: -
--

CREATE TYPE buldakov_food.product_status AS ENUM (
    'доступно',
    'нет_в_наличии',
    'архив'
);


--
-- Name: restaurant_status; Type: TYPE; Schema: buldakov_food; Owner: -
--

CREATE TYPE buldakov_food.restaurant_status AS ENUM (
    'активен',
    'неактивен'
);


--
-- Name: review_entity_type; Type: TYPE; Schema: buldakov_food; Owner: -
--

CREATE TYPE buldakov_food.review_entity_type AS ENUM (
    'блюдо',
    'ресторан',
    'заказ'
);


--
-- Name: add_product(character varying, uuid, numeric, uuid, text, numeric, buldakov_food.product_status, text); Type: PROCEDURE; Schema: buldakov_food; Owner: -
--

CREATE PROCEDURE buldakov_food.add_product(IN product_name character varying, IN product_category_id uuid, IN price numeric, IN restaurant_id uuid, IN photo_url text, IN rating numeric, IN status buldakov_food.product_status, IN description text)
    LANGUAGE plpgsql
    AS $$
DECLARE
    new_product_id UUID;
BEGIN
	if not exists (
	select 1 from buldakov_food.restaurant r
	where r.restaurant_id = add_product.restaurant_id
	) then 
		raise exception 'Такого ресторана нет';
	end if;

	if not exists (
	select 1 from buldakov_food.product_category pc
	where pc.product_category_id = add_product.product_category_id
	) then 
		raise exception 'Такой категории нет';
	end if;

	new_product_id := exts.uuid_generate_v4();
    insert into buldakov_food.product values(
		new_product_id,
		product_name,
		product_category_id,
		price,
		restaurant_id,
		photo_url,
		rating,
		status,
		description
	);
END;
$$;


--
-- Name: courier_salary(); Type: PROCEDURE; Schema: buldakov_food; Owner: -
--

CREATE PROCEDURE buldakov_food.courier_salary()
    LANGUAGE plpgsql
    AS $$
begin
	INSERT INTO buldakov_food.courier_pay
	SELECT
	    EXTRACT(YEAR FROM CURRENT_DATE)::INT,
	    EXTRACT(MONTH FROM CURRENT_DATE)::INT,
	    c.courier_id,
	    coalesce(cp.coefficient_used,c.coefficient) * COALESCE(SUM(o.commission), 0),
	    coalesce(cp.coefficient_used,c.coefficient)
	FROM buldakov_food.courier c
	LEFT JOIN buldakov_food."order" o
	    ON c.courier_id = o.courier_id
	    AND o.status = 'доставлен'
	    AND o.delivery_timestamp >= date_trunc('month', CURRENT_DATE)
	    AND o.delivery_timestamp < date_trunc('month', CURRENT_DATE) + INTERVAL '1 month'
	LEFT JOIN buldakov_food.courier_pay cp
	    ON c.courier_id = cp.courier_id
	    AND cp.year = EXTRACT(YEAR FROM CURRENT_DATE)::INT
	    AND cp.month = EXTRACT(MONTH FROM CURRENT_DATE)::INT
	GROUP BY c.courier_id, c.coefficient, cp.coefficient_used
	ON CONFLICT (year, month, courier_id)
	DO UPDATE SET
	    amount = EXCLUDED.amount,
	    coefficient_used = EXCLUDED.coefficient_used;
	update buldakov_food.courier c 
	set coefficient = CASE
		    WHEN stats.delivered_count <= 150 THEN 0.1
		    WHEN stats.delivered_count <= 250 THEN 0.2
		    WHEN stats.delivered_count <= 500 THEN 0.3
		    ELSE 0.5
		END
	FROM (
	    SELECT
	        c.courier_id,
	        COUNT(o.order_id) AS delivered_count
	    FROM buldakov_food.courier c
	    LEFT JOIN buldakov_food."order" o
	        ON o.courier_id = c.courier_id
	        AND o.status = 'доставлен'
	        AND o.delivery_timestamp >= date_trunc('month', CURRENT_DATE)
	        AND o.delivery_timestamp < date_trunc('month', CURRENT_DATE) + INTERVAL '1 month'
	    GROUP BY c.courier_id
	) stats
	WHERE c.courier_id = stats.courier_id
	  AND c.status <> 'уволен';
END;
$$;


--
-- Name: erase_test_data(); Type: PROCEDURE; Schema: buldakov_food; Owner: -
--

CREATE PROCEDURE buldakov_food.erase_test_data()
    LANGUAGE plpgsql
    AS $$
begin
	delete from buldakov_food.review;
	delete from buldakov_food.payment;
	delete from buldakov_food.order_structure;
	delete from buldakov_food.courier_pay;
	delete from buldakov_food."order";
	delete from buldakov_food.product;
	delete from buldakov_food.restaurant;
	delete from buldakov_food.client_address;
	delete from buldakov_food.address;
	delete from buldakov_food.courier;
	delete from buldakov_food.client;
	delete from buldakov_food.product_category;
end;
$$;


--
-- Name: generate_addresses(integer, uuid[], uuid[]); Type: PROCEDURE; Schema: buldakov_food; Owner: -
--

CREATE PROCEDURE buldakov_food.generate_addresses(IN p_value integer, INOUT restaurant_address_ids uuid[], INOUT client_address_ids uuid[])
    LANGUAGE plpgsql
    AS $$
DECLARE
    new_address_id UUID;
    new_apartment VARCHAR(20);
BEGIN
    IF p_value <= 0 THEN
        RAISE EXCEPTION 'Значение должно быть больше нуля';
    END IF;
	restaurant_address_ids := ARRAY[]::UUID[];
    client_address_ids := ARRAY[]::UUID[];
	--
	--
	for i in 1..p_value*5 loop
    IF FLOOR(RANDOM() * 2)::INT = 1 THEN
        new_apartment := NULL;
    ELSE
        new_apartment := FLOOR(RANDOM() * 200 + 1)::text;
    END IF;
	-- айдишка адреса, потом для связи с ресторанами понадобится
	new_address_id := exts.uuid_generate_v4();
	insert into buldakov_food.address values 
	(	new_address_id,
		'street_' || exts.uuid_generate_v4()::text,
		FLOOR(RANDOM()*1000000 + 1)::text,
		new_apartment
	);
	if i <=p_value then
		restaurant_address_ids := array_append(
			restaurant_address_ids,
			new_address_id
		);
	else client_address_ids := array_append(
			client_address_ids,
			new_address_id
		);
	end if;
end loop;
end;
$$;


--
-- Name: generate_base_data(integer, uuid[], uuid[], uuid[]); Type: PROCEDURE; Schema: buldakov_food; Owner: -
--

CREATE PROCEDURE buldakov_food.generate_base_data(IN p_value integer, INOUT client_ids uuid[], INOUT courier_ids uuid[], INOUT product_category_ids uuid[])
    LANGUAGE plpgsql
    AS $$
DECLARE
    new_client_id UUID;
    new_courier_id UUID;
    new_product_category_id UUID;

    new_phone VARCHAR(20);
    is_exists BOOLEAN;

    new_courier_status buldakov_food.courier_status;
    hire_date DATE;
    dismissal_date DATE;
BEGIN
RAISE NOTICE 'Передано значение: %', p_value;
	if p_value <=0 then
	RAISE EXCEPTION 'Значение должно быть больше нуля';
	end if;
    client_ids := ARRAY[]::UUID[];
    courier_ids := ARRAY[]::UUID[];
    product_category_ids := ARRAY[]::UUID[];

for i in 1..p_value loop
	--Генерация клиента
	--Генерация номера телефона
	loop
		new_phone := '+7' || LPAD(FLOOR(RANDOM() * 1000000000)::text, 10, '0');
		select exists(select 1 from buldakov_food.client where phone_number = new_phone) into is_exists;
		exit when not is_exists;
	end loop;
	--Генерация айдишки для последующей связи с адресами
	new_client_id := exts.uuid_generate_v4();
	client_ids := array_append(client_ids,new_client_id);
	insert into buldakov_food.client values 
	(	new_client_id,
		'client_' || exts.uuid_generate_v4()::text,
		md5(random()::text),
		new_phone
	);
	--Генерация курьера
	loop 
		new_phone := '7' || LPAD(FLOOR(RANDOM() * 1000000000)::text, 10, '0');
		select exists(select 1 from buldakov_food.courier where phone_number = new_phone) into is_exists;
		exit when not is_exists;
	end loop;
	--Статус курьеру выдаем, с проверкой что хотя бы 1 у нас не уволенный
	-- Хотя бы 1 курьер будет работать у нас
	if i = 1 then
		new_courier_status := 'свободен';
		hire_date := CURRENT_DATE-180;
		dismissal_date := NULL;
	else
		new_courier_status :=
		    (enum_range(NULL::buldakov_food.courier_status))
		    [floor(random() * 4 + 1)::INT];
		hire_date := CURRENT_DATE - floor(random()*180)::int;
		--Дата увольнения если он уволенный
		if new_courier_status = 'уволен' then
			dismissal_date := hire_date + floor(random() * (CURRENT_DATE- hire_date +1))::int;
		else dismissal_date := null;
		end if;
	end if;
	
	new_courier_id := exts.uuid_generate_v4();
	courier_ids = array_append(courier_ids, new_courier_id);
	insert into buldakov_food.courier values 
	(	new_courier_id,
		'courier_' || exts.uuid_generate_v4()::text,
		new_phone,
		new_courier_status,
		hire_date,
		dismissal_date,
		0.1
	);
	--категории продуктов
	new_product_category_id := exts.uuid_generate_v4();
	product_category_ids :=
            array_append(product_category_ids, new_product_category_id);
	insert into buldakov_food.product_category values (
		new_product_category_id,
		'product_cat_' || exts.uuid_generate_v4()::text
	);
end loop;
end;
$$;


--
-- Name: generate_client_addresses(integer, uuid[], uuid[]); Type: PROCEDURE; Schema: buldakov_food; Owner: -
--

CREATE PROCEDURE buldakov_food.generate_client_addresses(IN p_value integer, IN client_ids uuid[], IN client_address_ids uuid[])
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF p_value <= 0 THEN
        RAISE EXCEPTION 'Количество клиентов должно быть больше нуля';
    END IF;
    FOR i IN 1..p_value LOOP
        FOR j IN 1..4 LOOP
            INSERT INTO buldakov_food.client_address VALUES
            (
                client_ids[i],
                client_address_ids[(i-1)*4+j]
            );
        END LOOP;
    END LOOP;
    RAISE NOTICE 'Было создано: % связей клиента и адреса', p_value * 4;
END;
$$;


--
-- Name: generate_courier_pay(uuid[]); Type: PROCEDURE; Schema: buldakov_food; Owner: -
--

CREATE PROCEDURE buldakov_food.generate_courier_pay(IN courier_ids uuid[])
    LANGUAGE plpgsql
    AS $$
DECLARE
    current_courier_id UUID;

    current_coefficient NUMERIC;
    new_coefficient NUMERIC;

    current_dismissal_date DATE;

    month_start DATE;
    month_end DATE;

    delivered_orders_count INT;
    total_commission NUMERIC;
    payment_amount NUMERIC;

BEGIN

    -- Перебираем всех созданных курьеров
    FOREACH current_courier_id IN ARRAY courier_ids LOOP

        -- Получаем коэффициент и дату увольнения
        SELECT coefficient, dismissal_date
        FROM buldakov_food.courier
        WHERE courier_id = current_courier_id
        INTO current_coefficient, current_dismissal_date;

        -- Последние 6 месяцев
        FOR i IN 0..5 LOOP

            month_start :=
                (
                    DATE_TRUNC('month', CURRENT_DATE)
                    - (5 - i) * INTERVAL '1 month'
                )::DATE;

            month_end :=
                (month_start + INTERVAL '1 month')::DATE;

            -- Количество доставленных заказов и сумма комиссий
            SELECT
                COUNT(*),
                COALESCE(SUM(commission), 0)
            FROM buldakov_food."order"
            WHERE courier_id = current_courier_id
                AND status = 'доставлен'
                AND delivery_timestamp >= month_start
                AND delivery_timestamp < month_end
            INTO delivered_orders_count, total_commission;

            -- Рассчитываем выплату
            payment_amount :=
                ROUND(total_commission * current_coefficient, 2);

            -- Сохраняем выплату
            INSERT INTO buldakov_food.courier_pay VALUES (
                EXTRACT(YEAR FROM month_start)::INT,
                EXTRACT(MONTH FROM month_start)::INT,
                current_courier_id,
                payment_amount,
                current_coefficient
            );

            -- Рассчитываем коэффициент на следующий месяц
            IF delivered_orders_count <= 150 THEN
                new_coefficient := 0.1;

            ELSIF delivered_orders_count <= 250 THEN
                new_coefficient := 0.2;

            ELSIF delivered_orders_count <= 500 THEN
                new_coefficient := 0.3;

            ELSE
                new_coefficient := 0.5;

            END IF;

            -- Обновляем коэффициент, если месяц завершён
            -- и курьер не был уволен в течение этого месяца
            IF month_end <= CURRENT_DATE
                AND (
                    current_dismissal_date IS NULL
                    OR current_dismissal_date >= month_end
                )
            THEN

                current_coefficient := new_coefficient;

                UPDATE buldakov_food.courier
                SET coefficient = new_coefficient
                WHERE courier_id = current_courier_id;

            END IF;

        END LOOP;

    END LOOP;

END;
$$;


--
-- Name: generate_orders(integer, uuid[], uuid[], uuid[], uuid[]); Type: PROCEDURE; Schema: buldakov_food; Owner: -
--

CREATE PROCEDURE buldakov_food.generate_orders(IN p_value integer, IN client_ids uuid[], IN courier_ids uuid[], IN restaurant_ids uuid[], INOUT order_ids uuid[])
    LANGUAGE plpgsql
    AS $$
DECLARE
    new_order_id UUID;
    new_order_timestamp TIMESTAMP;
    new_order_client_id UUID;
    new_order_address_id UUID;
    new_order_restaurant_id UUID;
    new_order_courier_id UUID;

    order_product_count INT;
    order_product_ids UUID[];
    product_quantities NUMERIC[];

    new_order_amount NUMERIC;
    new_commission NUMERIC;
    new_total_amount NUMERIC;

    new_product_id UUID;
    new_product_price NUMERIC;
    new_quantity NUMERIC;

    first_product_id UUID;
    first_product_price NUMERIC;
    first_product_quantity NUMERIC;

    new_order_status buldakov_food.order_status;
    new_pay_status buldakov_food.pay_status;
    new_delivery_timestamp TIMESTAMP;

    status_roll INT;
BEGIN
	order_ids := ARRAY[]::UUID[];
    FOR i IN 1..p_value*5 LOOP

        -- Время заказа
        new_order_timestamp :=
            CURRENT_TIMESTAMP - RANDOM() * INTERVAL '180 days';

        -- ID заказа
        new_order_id := exts.uuid_generate_v4();

        -- ID клиента
        new_order_client_id :=
            client_ids[FLOOR(RANDOM()*p_value)::INT+1];

        -- ID адреса
        SELECT address_id
        FROM buldakov_food.client_address
        WHERE client_id = new_order_client_id
        ORDER BY RANDOM()
        LIMIT 1
        INTO new_order_address_id;

        -- ID ресторана
        new_order_restaurant_id :=
            restaurant_ids[FLOOR(RANDOM()*p_value)::INT+1];

        -- Подбор курьера
        SELECT courier_id
        FROM buldakov_food.courier
        WHERE (
            hire_date <= new_order_timestamp::DATE
            AND (
                dismissal_date IS NULL
                OR dismissal_date >= new_order_timestamp::DATE
            )
            AND courier_id = ANY(courier_ids)
        )
        ORDER BY RANDOM()
        LIMIT 1
        INTO new_order_courier_id;

        -- Подбираем товары для заказа
        order_product_count := FLOOR(RANDOM()*5)::INT + 1;

        SELECT ARRAY(
            SELECT product_id
            FROM buldakov_food.product
            WHERE restaurant_id = new_order_restaurant_id
            ORDER BY RANDOM()
            LIMIT order_product_count
        )
        INTO order_product_ids;

        new_order_amount := 0;
        first_product_id := NULL;
        product_quantities := ARRAY[]::NUMERIC[];

        FOREACH new_product_id IN ARRAY order_product_ids LOOP

            SELECT price
            FROM buldakov_food.product
            WHERE product_id = new_product_id
            INTO new_product_price;

            new_quantity := FLOOR(RANDOM() * 3 + 1);

            IF first_product_id IS NULL THEN
                first_product_id := new_product_id;
                first_product_price := new_product_price;
                first_product_quantity := new_quantity;
            END IF;

            product_quantities :=
                ARRAY_APPEND(product_quantities, new_quantity);

            new_order_amount :=
                new_order_amount + new_product_price * new_quantity;

        END LOOP;

        -- Сумма заказа до 1000 рублей
        WHILE new_order_amount < 1000 LOOP

            first_product_quantity := first_product_quantity + 1;

            new_order_amount :=
                new_order_amount + first_product_price;

        END LOOP;

        product_quantities[1] := first_product_quantity;

        -- Комиссия и итоговая сумма
        new_commission := new_order_amount * 0.1;
        new_total_amount := new_order_amount + new_commission;

        -- Статус заказа
        status_roll := FLOOR(RANDOM()*10)::INT + 1;

        IF status_roll <= 6 THEN
            new_order_status := 'доставлен';
            new_pay_status := 'оплачен';

            new_delivery_timestamp := least(
                new_order_timestamp + RANDOM() * INTERVAL '24 hours',
					CURRENT_TIMESTAMP
				);
        ELSIF status_roll = 7 THEN
            new_order_status := 'отменён';
            new_pay_status := 'ошибка';
            new_delivery_timestamp := NULL;

        ELSIF status_roll = 8 THEN
            new_order_status := 'создан';
            new_pay_status := 'ожидает';
            new_delivery_timestamp := NULL;

        ELSIF status_roll = 9 THEN
            new_order_status := 'готовится';
            new_pay_status := 'оплачен';
            new_delivery_timestamp := NULL;

        ELSE
            new_order_status := 'в_доставке';
            new_pay_status := 'ожидает';
            new_delivery_timestamp := NULL;

        END IF;

        -- Создаём заказ
        INSERT INTO buldakov_food."order" VALUES (
            new_order_id,
            new_order_courier_id,
            new_order_client_id,
            new_order_address_id,
            new_order_restaurant_id,
            new_order_timestamp,
            new_delivery_timestamp,
            new_order_amount,
            new_commission,
            new_total_amount,
            new_order_status,
            new_pay_status,
            'Тестовый заказ'
        );
		order_ids := ARRAY_APPEND(order_ids, new_order_id);
        -- Состав заказа
        FOR j IN 1..order_product_count LOOP

            INSERT INTO buldakov_food.order_structure VALUES (
                new_order_id,
                order_product_ids[j],
                product_quantities[j]
            );

        END LOOP;

    END LOOP;

END;
$$;


--
-- Name: generate_payments(uuid[]); Type: PROCEDURE; Schema: buldakov_food; Owner: -
--

CREATE PROCEDURE buldakov_food.generate_payments(IN p_order_ids uuid[])
    LANGUAGE plpgsql
    AS $$
DECLARE
    current_order_id UUID;

    new_payment_id UUID;
    new_payment_type buldakov_food.payment_type;
    new_payment_status buldakov_food.payment_status;

    new_payment_amount NUMERIC;
    new_payment_timestamp TIMESTAMP;
    new_transaction_id VARCHAR(255);

    current_order_timestamp TIMESTAMP;
    current_pay_status buldakov_food.pay_status;

BEGIN
    FOREACH current_order_id IN ARRAY p_order_ids LOOP
        -- Данные заказа
        SELECT total_amount, order_timestamp, pay_status
        FROM buldakov_food."order"
        WHERE order_id = current_order_id
        INTO
            new_payment_amount,
            current_order_timestamp,
            current_pay_status;
        -- ID платежа
        new_payment_id := exts.uuid_generate_v4();
        -- Тип платежа
		new_payment_type :=
			    (enum_range(NULL::buldakov_food.payment_type))
			    [floor(random() * 3 + 1)::INT];
        -- Статус платежа
        IF current_pay_status = 'оплачен' THEN
            new_payment_status := 'успех';
        ELSIF current_pay_status = 'ошибка' THEN
            new_payment_status := 'ошибка';
        ELSE
            new_payment_status := 'в_обработке';
        END IF;
        -- Время
        new_payment_timestamp := least(
            current_order_timestamp + RANDOM() * INTERVAL '1 hour',
			CURRENT_TIMESTAMP);
        -- ID транзакции
        new_transaction_id := exts.uuid_generate_v4()::TEXT;
        INSERT INTO buldakov_food.payment VALUES (
            new_payment_id,
            current_order_id,
            new_payment_type,
            new_payment_amount,
            new_transaction_id,
            new_payment_timestamp,
            new_payment_status
        );
    END LOOP;

END;
$$;


--
-- Name: generate_products(integer, uuid[], uuid[], uuid[]); Type: PROCEDURE; Schema: buldakov_food; Owner: -
--

CREATE PROCEDURE buldakov_food.generate_products(IN p_value integer, IN restaurant_ids uuid[], IN product_category_ids uuid[], INOUT product_ids uuid[])
    LANGUAGE plpgsql
    AS $$
DECLARE
    new_product_id UUID;
    new_product_status buldakov_food.product_status;
BEGIN
    IF p_value <= 0 THEN
        RAISE EXCEPTION 'Количество ресторанов должно быть больше нуля';
    END IF;

    product_ids := ARRAY[]::UUID[];

    FOR i IN 1..p_value LOOP
        FOR j IN 1..5 LOOP
            new_product_id := exts.uuid_generate_v4();

			new_product_status :=
			    (enum_range(NULL::buldakov_food.product_status))
			    [floor(random() * 3 + 1)::INT];

            INSERT INTO buldakov_food.product VALUES (
                new_product_id,
                'Product_' || exts.uuid_generate_v4()::TEXT,
                product_category_ids[
                    FLOOR(RANDOM() * CARDINALITY(product_category_ids) + 1)::INT
                ],
                FLOOR(RANDOM() * 1000 + 1),
                restaurant_ids[i],
                NULL,
                NULL,
                new_product_status,
                'Какое-то описание продукта ' || exts.uuid_generate_v4()::TEXT
            );

            product_ids := ARRAY_APPEND(product_ids, new_product_id);
        END LOOP;
    END LOOP;

    RAISE NOTICE 'Было создано: % продуктов для % ресторанов', p_value * 5, p_value;
END;
$$;


--
-- Name: generate_restaurants(integer, uuid[], uuid[]); Type: PROCEDURE; Schema: buldakov_food; Owner: -
--

CREATE PROCEDURE buldakov_food.generate_restaurants(IN p_value integer, IN restaurant_address_ids uuid[], INOUT restaurant_ids uuid[])
    LANGUAGE plpgsql
    AS $$
DECLARE
    new_restaurant_id UUID;
    new_work_start TIME;
    new_work_end TIME;
	new_restaurant_status buldakov_food.restaurant_status;
BEGIN

    IF p_value <= 0 THEN
        RAISE EXCEPTION 'Значение должно быть больше нуля';
    END IF;
    restaurant_ids := ARRAY[]::UUID[];
    -- Создаём рестораны
    FOR i IN 1..p_value LOOP
        --Время открытия
		-- max start = 10:00
        new_work_start :=
            TIME '00:00' +
            FLOOR(RANDOM() * 600)::INT * INTERVAL '1 minute';
        --время закрытия
		--max close = max start + 10hours + 2 hours = 22:00
        new_work_end :=
            new_work_start +
            FLOOR(RANDOM() * 600)::INT * INTERVAL '1 minute' +
            INTERVAL '2 hours';
        new_restaurant_id := exts.uuid_generate_v4();
		new_restaurant_status :=
		    (enum_range(NULL::buldakov_food.restaurant_status))
		    [floor(random() * 2 + 1)::INT];
        INSERT INTO buldakov_food.restaurant VALUES (
            new_restaurant_id,
            'restaurant_' || exts.uuid_generate_v4()::TEXT,
            restaurant_address_ids[i],
            'Описание ресторана ' ||
                FLOOR(i * RANDOM() * 1000)::TEXT,
            new_work_start,
            new_work_end,
            'company details',
            NULL,
            new_restaurant_status
        );
        restaurant_ids := ARRAY_APPEND(
            restaurant_ids,
            new_restaurant_id
        );
    END LOOP;
    RAISE NOTICE 'Было создано: % ресторанов', p_value;
END;
$$;


--
-- Name: generate_reviews(uuid[]); Type: PROCEDURE; Schema: buldakov_food; Owner: -
--

CREATE PROCEDURE buldakov_food.generate_reviews(IN p_order_ids uuid[])
    LANGUAGE plpgsql
    AS $$
DECLARE
    i INT;

    new_review_id UUID;
    new_client_id UUID;
    new_order_id UUID;
    new_entity_id UUID;
    new_entity_type buldakov_food.review_entity_type;

    new_review_timestamp TIMESTAMP;
    new_description TEXT;
    new_rating NUMERIC;
BEGIN

    IF p_order_ids IS NULL OR CARDINALITY(p_order_ids) = 0 THEN
        RAISE EXCEPTION 'Массив заказов пуст';
    END IF;

    -- Отзыв = 1 заказ
    for i in 1..CARDINALITY(p_order_ids) LOOP
		loop
			--Забираем то на что у нас ревьюшка
			new_entity_type :=
			    (enum_range(NULL::buldakov_food.review_entity_type))
			    [floor(random() * 3 + 1)::INT];
			-- выбираем заказ персоны
			select order_id,client_id,order_timestamp from buldakov_food."order"
			where order_id = p_order_ids[i]
			order by random()
			limit 1 into new_order_id,new_client_id,new_review_timestamp;
			--теперь смотрим что выпало и в зависимости берем нужную айдишку
	
			if new_entity_type = 'заказ' then
				new_entity_id := new_order_id;
			elsif new_entity_type = 'ресторан' then
				select restaurant_id 
				from buldakov_food."order"
				where order_id = new_order_id into new_entity_id;
			else
				select product_id 
				from buldakov_food.order_structure
				where order_id = new_order_id
				order by random()
				limit 1 into new_entity_id;
			end if; 
			 
			if not exists (
				select 1 from buldakov_food.review
				where order_id = new_order_id
				and entity_type = new_entity_type
				and entity_id = new_entity_id
				) then exit;
			end if;
		end loop;

        -- Генерируем дату отзыва после создания заказа
        new_review_timestamp :=
            new_review_timestamp
            + RANDOM() * (CURRENT_TIMESTAMP - new_review_timestamp);

        new_review_id := exts.uuid_generate_v4();

        new_rating := FLOOR(RANDOM() * 5 + 1);

        new_description := (
            ARRAY[
                'Круто',
                'Все супер',
                'Not bad',
                'can be better',
                'Tasty'
            ]
        )[FLOOR(RANDOM() * 5 + 1)::INT];

        INSERT INTO buldakov_food.review VALUES (
            new_review_id,
            new_client_id,
            new_review_timestamp,
            new_entity_id,
            new_entity_type,
            new_order_id,
            new_description,
            NULL,
            new_rating
        );

    END LOOP;

    RAISE NOTICE 'Создано отзывов: %', CARDINALITY(p_order_ids);

END;
$$;


--
-- Name: get_statistic(); Type: FUNCTION; Schema: buldakov_food; Owner: -
--

CREATE FUNCTION buldakov_food.get_statistic() RETURNS TABLE(restaurant_name character varying, best_product_name character varying, total_amount numeric, avg_amount numeric, best_user character varying)
    LANGUAGE sql
    AS $$
	with delivery_orders as (
		select order_id, restaurant_id, client_id, total_amount
		from buldakov_food."order"
		where status ='доставлен'
	),
	-- Чеки для ресторанов
	restaurant_stats as (
		select 
		restaurant_id, 
		sum(total_amount) as total_amount,
		avg(total_amount) as avg_amount
		from delivery_orders
		group by restaurant_id
	),
	-- Проданные блюда
	product_stats as (
		select d.restaurant_id,
		p.product_id,
		p.product_name,
		sum(os.quantity) as total_quantity
		from delivery_orders d
		join buldakov_food.order_structure os
			on d.order_id = os.order_id
		join buldakov_food.product p
			on os.product_id = p.product_id
		group by d.restaurant_id, p.product_id,p.product_name
		),
	-- Популярное блюдо
	popular_product as (
		select distinct on (restaurant_id)
		restaurant_id,
		product_name as best_product_name
		from product_stats
		order by restaurant_id, total_quantity desc
		),
	-- Заказы клиентоа
	user_stats as (
		select d.restaurant_id,
		c.client_id,
		c.login,
		count(*) as order_count
	 	from delivery_orders d
		join buldakov_food.client c 
			on c.client_id = d.client_id
		group by d.restaurant_id,c.client_id, c.login
	),
	best_user as (
		select distinct on (restaurant_id)
		restaurant_id,
		login as best_user
		from user_stats
		order by restaurant_id, order_count desc
	)
	select r.restaurant_name,
	pp.best_product_name,
	rs.total_amount,
	rs.avg_amount,
	bu.best_user
	from buldakov_food.restaurant r
	left join restaurant_stats rs
		on r.restaurant_id = rs.restaurant_id
	left join popular_product pp
		on r.restaurant_id = pp.restaurant_id
	left join best_user bu
		on r.restaurant_id = bu.restaurant_id
$$;


--
-- Name: insert_test_data(integer); Type: PROCEDURE; Schema: buldakov_food; Owner: -
--

CREATE PROCEDURE buldakov_food.insert_test_data(IN value integer)
    LANGUAGE plpgsql
    AS $$
DECLARE
    client_ids UUID[];
    courier_ids UUID[];
    product_category_ids UUID[];
    restaurant_address_ids UUID[];
    client_address_ids UUID[];
    restaurant_ids UUID[];
    product_ids UUID[];
	order_ids UUID[];
BEGIN
RAISE NOTICE 'Передано значение: %', value;
	if value <=0 then
	RAISE EXCEPTION 'Значение должно быть больше нуля';
	end if;
--Благодаря рефакторингу кода все внутренний функции по созданию вынесены
--Создаем клиентов, курьеров и категории продуктов
call buldakov_food.generate_base_data(
	value,
	client_ids,
	courier_ids,
	product_category_ids
);
--Создаем адреса
call buldakov_food.generate_addresses(
	value,
	restaurant_address_ids,
	client_address_ids
);
--Создаем рестораны
call buldakov_food.generate_restaurants(
	value,
	restaurant_address_ids,
	restaurant_ids
);
--Ну тут связь адреса и клиента
call buldakov_food.generate_client_addresses(
	value,
	client_ids,
	client_address_ids
);
-- Продукты для ресторанов
call buldakov_food.generate_products(
	value,
	restaurant_ids,
	product_category_ids,
	product_ids
);

-- Делаем заказы и платежка к ним
call buldakov_food.generate_orders(
    value,
    client_ids,
    courier_ids,
    restaurant_ids,
    order_ids
);
call buldakov_food.generate_payments(order_ids);
-- Выплаты курьерам
call buldakov_food.generate_courier_pay(
    courier_ids
);
--Ревьюшка
call buldakov_food.generate_reviews(
    order_ids
);
END;
$$;


--
-- Name: rating_change(); Type: FUNCTION; Schema: buldakov_food; Owner: -
--

CREATE FUNCTION buldakov_food.rating_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
	if TG_OP = 'DELETE' or TG_OP = 'UPDATE' then
		if old.entity_type = 'блюдо' then
			update buldakov_food.product
				set rating = (
						select avg(r.rating) from buldakov_food.review r
						where r.entity_type = 'блюдо'
						and r.entity_id = OLD.entity_id
						)where product_id = OLD.entity_id;

		elsif old.entity_type = 'ресторан' then
			update buldakov_food.restaurant
				set rating = (
						select avg(r.rating) from buldakov_food.review r
						where r.entity_type = 'ресторан'
						and r.entity_id = OLD.entity_id
						)where restaurant_id = OLD.entity_id;
		end if;
	end if;
	if TG_OP = 'INSERT' or TG_OP = 'UPDATE' then
		if new.entity_type = 'блюдо' then
			update buldakov_food.product
				set rating = (
						select avg(r.rating) from buldakov_food.review r
						where r.entity_type = 'блюдо'
						and r.entity_id = new.entity_id
						)where product_id = new.entity_id;

		elsif new.entity_type = 'ресторан' then
			update buldakov_food.restaurant
				set rating = (
						select avg(r.rating) from buldakov_food.review r
						where r.entity_type = 'ресторан'
						and r.entity_id = new.entity_id
						)where restaurant_id = new.entity_id;
		end if;
	end if;
return null;
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: address; Type: TABLE; Schema: buldakov_food; Owner: -
--

CREATE TABLE buldakov_food.address (
    address_id uuid DEFAULT exts.uuid_generate_v4() NOT NULL,
    street character varying(100) NOT NULL,
    house_number character varying(32) NOT NULL,
    apartment_office character varying(20)
);


--
-- Name: client; Type: TABLE; Schema: buldakov_food; Owner: -
--

CREATE TABLE buldakov_food.client (
    client_id uuid DEFAULT exts.uuid_generate_v4() NOT NULL,
    login character varying(100) NOT NULL,
    password character varying(32) NOT NULL,
    phone_number character varying(20) NOT NULL
);


--
-- Name: client_address; Type: TABLE; Schema: buldakov_food; Owner: -
--

CREATE TABLE buldakov_food.client_address (
    client_id uuid NOT NULL,
    address_id uuid NOT NULL
);


--
-- Name: courier; Type: TABLE; Schema: buldakov_food; Owner: -
--

CREATE TABLE buldakov_food.courier (
    courier_id uuid DEFAULT exts.uuid_generate_v4() NOT NULL,
    fio character varying(100) NOT NULL,
    phone_number character(11) NOT NULL,
    status buldakov_food.courier_status NOT NULL,
    hire_date date NOT NULL,
    dismissal_date date,
    coefficient numeric DEFAULT 0.1 NOT NULL,
    CONSTRAINT courier_check CHECK (((dismissal_date IS NULL) OR (dismissal_date >= hire_date))),
    CONSTRAINT courier_coefficient_check CHECK (((coefficient >= 0.1) AND (coefficient <= 0.5)))
);


--
-- Name: courier_pay; Type: TABLE; Schema: buldakov_food; Owner: -
--

CREATE TABLE buldakov_food.courier_pay (
    year integer NOT NULL,
    month integer NOT NULL,
    courier_id uuid NOT NULL,
    amount numeric NOT NULL,
    coefficient_used numeric NOT NULL,
    CONSTRAINT courier_pay_amount_check CHECK ((amount >= (0)::numeric)),
    CONSTRAINT courier_pay_coefficient_used_check CHECK (((coefficient_used >= 0.1) AND (coefficient_used <= 0.5))),
    CONSTRAINT courier_pay_month_check CHECK (((month >= 1) AND (month <= 12)))
);


--
-- Name: order; Type: TABLE; Schema: buldakov_food; Owner: -
--

CREATE TABLE buldakov_food."order" (
    order_id uuid DEFAULT exts.uuid_generate_v4() NOT NULL,
    courier_id uuid NOT NULL,
    client_id uuid NOT NULL,
    address_id uuid NOT NULL,
    restaurant_id uuid NOT NULL,
    order_timestamp timestamp without time zone NOT NULL,
    delivery_timestamp timestamp without time zone,
    order_amount numeric NOT NULL,
    commission numeric NOT NULL,
    total_amount numeric NOT NULL,
    status buldakov_food.order_status NOT NULL,
    pay_status buldakov_food.pay_status NOT NULL,
    description text NOT NULL,
    CONSTRAINT order_check CHECK ((delivery_timestamp >= order_timestamp)),
    CONSTRAINT order_check1 CHECK (((commission > (0)::numeric) AND ((order_amount * 0.1) = commission))),
    CONSTRAINT order_check2 CHECK (((total_amount >= (1000)::numeric) AND ((order_amount + commission) = total_amount))),
    CONSTRAINT order_order_amount_check CHECK ((order_amount >= (0)::numeric))
);


--
-- Name: order_structure; Type: TABLE; Schema: buldakov_food; Owner: -
--

CREATE TABLE buldakov_food.order_structure (
    order_id uuid NOT NULL,
    product_id uuid NOT NULL,
    quantity numeric NOT NULL,
    CONSTRAINT order_structure_quantity_check CHECK ((quantity > (0)::numeric))
);


--
-- Name: payment; Type: TABLE; Schema: buldakov_food; Owner: -
--

CREATE TABLE buldakov_food.payment (
    payment_id uuid DEFAULT exts.uuid_generate_v4() NOT NULL,
    order_id uuid NOT NULL,
    payment_type buldakov_food.payment_type NOT NULL,
    amount numeric(12,2) NOT NULL,
    transaction_id character varying(255) NOT NULL,
    transaction_timestamp timestamp without time zone NOT NULL,
    status buldakov_food.payment_status NOT NULL
);


--
-- Name: product; Type: TABLE; Schema: buldakov_food; Owner: -
--

CREATE TABLE buldakov_food.product (
    product_id uuid DEFAULT exts.uuid_generate_v4() NOT NULL,
    product_name character varying(100) NOT NULL,
    product_category_id uuid NOT NULL,
    price numeric NOT NULL,
    restaurant_id uuid NOT NULL,
    photo_url text,
    rating numeric,
    status buldakov_food.product_status NOT NULL,
    description text NOT NULL,
    CONSTRAINT product_price_check CHECK ((price >= (0)::numeric)),
    CONSTRAINT product_rating_check CHECK (((rating >= (0)::numeric) AND (rating <= (5)::numeric)))
);


--
-- Name: product_category; Type: TABLE; Schema: buldakov_food; Owner: -
--

CREATE TABLE buldakov_food.product_category (
    product_category_id uuid DEFAULT exts.uuid_generate_v4() NOT NULL,
    product_category_name character varying(100) NOT NULL
);


--
-- Name: restaurant; Type: TABLE; Schema: buldakov_food; Owner: -
--

CREATE TABLE buldakov_food.restaurant (
    restaurant_id uuid DEFAULT exts.uuid_generate_v4() NOT NULL,
    restaurant_name character varying(100) NOT NULL,
    address_id uuid NOT NULL,
    description text NOT NULL,
    work_start time without time zone NOT NULL,
    work_end time without time zone NOT NULL,
    company_details text NOT NULL,
    rating numeric,
    status buldakov_food.restaurant_status NOT NULL,
    CONSTRAINT restaurant_check CHECK ((work_end > work_start)),
    CONSTRAINT restaurant_rating_check CHECK (((rating >= (0)::numeric) AND (rating <= (5)::numeric)))
);


--
-- Name: review; Type: TABLE; Schema: buldakov_food; Owner: -
--

CREATE TABLE buldakov_food.review (
    review_id uuid DEFAULT exts.uuid_generate_v4() NOT NULL,
    client_id uuid NOT NULL,
    review_timestamp timestamp without time zone NOT NULL,
    entity_id uuid NOT NULL,
    entity_type buldakov_food.review_entity_type NOT NULL,
    order_id uuid NOT NULL,
    description text NOT NULL,
    photo_url text,
    rating numeric NOT NULL,
    CONSTRAINT review_rating_check CHECK (((rating >= (1)::numeric) AND (rating <= (5)::numeric)))
);


--
-- Name: address address_pkey; Type: CONSTRAINT; Schema: buldakov_food; Owner: -
--

ALTER TABLE ONLY buldakov_food.address
    ADD CONSTRAINT address_pkey PRIMARY KEY (address_id);


--
-- Name: client_address client_address_pkey; Type: CONSTRAINT; Schema: buldakov_food; Owner: -
--

ALTER TABLE ONLY buldakov_food.client_address
    ADD CONSTRAINT client_address_pkey PRIMARY KEY (client_id, address_id);


--
-- Name: client client_login_key; Type: CONSTRAINT; Schema: buldakov_food; Owner: -
--

ALTER TABLE ONLY buldakov_food.client
    ADD CONSTRAINT client_login_key UNIQUE (login);


--
-- Name: client client_phone_number_key; Type: CONSTRAINT; Schema: buldakov_food; Owner: -
--

ALTER TABLE ONLY buldakov_food.client
    ADD CONSTRAINT client_phone_number_key UNIQUE (phone_number);


--
-- Name: client client_pkey; Type: CONSTRAINT; Schema: buldakov_food; Owner: -
--

ALTER TABLE ONLY buldakov_food.client
    ADD CONSTRAINT client_pkey PRIMARY KEY (client_id);


--
-- Name: courier_pay courier_pay_pkey; Type: CONSTRAINT; Schema: buldakov_food; Owner: -
--

ALTER TABLE ONLY buldakov_food.courier_pay
    ADD CONSTRAINT courier_pay_pkey PRIMARY KEY (year, month, courier_id);


--
-- Name: courier courier_phone_number_key; Type: CONSTRAINT; Schema: buldakov_food; Owner: -
--

ALTER TABLE ONLY buldakov_food.courier
    ADD CONSTRAINT courier_phone_number_key UNIQUE (phone_number);


--
-- Name: courier courier_pkey; Type: CONSTRAINT; Schema: buldakov_food; Owner: -
--

ALTER TABLE ONLY buldakov_food.courier
    ADD CONSTRAINT courier_pkey PRIMARY KEY (courier_id);


--
-- Name: order order_pkey; Type: CONSTRAINT; Schema: buldakov_food; Owner: -
--

ALTER TABLE ONLY buldakov_food."order"
    ADD CONSTRAINT order_pkey PRIMARY KEY (order_id);


--
-- Name: order_structure order_structure_pkey; Type: CONSTRAINT; Schema: buldakov_food; Owner: -
--

ALTER TABLE ONLY buldakov_food.order_structure
    ADD CONSTRAINT order_structure_pkey PRIMARY KEY (order_id, product_id);


--
-- Name: payment payment_pkey; Type: CONSTRAINT; Schema: buldakov_food; Owner: -
--

ALTER TABLE ONLY buldakov_food.payment
    ADD CONSTRAINT payment_pkey PRIMARY KEY (payment_id);


--
-- Name: payment payment_transaction_id_key; Type: CONSTRAINT; Schema: buldakov_food; Owner: -
--

ALTER TABLE ONLY buldakov_food.payment
    ADD CONSTRAINT payment_transaction_id_key UNIQUE (transaction_id);


--
-- Name: product_category product_category_pkey; Type: CONSTRAINT; Schema: buldakov_food; Owner: -
--

ALTER TABLE ONLY buldakov_food.product_category
    ADD CONSTRAINT product_category_pkey PRIMARY KEY (product_category_id);


--
-- Name: product product_pkey; Type: CONSTRAINT; Schema: buldakov_food; Owner: -
--

ALTER TABLE ONLY buldakov_food.product
    ADD CONSTRAINT product_pkey PRIMARY KEY (product_id);


--
-- Name: restaurant restaurant_address_id_key; Type: CONSTRAINT; Schema: buldakov_food; Owner: -
--

ALTER TABLE ONLY buldakov_food.restaurant
    ADD CONSTRAINT restaurant_address_id_key UNIQUE (address_id);


--
-- Name: restaurant restaurant_pkey; Type: CONSTRAINT; Schema: buldakov_food; Owner: -
--

ALTER TABLE ONLY buldakov_food.restaurant
    ADD CONSTRAINT restaurant_pkey PRIMARY KEY (restaurant_id);


--
-- Name: review review_order_id_entity_type_entity_id_key; Type: CONSTRAINT; Schema: buldakov_food; Owner: -
--

ALTER TABLE ONLY buldakov_food.review
    ADD CONSTRAINT review_order_id_entity_type_entity_id_key UNIQUE (order_id, entity_type, entity_id);


--
-- Name: review review_pkey; Type: CONSTRAINT; Schema: buldakov_food; Owner: -
--

ALTER TABLE ONLY buldakov_food.review
    ADD CONSTRAINT review_pkey PRIMARY KEY (review_id);


--
-- Name: review review_rating_trigger; Type: TRIGGER; Schema: buldakov_food; Owner: -
--

CREATE TRIGGER review_rating_trigger AFTER INSERT OR DELETE OR UPDATE ON buldakov_food.review FOR EACH ROW EXECUTE FUNCTION buldakov_food.rating_change();


--
-- Name: client_address client_address_address_id_fkey; Type: FK CONSTRAINT; Schema: buldakov_food; Owner: -
--

ALTER TABLE ONLY buldakov_food.client_address
    ADD CONSTRAINT client_address_address_id_fkey FOREIGN KEY (address_id) REFERENCES buldakov_food.address(address_id);


--
-- Name: client_address client_address_client_id_fkey; Type: FK CONSTRAINT; Schema: buldakov_food; Owner: -
--

ALTER TABLE ONLY buldakov_food.client_address
    ADD CONSTRAINT client_address_client_id_fkey FOREIGN KEY (client_id) REFERENCES buldakov_food.client(client_id);


--
-- Name: courier_pay courier_pay_courier_id_fkey; Type: FK CONSTRAINT; Schema: buldakov_food; Owner: -
--

ALTER TABLE ONLY buldakov_food.courier_pay
    ADD CONSTRAINT courier_pay_courier_id_fkey FOREIGN KEY (courier_id) REFERENCES buldakov_food.courier(courier_id);


--
-- Name: order order_address_id_fkey; Type: FK CONSTRAINT; Schema: buldakov_food; Owner: -
--

ALTER TABLE ONLY buldakov_food."order"
    ADD CONSTRAINT order_address_id_fkey FOREIGN KEY (address_id) REFERENCES buldakov_food.address(address_id);


--
-- Name: order order_client_address_fkey; Type: FK CONSTRAINT; Schema: buldakov_food; Owner: -
--

ALTER TABLE ONLY buldakov_food."order"
    ADD CONSTRAINT order_client_address_fkey FOREIGN KEY (client_id, address_id) REFERENCES buldakov_food.client_address(client_id, address_id);


--
-- Name: order order_client_id_fkey; Type: FK CONSTRAINT; Schema: buldakov_food; Owner: -
--

ALTER TABLE ONLY buldakov_food."order"
    ADD CONSTRAINT order_client_id_fkey FOREIGN KEY (client_id) REFERENCES buldakov_food.client(client_id);


--
-- Name: order order_courier_id_fkey; Type: FK CONSTRAINT; Schema: buldakov_food; Owner: -
--

ALTER TABLE ONLY buldakov_food."order"
    ADD CONSTRAINT order_courier_id_fkey FOREIGN KEY (courier_id) REFERENCES buldakov_food.courier(courier_id);


--
-- Name: order order_restaurant_id_fkey; Type: FK CONSTRAINT; Schema: buldakov_food; Owner: -
--

ALTER TABLE ONLY buldakov_food."order"
    ADD CONSTRAINT order_restaurant_id_fkey FOREIGN KEY (restaurant_id) REFERENCES buldakov_food.restaurant(restaurant_id);


--
-- Name: order_structure order_structure_order_id_fkey; Type: FK CONSTRAINT; Schema: buldakov_food; Owner: -
--

ALTER TABLE ONLY buldakov_food.order_structure
    ADD CONSTRAINT order_structure_order_id_fkey FOREIGN KEY (order_id) REFERENCES buldakov_food."order"(order_id);


--
-- Name: order_structure order_structure_product_id_fkey; Type: FK CONSTRAINT; Schema: buldakov_food; Owner: -
--

ALTER TABLE ONLY buldakov_food.order_structure
    ADD CONSTRAINT order_structure_product_id_fkey FOREIGN KEY (product_id) REFERENCES buldakov_food.product(product_id);


--
-- Name: payment payment_order_id_fkey; Type: FK CONSTRAINT; Schema: buldakov_food; Owner: -
--

ALTER TABLE ONLY buldakov_food.payment
    ADD CONSTRAINT payment_order_id_fkey FOREIGN KEY (order_id) REFERENCES buldakov_food."order"(order_id);


--
-- Name: product product_product_category_id_fkey; Type: FK CONSTRAINT; Schema: buldakov_food; Owner: -
--

ALTER TABLE ONLY buldakov_food.product
    ADD CONSTRAINT product_product_category_id_fkey FOREIGN KEY (product_category_id) REFERENCES buldakov_food.product_category(product_category_id);


--
-- Name: product product_restaurant_id_fkey; Type: FK CONSTRAINT; Schema: buldakov_food; Owner: -
--

ALTER TABLE ONLY buldakov_food.product
    ADD CONSTRAINT product_restaurant_id_fkey FOREIGN KEY (restaurant_id) REFERENCES buldakov_food.restaurant(restaurant_id);


--
-- Name: restaurant restaurant_address_id_fkey; Type: FK CONSTRAINT; Schema: buldakov_food; Owner: -
--

ALTER TABLE ONLY buldakov_food.restaurant
    ADD CONSTRAINT restaurant_address_id_fkey FOREIGN KEY (address_id) REFERENCES buldakov_food.address(address_id);


--
-- Name: review review_client_id_fkey; Type: FK CONSTRAINT; Schema: buldakov_food; Owner: -
--

ALTER TABLE ONLY buldakov_food.review
    ADD CONSTRAINT review_client_id_fkey FOREIGN KEY (client_id) REFERENCES buldakov_food.client(client_id);


--
-- Name: review review_order_id_fkey; Type: FK CONSTRAINT; Schema: buldakov_food; Owner: -
--

ALTER TABLE ONLY buldakov_food.review
    ADD CONSTRAINT review_order_id_fkey FOREIGN KEY (order_id) REFERENCES buldakov_food."order"(order_id);


--
-- PostgreSQL database dump complete
--

