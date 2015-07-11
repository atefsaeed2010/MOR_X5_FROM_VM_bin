DELETE FROM `conflines` where name='Date_format';
INSERT INTO `conflines` (`value`,`name`) VALUES ('%d,%m,%Y %H:%M:%S','Date_format');
