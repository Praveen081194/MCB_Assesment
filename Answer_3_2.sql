-- Package Specification
CREATE OR REPLACE PACKAGE order_migration_pkg AS
    PROCEDURE migrate_order_data;
END order_migration_pkg;
/

-- Package Body
CREATE OR REPLACE PACKAGE BODY order_migration_pkg AS
    -- Procedure to migrate data
    PROCEDURE migrate_order_data IS
        -- Variables to store data
        v_supplier_id NUMBER;
        v_order_id NUMBER;
        v_invoice_id NUMBER;
        v_rows_processed NUMBER := 0;

        -- Cursor to select data from XXBCM_ORDER_MGT
        CURSOR c_order_mgt IS
        SELECT ORDER_REF, ORDER_DATE, SUPPLIER_NAME, SUPP_CONTACT_NAME, SUPP_ADDRESS, SUPP_CONTACT_NUMBER,
               SUPP_EMAIL, ORDER_TOTAL_AMOUNT, ORDER_DESCRIPTION, ORDER_STATUS, ORDER_LINE_AMOUNT, INVOICE_REFERENCE,
               INVOICE_DATE, INVOICE_STATUS, INVOICE_HOLD_REASON, INVOICE_AMOUNT, INVOICE_DESCRIPTION
        FROM XXBCM_ORDER_MGT;

        -- Exception logging procedure
        PROCEDURE log_error(p_error_message VARCHAR2, p_proc_name VARCHAR2, p_error_data CLOB) IS
        BEGIN
            INSERT INTO migration_errors (error_message, procedure_name, error_data)
            VALUES (p_error_message, p_proc_name, p_error_data);
        END log_error;

    BEGIN
        -- Start the migration process
        FOR order_rec IN c_order_mgt LOOP
            BEGIN
                -- Step 1: Insert supplier data and get supplier_id
                BEGIN
                    INSERT INTO suppliers (supplier_name, contact_name, address, contact_number, email)
                    VALUES (order_rec.SUPPLIER_NAME, order_rec.SUPP_CONTACT_NAME, order_rec.SUPP_ADDRESS,
                            order_rec.SUPP_CONTACT_NUMBER, order_rec.SUPP_EMAIL)
                    RETURNING supplier_id INTO v_supplier_id;
                EXCEPTION
                    WHEN DUP_VAL_ON_INDEX THEN
                        -- If supplier already exists, get the existing supplier_id
                        SELECT supplier_id INTO v_supplier_id FROM suppliers WHERE email = order_rec.SUPP_EMAIL;
                END;

                -- Step 2: Insert order data and get order_id
                INSERT INTO orders (supplier_id, order_ref, order_date, total_amount, description, status)
                VALUES (v_supplier_id, order_rec.ORDER_REF, TO_DATE(order_rec.ORDER_DATE, 'DD-MON-YYYY'),
                        TO_NUMBER(order_rec.ORDER_TOTAL_AMOUNT, '999G999D99'), order_rec.ORDER_DESCRIPTION, order_rec.ORDER_STATUS)
                RETURNING order_id INTO v_order_id;

                -- Step 3: Insert order line data if available
                IF order_rec.ORDER_LINE_AMOUNT IS NOT NULL THEN
                    INSERT INTO order_lines (order_id, line_amount, description)
                    VALUES (v_order_id, TO_NUMBER(order_rec.ORDER_LINE_AMOUNT, '999G999D99'), order_rec.ORDER_DESCRIPTION);
                END IF;

                -- Step 4: Insert invoice data if available
                IF order_rec.INVOICE_REFERENCE IS NOT NULL THEN
                    INSERT INTO invoices (order_id, invoice_ref, invoice_date, status, hold_reason, amount, description)
                    VALUES (v_order_id, order_rec.INVOICE_REFERENCE, TO_DATE(order_rec.INVOICE_DATE, 'DD-MON-YYYY'),
                            order_rec.INVOICE_STATUS, order_rec.INVOICE_HOLD_REASON,
                            TO_NUMBER(order_rec.INVOICE_AMOUNT, '999G999D99'), order_rec.INVOICE_DESCRIPTION)
                    RETURNING invoice_id INTO v_invoice_id;
                END IF;

                -- Increment the row processed count
                v_rows_processed := v_rows_processed + 1;

            EXCEPTION
                WHEN OTHERS THEN
                    -- Log any unexpected errors
                    log_error(SQLERRM, 'migrate_order_data', 'ORDER_REF: ' || order_rec.ORDER_REF);
            END;
        END LOOP;

        -- Output the results
        DBMS_OUTPUT.PUT_LINE('Migration completed. Rows processed: ' || v_rows_processed);

    EXCEPTION
        WHEN OTHERS THEN
            -- Handle any general errors in the migration process
            log_error(SQLERRM, 'migrate_order_data', 'Migration failed.');
            DBMS_OUTPUT.PUT_LINE('Migration failed due to an error.');
    END migrate_order_data;
END order_migration_pkg;
/