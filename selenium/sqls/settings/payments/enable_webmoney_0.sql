# Enable webmoney for admin
UPDATE conflines SET value=1 WHERE name = 'WebMoney_Enabled' AND owner_id = 0;