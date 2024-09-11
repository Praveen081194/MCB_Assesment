CREATE OR REPLACE PROCEDURE get_supplier_order_summary (
    p_start_date IN DATE := TO_DATE('01-JAN-2017', 'DD-MON-YYYY'),
    p_end_date IN DATE := TO_DATE('31-AUG-2017', 'DD-MON-YYYY')
) AS
    -- Variables to store query results
    v_supplier_name VARCHAR2(255);
    v_supplier_contact_name VARCHAR2(255);
    v_contact_no_1 VARCHAR2(15);
    v_contact_no_2 VARCHAR2(15);
    v_total_orders NUMBER;
    v_order_total_amount VARCHAR2(20);

    -- Variable for error handling
    v_error_message VARCHAR2(1000);

    -- Cursor to retrieve the suppliers with orders within the date range
    CURSOR c_supplier_orders IS
        SELECT 
            s.supplier_name,
            s.contact_name,
            s.contact_number contact_number_1,
            s.contact_number contact_number_2,
            COUNT(o.order_id) AS total_orders,
            SUM(o.total_amount) AS total_order_amount
        FROM 
            suppliers s
        JOIN 
            orders o ON s.supplier_id = o.supplier_id
        WHERE 
            o.order_date BETWEEN p_start_date AND p_end_date
        GROUP BY 
            s.supplier_name, s.contact_name, s.contact_number 
        ORDER BY 
            s.supplier_name;

BEGIN
    -- Output the header
    DBMS_OUTPUT.PUT_LINE('Supplier Name | Contact Name | Contact No. 1 | Contact No. 2 | Total Orders | Order Total Amount');
    DBMS_OUTPUT.PUT_LINE('--------------|--------------|----------------|----------------|--------------|--------------------');

    -- Open the cursor to loop through the result set
    FOR rec IN c_supplier_orders LOOP
        BEGIN
            -- Step 1: Get supplier name and contact details
            v_supplier_name := rec.supplier_name;
            v_supplier_contact_name := rec.contact_name;

            -- Step 2: Format Contact Number 1
            IF LENGTH(rec.contact_number_1) = 8 THEN
                v_contact_no_1 := SUBSTR(rec.contact_number_1, 1, 4) || '-' || SUBSTR(rec.contact_number_1, 5);
            ELSE
                v_contact_no_1 := rec.contact_number_1; -- In case the contact number doesn't match expected format
            END IF;

            -- Step 3: Format Contact Number 2
            IF LENGTH(rec.contact_number_2) = 8 THEN
                v_contact_no_2 := SUBSTR(rec.contact_number_2, 1, 4) || '-' || SUBSTR(rec.contact_number_2, 5);
            ELSE
                v_contact_no_2 := rec.contact_number_2; -- In case the contact number doesn't match expected format
            END IF;

            -- Step 4: Calculate Total Orders
            v_total_orders := rec.total_orders;

            -- Step 5: Format Order Total Amount as '99,999,990.00'
            v_order_total_amount := TO_CHAR(rec.total_order_amount, '999G999G990D00');

            -- Step 6: Output the result
            DBMS_OUTPUT.PUT_LINE(v_supplier_name || ' | ' ||
                                 v_supplier_contact_name || ' | ' ||
                                 NVL(v_contact_no_1, 'N/A') || ' | ' ||
                                 NVL(v_contact_no_2, 'N/A') || ' | ' ||
                                 v_total_orders || ' | ' ||
                                 v_order_total_amount);

        EXCEPTION
            WHEN OTHERS THEN
                -- Handle any unexpected errors
                v_error_message := 'Error processing supplier ' || rec.supplier_name || ': ' || SQLERRM;
                DBMS_OUTPUT.PUT_LINE(v_error_message);
        END;
    END LOOP;

    -- Notify when processing is complete
    DBMS_OUTPUT.PUT_LINE('Supplier order summary completed.');

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('No data found for the specified date range.');
    WHEN OTHERS THEN
        -- Handle any unexpected errors
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
END get_supplier_order_summary;
/