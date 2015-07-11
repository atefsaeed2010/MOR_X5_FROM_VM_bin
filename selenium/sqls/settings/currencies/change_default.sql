# XAF padarymas default currency
UPDATE `currencies` set id=555555 where name='XAF';
UPDATE `currencies` set id=28 where name='USD';
UPDATE `currencies` set id=1 where name='XAF';
UPDATE `currencies` set exchange_rate=0.005 AND active=1 where name='USD';
