CREATE OR REPLACE PROCEDURE generate_order_invoice_report AS
    -- Define a cursor to retrieve all orders and related invoices
    CURSOR c_order_invoice IS
        SELECT 
            o.order_ref,
            o.order_date,
            s.supplier_name,
            o.total_amount AS order_total_amount,
            o.status AS order_status,
            i.invoice_ref,
            i.amount AS invoice_total_amount,
            i.status AS invoice_status
        FROM 
            orders o
        JOIN 
            suppliers s ON o.supplier_id = s.supplier_id
        LEFT JOIN 
            invoices i ON o.order_id = i.order_id
        ORDER BY 
            o.order_date DESC;

    -- Variables to hold values during processing
    v_order_ref VARCHAR2(10);
    v_order_period VARCHAR2(10);
    v_supplier_name VARCHAR2(255);
    v_order_total_amount VARCHAR2(20);
    v_order_status VARCHAR2(50);
    v_invoice_ref VARCHAR2(100);
    v_invoice_total_amount VARCHAR2(20);
    v_invoice_status VARCHAR2(50);
    v_action VARCHAR2(20);
    v_all_paid BOOLEAN := TRUE;
    v_any_pending BOOLEAN := FALSE;
    v_any_blank BOOLEAN := FALSE;

    -- Procedure to log errors
    PROCEDURE log_error(p_error_message VARCHAR2) IS
    BEGIN
        DBMS_OUTPUT.PUT_LINE('Error: ' || p_error_message);
    END log_error;

BEGIN
    DBMS_OUTPUT.PUT_LINE('Order Ref | Order Period | Supplier Name | Order Total Amount | Order Status | Invoice Ref | Invoice Total Amount | Action');
    DBMS_OUTPUT.PUT_LINE('----------|--------------|---------------|--------------------|--------------|-------------|----------------------|--------');
    
    -- Open cursor and loop through the records
    FOR rec IN c_order_invoice LOOP
        BEGIN
            -- Step 1: Format Order Reference (Remove 'PO' prefix and convert to number)
            v_order_ref := TO_NUMBER(SUBSTR(rec.order_ref, 3));

            -- Step 2: Format Order Period (MON-YY)
            v_order_period := TO_CHAR(TO_DATE(rec.order_date, 'DD-MON-YYYY'), 'MON-YY');

            -- Step 3: Format Supplier Name (First letter of each word capitalized)
            v_supplier_name := INITCAP(rec.supplier_name);

            -- Step 4: Format Order Total Amount as '99,999,990.00'
            v_order_total_amount := TO_CHAR(rec.order_total_amount, '999G999G990D00');

            -- Step 5: Set Order Status
            v_order_status := rec.order_status;

            -- Step 6: Format Invoice Total Amount (if exists)
            IF rec.invoice_ref IS NOT NULL THEN
                v_invoice_ref := rec.invoice_ref;
                v_invoice_total_amount := TO_CHAR(rec.invoice_total_amount, '999G999G990D00');
                v_invoice_status := rec.invoice_status;

                -- Step 7: Determine Action based on Invoice Status
                IF rec.invoice_status = 'Paid' THEN
                    v_all_paid := TRUE;
                ELSIF rec.invoice_status = 'Pending' THEN
                    v_any_pending := TRUE;
                ELSIF rec.invoice_status IS NULL OR rec.invoice_status = '' THEN
                    v_any_blank := TRUE;
                END IF;

            ELSE
                v_invoice_ref := 'No Invoice';
                v_invoice_total_amount := '0.00';
                v_invoice_status := 'No Invoice';
            END IF;

            -- Step 8: Determine Action based on combined statuses
            IF v_any_blank THEN
                v_action := 'To verify';
            ELSIF v_any_pending THEN
                v_action := 'To follow up';
            ELSIF v_all_paid THEN
                v_action := 'OK';
            END IF;

            -- Step 9: Output the result
            DBMS_OUTPUT.PUT_LINE(v_order_ref || ' | ' || v_order_period || ' | ' || v_supplier_name || ' | ' ||
                                 v_order_total_amount || ' | ' || v_order_status || ' | ' || v_invoice_ref || ' | ' ||
                                 v_invoice_total_amount || ' | ' || v_action);
            
            -- Reset status flags
            v_all_paid := TRUE;
            v_any_pending := FALSE;
            v_any_blank := FALSE;
        EXCEPTION
            WHEN OTHERS THEN
                -- Log any unexpected errors
                log_error(SQLERRM);
        END;
    END LOOP;
    
    DBMS_OUTPUT.PUT_LINE('Report generation complete.');
EXCEPTION
    WHEN OTHERS THEN
        -- Handle errors at a higher level
        log_error(SQLERRM);
        DBMS_OUTPUT.PUT_LINE('Failed to generate the report.');
END generate_order_invoice_report;
/