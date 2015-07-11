#this makes reseller rspro
UPDATE `users` SET `own_providers` = '1' WHERE `id` =3;

INSERT INTO `lcrs` (`id`, `name`, `order`, `user_id`, `first_provider_percent_limit`, `failover_provider_id`, `no_failover`) VALUES (11301,'BLANK','price',3,0.000000000000000,NULL,0);
