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
 

// --------------------------------------------------------------------------
// Green: Time remaining in current meeting
// Red:   Time to next meeting
//
// Documentation for the Zend framework calendar interface is here:
// http://framework.zend.com/manual/1.12/en/zend.gdata.calendar.html
// http://framework.zend.com/apidoc/1.12/
//
// Google's version is here:
// https://developers.google.com/google-apps/calendar/v1/developers_guide_php
// --------------------------------------------------------------------------

$path = ini_get("include_path");
ini_set("include_path", "$path:" . __DIR__ . "/../libraries/ZendGdata-1.12.3/library");

require_once 'Zend/Loader.php';
Zend_Loader::loadClass('Zend_Gdata');
Zend_Loader::loadClass('Zend_Gdata_ClientLogin');
Zend_Loader::loadClass('Zend_Gdata_Calendar');

date_default_timezone_set("America/Los_Angeles");

class Meeting_Minder extends CI_Controller {

	//---------------------------------------------------------------------------------------------------------
	function __construct()
	{
		// Authentication
		$this->user = 'owner@gmail.com';
		$this->pass = base64_decode("encodedpassword"); // Yes, there are more secure ways of doing this.
		$this->client = Zend_Gdata_ClientLogin::getHttpClient($this->user, $this->pass, Zend_Gdata_Calendar::AUTH_SERVICE_NAME);
		$this->service = new Zend_Gdata_Calendar($this->client);
	}

	//---------------------------------------------------------------------------------------------------------
	public function get() {
		$nownext = $this->getNowAndNext();

		$result = array();
		if (isset($nownext['now'])) {
			$result['now'] = strtotime($nownext['now']['when']->endTime);
		}
		if (isset($nownext['next'])) {
			$result['next'] = strtotime($nownext['next']['when']->startTime);
		}

		header("Content-Type: application/json");
		echo json_encode($result);
	}


	//---------------------------------------------------------------------------------------------------------
	public function extend() {
		$nownext = $this->getNowAndNext();
		$result = array();

		$command = "none";
		if (isset($nownext['now'])) {
			$result['now'] = strtotime($nownext['now']['when']->endTime) + 900;
			$command = "updateEventEnd";
		} else {
			$result['now'] = time() + 900;
			$command = "createEvent";
		}

		// Limit the extension to the next meeting start time
		if (isset($nownext['next'])) {
			$result['next'] = strtotime($nownext['next']['when']->startTime);
			if ($result['now'] > $result['next']) {
				$result['now'] = $result['next'];
			}
		}

		if ($command == "updateEventEnd") {
			$this->updateEventEnd($nownext['now'], $result['now']);
		} elseif ($command == "createEvent") {
			$this->createEvent(time(), $result['now'], "Meeting added by Meeting Minder");
		}

		if (isset($nownext['next'])) {
			$result['next'] = strtotime($nownext['next']['when']->startTime);
		}

		header("Content-Type: application/json");
		echo json_encode($result);
	}


	//---------------------------------------------------------------------------------------------------------
	public function end() {
		$nownext = $this->getNowAndNext();
		$result = array();

		if (isset($nownext['now'])) {
			$result['now'] = time()-100;
		}
		$this->updateEventEnd($nownext['now'], time());

		if (isset($nownext['next'])) {
			$result['next'] = strtotime($nownext['next']['when']->startTime);
		}

		header("Content-Type: application/json");
		echo json_encode($result);
	}


	//---------------------------------------------------------------------------------------------------------
	// Get the now and next events
	protected function getNowAndNext() {
		$results = array();
		foreach ($calendar = $this->getCalendars() as $calendar) {
			if ($calendar->title->text == $this->user) {
				$events = $this->getEvents("-1 day", "+1 day", $calendar);
				foreach ($events as $event) {
					foreach ($event->when as $when) {

						$starttime = strtotime($when->startTime);
						$endtime = strtotime($when->endTime);
						$midnight = strtotime("23:59:59");

						if ($starttime <= time() && time() < $endtime) {
							// We are in a meeting now
							$results['now']['event'] = $event;
							$results['now']['when'] = $when;
						} else if (time() < $starttime && $starttime <= $midnight) {
							// We have a meeting today
							if (!isset($results['next']) || $starttime < $results['next']) {
								$results['next']['event'] = $event;
								$results['next']['when'] = $when;
							}
						}
					}
				}
			}
		}

		return $results;
	}


	//---------------------------------------------------------------------------------------------------------
	// List the calendars
	protected function getCalendars() {
		return $this->service->getCalendarListFeed();
	}


	//---------------------------------------------------------------------------------------------------------
	// List events from one calendar
	protected function getEvents($from, $to, $calendar = null) {

		$url = $calendar ? $calendar->link[0]->href : null;
		$query = $this->service->newEventQuery($url);
		$query->setUser($calendar ? null : "default");
		$query->setVisibility(NULL);
		$query->setProjection(NULL);
		$query->setOrderby('starttime');
		$query->setFutureevents(null);
		$query->setStartMin(gmdate("Y-m-d\TH:i:s-00:00", strtotime($from)));
		$query->setStartMax(gmdate("Y-m-d\TH:i:s-00:00", strtotime($to)));
		return $this->service->getCalendarEventFeed($query);

	}


	//---------------------------------------------------------------------------------------------------------
	// Create an event
	protected function createEvent($from, $to, $title, $description = "", $location = "") {

		$newEvent = $this->service->newEventEntry();
		$newEvent->title = $this->service->newTitle($title);
		if ($location) $newEvent->where = array($this->service->newWhere($location));
		if ($description) $newEvent->content = $this->service->newContent($description);

		$when = $this->service->newWhen();
		$when->startTime = gmdate("Y-m-d\TH:i:s-00:00", $from);
		$when->endTime = gmdate("Y-m-d\TH:i:s-00:00", $to);
		$newEvent->when = array($when);

		// Upload the event to the calendar server
		// A copy of the event as it is recorded on the server is returned
		return $this->service->insertEvent($newEvent);

	}

	//---------------------------------------------------------------------------------------------------------
	protected function updateEventEnd($event, $end) {
		$when = $event['when'];
		$when->setEndTime(gmdate("Y-m-d\TH:i:s-00:00", $end));
		$event['event']->when = array($when);
		$event['event']->save();
	}

}

