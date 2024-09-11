CREATE OR REPLACE PROCEDURE get_third_highest_order_info AS
    -- Variables to store the result
    v_order_ref VARCHAR2(10);
    v_order_date VARCHAR2(30);
    v_supplier_name VARCHAR2(255);
    v_order_total_amount VARCHAR2(20);
    v_order_status VARCHAR2(50);
    v_invoice_refs VARCHAR2(4000);

    -- Variable for error handling
    v_error_message VARCHAR2(1000);

BEGIN
    -- Query to fetch the details for the third-highest order total
    SELECT 
        TO_NUMBER(SUBSTR(order_ref, 3)) AS order_ref_numeric,          -- Remove 'PO' prefix and return numeric value
        TO_CHAR(order_date, 'Month DD, YYYY') AS formatted_order_date, -- Format order date as 'Month DD, YYYY'
        UPPER(supplier_name) AS upper_supplier_name,                   -- Supplier name in uppercase
        TO_CHAR(total_amount, '999G999G990D00') AS formatted_total_amount, -- Format order total amount
        status AS order_status,                                        -- Order status
        (SELECT LISTAGG(i.invoice_ref, ', ') WITHIN GROUP (ORDER BY i.invoice_ref) -- Concatenate all invoice references
         FROM invoices i, orders o
         WHERE i.order_id = o.order_id) AS invoice_references
    INTO 
        v_order_ref, v_order_date, v_supplier_name, v_order_total_amount, v_order_status, v_invoice_refs
    FROM 
        (SELECT o.order_id, o.order_ref, o.order_date, o.total_amount, o.status, s.supplier_name, 
                ROW_NUMBER() OVER (ORDER BY o.total_amount DESC) AS rn
         FROM orders o
         JOIN suppliers s ON o.supplier_id = s.supplier_id
         ORDER BY o.total_amount DESC) 
    WHERE 
        rn = 3; -- Fetch the third-highest total amount

    -- Output the result
    DBMS_OUTPUT.PUT_LINE('Order Reference: ' || v_order_ref);
    DBMS_OUTPUT.PUT_LINE('Order Date: ' || v_order_date);
    DBMS_OUTPUT.PUT_LINE('Supplier Name: ' || v_supplier_name);
    DBMS_OUTPUT.PUT_LINE('Order Total Amount: ' || v_order_total_amount);
    DBMS_OUTPUT.PUT_LINE('Order Status: ' || v_order_status);
    DBMS_OUTPUT.PUT_LINE('Invoice References: ' || NVL(v_invoice_refs, 'No Invoices'));

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        v_error_message := 'No data found for the third-highest order total amount.';
        DBMS_OUTPUT.PUT_LINE(v_error_message);
    WHEN OTHERS THEN
        v_error_message := 'Error occurred: ' || SQLERRM;
        DBMS_OUTPUT.PUT_LINE(v_error_message);
END get_third_highest_order_info;
/