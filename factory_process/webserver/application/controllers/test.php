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
 

class Test extends CI_Controller {

	public function __construct() 
	{
		parent::__construct();
		$this->output->set_header("Content-Type: text/plain");
		$this->load->dbforge();
	}


	public function index()
	{
		// Output the data
		$query1 = $this->db->query('SHOW TABLES');
		foreach ($query1->result_array() as $table) {
			echo "Table: " . $table['Tables_in_devices'] . "\n";
			$query2 = $this->db->order_by("id", "desc")->limit(20)->get($table['Tables_in_devices']);
			foreach ($query2->result() as $row)
			{
				foreach ($row as $k => $v) {
					echo "\t$k => $v\n";
				}
				echo "--------------------\n";
			}
			echo "\n";
		}
	}

}


/* End of file test.php */
/* Location: ./application/controllers/test.php */
