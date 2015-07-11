DELETE from `conflines` where name='reCAPTCHA_enabled';
INSERT into `conflines` (`name`, `value`, `owner_id`) VALUES ('reCAPTCHA_enabled', '1', 0);

DELETE from `conflines` where name='ReCAPTCHA_public_key';
INSERT into `conflines` (`name`, `value`, `owner_id`) VALUES ('ReCAPTCHA_public_key', '6LeDU-8SAAAAAN36QlHDCl_sTa4_VJzISa90RWDH', 0);

DELETE from `conflines` where name='ReCAPTCHA_private_key';
INSERT into `conflines` (`name`, `value`, `owner_id`) VALUES ('ReCAPTCHA_private_key', '6LeDU-8SAAAAAAIhhWPZXZ3ENOeUPb18X_gy2dPd', 0);
