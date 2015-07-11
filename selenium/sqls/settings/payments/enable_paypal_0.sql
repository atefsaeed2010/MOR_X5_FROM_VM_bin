# Enable paypal for admin
UPDATE `conflines` SET value=1 WHERE name = 'Paypal_Enabled' AND owner_id = 0;
UPDATE `conflines` SET value='test@test.lt' WHERE name = 'Paypal_Email' AND owner_id = 0;
