BEGIN
    order_migration_pkg.migrate_order_data;
	COMMIT;
END;
/