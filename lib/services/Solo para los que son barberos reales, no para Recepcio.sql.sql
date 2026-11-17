-- Solo para los que son barberos reales, no para Recepcion
UPDATE transactions SET barber_name = cashier_name 
WHERE barber_name IS NULL 
AND UPPER(cashier_name) IN ('BRAYAN','ALEX','MATY');