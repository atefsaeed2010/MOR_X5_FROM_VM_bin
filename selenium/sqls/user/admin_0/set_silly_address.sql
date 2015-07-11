INSERT INTO `addresses` (`id`, `direction_id`, `state`, `county`, `city`, `postcode`, `address`, `phone`, `mob_phone`, `fax`, `email`) VALUES
(22, 5, '*Y$#$*^(@#^_)@!', '*Y$#$*^(@#^_)@!', '*Y$#$*^(@#^_)@!', '*Y$#$*^(@#^_)@!', '*Y$#$*^(@#^_)@!', '*Y$#$*^(@#^_)@!', '*Y$#$*^(@#^_)@!', '*Y$#$*^(@#^_)@!', '*Y$#$*^(@#^_)@!@*Y$#$*^(@#^_)@!.com');

update `users` set address_id=22 where id=0;
update `users` set clientid='*Y$#$*^(@#^_)@!' where id=0;

