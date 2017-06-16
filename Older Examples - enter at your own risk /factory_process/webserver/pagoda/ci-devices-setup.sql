DROP TABLE IF EXISTS `devices`;

CREATE TABLE `devices` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `device_id` varchar(16) DEFAULT NULL,
  `token` varchar(16) DEFAULT NULL,
  `plan_id` varchar(16) DEFAULT NULL,
  `agent_url` varchar(256) DEFAULT NULL,
  `email` varchar(256) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

LOCK TABLES `devices` WRITE;

INSERT INTO `devices` (`id`, `device_id`, `token`, `agent_url`, `plan_id`, `email`)
VALUES
	(1,'20000c2a6900367c',NULL,'https://agent.electricimp.com/ZxXwwhKx_cAw','83f7dbcbf95eb79c','aron@electricimp.com');

UNLOCK TABLES;
