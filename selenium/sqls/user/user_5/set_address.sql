INSERT INTO `addresses` (`id`, `direction_id`, `state`, `county`, `city`, `postcode`, `address`, `phone`, `mob_phone`, `fax`, `email`) VALUES
(20, 97, 'none', 'Hungary', 'Budapest', '2806', 'Fiktiv utca 82., IV. em./28.', '+36 -1-7866658', '+36-30-3453132', '+36 -1-7866659', 'test_user_reseller@email.test');

update `users` set address_id=20 where id=5;
update `users` set clientid='kompanija yes' where id=5;
