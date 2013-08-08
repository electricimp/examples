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
 

class FactoryLog extends CI_Controller {

	protected $printer_agent = "http://agent.electricimp.com/_YFPEUUjNmE_";
	public function index()
	{
		log_message("info", "factorylog: " . print_r($_REQUEST, true));
		echo "OK\n";

		// Extract the values from the urlencoded request
		$device_id = element('device_id', $_REQUEST);
		$mac = element('mac', $_REQUEST);
		$success = element('success', $_REQUEST);
		$passed = element('passed', $_REQUEST);

		if ($success && $passed && $device_id && $mac) {

			// Update the database with the mac address
			$sql = "UPDATE devices
					SET mac = ?
					WHERE id = ?";
			$this->db->query($sql, array($mac, $device_id));

			// Send the information to the printer
			$this->load->library('curl'); 
			$printout = "Device ID: $device_id\n"
			          . "Mac: $mac\n"
					  . "Time: " . gmdate("Y-m-d H:i:s");
			$json = json_encode(array("barcode" => $device_id, "text" => $printout));
			$this->curl->simple_post($this->printer_agent . "/qr", $json);
		}

	}

}

/* End of file factorylog.php */
/* Location: ./application/controllers/factorylog.php */
