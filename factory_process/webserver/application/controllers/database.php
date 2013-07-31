<?php if ( ! defined('BASEPATH')) exit('No direct script access allowed');

/*
Copyright (C) 2013 Electric Imp, Inc
 
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files 
(the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge,
publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:
 
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
 
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE
FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/
 

class Database extends CI_Controller {

	public function __construct() 
	{
		parent::__construct();
		$this->output->set_header("Content-Type: text/plain");
		$this->load->dbforge();
	}


	public function index()
	{
		// Logs table
		$this->dbforge->drop_table('logs');
		$this->dbforge->add_field('id');
		$this->dbforge->add_field(array('when' => array('type' => 'DATETIME')));
		$this->dbforge->add_field(array('device_id' => array('type' => 'VARCHAR', 'constraint' => '16')));
		$this->dbforge->add_field(array('msg' => array('type' => 'VARCHAR', 'constraint' => '256')));
		$this->dbforge->add_key('device_id');
		$this->dbforge->create_table('logs', TRUE);

		// Devices table
		$this->dbforge->drop_table('devices');
		$this->dbforge->add_field(array('id' => array('type' => 'VARCHAR', 'constraint' => '16')));
		$this->dbforge->add_field(array('mac' => array('type' => 'VARCHAR', 'constraint' => '12')));
		$this->dbforge->add_field(array('first_blessed' => array('type' => 'DATETIME')));
		$this->dbforge->add_field(array('last_blessed' => array('type' => 'DATETIME')));
		$this->dbforge->add_field(array('first_blinked' => array('type' => 'DATETIME')));
		$this->dbforge->add_field(array('last_blinked' => array('type' => 'DATETIME')));
		$this->dbforge->add_field(array('heartbeat' => array('type' => 'DATETIME')));
		$this->dbforge->add_key('id', true);
		$this->dbforge->add_key('mac');
		$this->dbforge->create_table('devices', true);

		echo "OK\n";
	}

}


/* End of file database.php */
/* Location: ./application/controllers/database.php */
