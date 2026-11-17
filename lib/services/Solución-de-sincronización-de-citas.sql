UPDATE transactions SET cashier_name = UPPER(cashier_name) WHERE cashier_name IS NOT NULL;
UPDATE transactions SET barber_name = UPPER(barber_name) WHERE barber_name IS NOT NULL;