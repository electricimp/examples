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
 

class Enroll extends CI_Controller {

	public function index()
	{
		echo "OK";

		$device_id = element("device_id", $_REQUEST);
		if ($device_id) {

			// Writes the enrollment data to the database and logs
			$this->db->set('when', 'now()', false);
			$this->db->set('device_id', $device_id);
			$this->db->set('msg', "Blessing successful");
			$this->db->insert("logs");

			$sql = "INSERT INTO devices (id, first_blessed)
			        VALUES (?, NOW())
					ON DUPLICATE KEY UPDATE
					   last_blessed = NOW()";
			$this->db->query($sql, array($device_id));

		} else {

			log_message("info", "enroll missing device_id: " . print_r($_REQUEST, true));

		}
	}

}

/* End of file enroll.php */
/* Location: ./application/controllers/enroll.php */
