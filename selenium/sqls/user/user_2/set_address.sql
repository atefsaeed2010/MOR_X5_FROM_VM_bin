INSERT INTO `addresses` (`id`, `direction_id`, `state`, `county`, `city`, `postcode`, `address`, `phone`, `mob_phone`, `fax`, `email`) VALUES
(21, 150, 'none', 'Netherlands', 'S-Gravenhage  ', '2595 AK', 'Prinses Beatrixlaan 23', '(+31) 26 6456896', '(+31) 55 3731678', '(+31) 26 6456897', 'test_user_admin@email.test');

update `users` set address_id=21 where id=2;
update `users` set clientid='uab kompanija' where id=2;
