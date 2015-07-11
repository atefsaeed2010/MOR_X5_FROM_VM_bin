DELETE FROM `conflines` where name='Date_format';
INSERT INTO `conflines` (`owner_id`,`value`,`name`) VALUES ('3','%d,%m,%Y %H:%M:%S','Date_format');
